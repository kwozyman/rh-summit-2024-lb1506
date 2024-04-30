#BOOTC_IMAGE ?= registry.redhat.io/rhel9/rhel-bootc:9.4
#BOOTC_IMAGE ?= registry.redhat.io/rhel9-beta/rhel-bootc:9.4
BOOTC_IMAGE ?= quay.io/centos-bootc/centos-bootc:stream9

#BOOTC_IMAGE_BUILDER ?= registry.redhat.io/rhel9/bootc-image-builder:9.4
#BOOTC_IMAGE_BUILDER ?= registry.redhat.io/rhel9-beta/bootc-image-builder:9.4
BOOTC_IMAGE_BUILDER ?= quay.io/centos-bootc/bootc-image-builder:latest

LIBVIRT_DEFAULT_URI ?= qemu:///system
LIBVIRT_NETWORK ?= summit-network
LIBVIRT_STORAGE ?= summit-storage
LIBVIRT_STORAGE_DIR ?= /var/lib/libvirt/images/summit
LIBVIRT_VM_NAME ?= bifrost

ISO_URL ?= https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-boot.iso
ISO_NAME ?= rhel-boot

CONTAINER ?= summit.registry/bifrost:latest
CONTAINERFILE ?= Containerfile

REGISTRY_POD ?= registry-pod.yaml

.PHONY: certs

setup: setup-pull vm-setup iso-download registry-certs
clean: vm-clean iso-clean registry-certs-clean

setup-registry: registry-certs registry

vm-setup: vm-setup-network vm-setup-storage
vm-clean-all: vm-clean vm-clean-network vm-clean-storage

vm-setup-network:
	grep summit.registry /etc/hosts || sudo bash -c "echo 192.168.150.1 summit.registry >> /etc/hosts"
	grep bifrost-vm /etc/hosts || sudo bash -c "echo 192.168.150.100 bifrost-vm >> /etc/hosts"
	grep regular-vm /etc/hosts || sudo bash -c "echo 192.168.150.101 regular-vm >> /etc/hosts"
	virsh --connect "${LIBVIRT_DEFAULT_URI}" net-create --file libvirt/network.xml

vm-setup-storage:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" pool-create-as --name "${LIBVIRT_STORAGE}" --target "${LIBVIRT_STORAGE_DIR}" --type dir --build

vm-clean-network:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" net-destroy --network "${LIBVIRT_NETWORK}" || echo not defined

vm-clean-storage:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" pool-destroy --pool "${LIBVIRT_STORAGE}" || echo not defined
	sudo rm -rf "${LIBVIRT_STORAGE_DIR}"

vm:
	ssh-keygen -R bifrost-vm
	ssh-keygen -R 192.168.150.100
	virt-install --connect "${LIBVIRT_DEFAULT_URI}" \
		--name "${LIBVIRT_VM_NAME}" \
		--disk "pool=${LIBVIRT_STORAGE},size=50" \
		--network "network=${LIBVIRT_NETWORK},mac=de:ad:be:ef:01:01" \
		--location "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-custom.iso,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img" \
		--extra-args="inst.ks=hd:LABEL=CentOS-Stream-9-BaseOS-x86_64:/local.ks console=tty0 console=ttyS0,115200n8" \
		--memory 4096 \
		--graphics none \
		--noreboot

vm-regular:
	ssh-keygen -R regular-vm
	ssh-keygen -R 192.168.150.101
	sudo rm -f "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-regular.iso"
	sudo mkksiso --ks templates/classic.ks "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}.iso" "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-regular.iso"
	virt-install --connect "${LIBVIRT_DEFAULT_URI}" \
		--name "regular" \
		--disk "pool=${LIBVIRT_STORAGE},size=50" \
		--network "network=${LIBVIRT_NETWORK},mac=de:ad:be:ef:01:02" \
		--location "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-regular.iso,kernel=images/pxeboot/vmlinuz,initrd=images/pxeboot/initrd.img" \
		--extra-args="inst.stage2=hd:LABEL=CentOS-Stream-9-BaseOS-x86_64 inst.ks=hd:LABEL=CentOS-Stream-9-BaseOS-x86_64:/classic.ks console=tty0 console=ttyS0,115200n8" \
		--disk "device=cdrom,path=${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-regular.iso,format=iso" \
		--memory 4096 \
		--graphics none \
		--noautoconsole \
		--noreboot

vm-regular-clean:
	@virsh --connect "${LIBVIRT_DEFAULT_URI}" destroy "regular" || echo not running
	@virsh --connect "${LIBVIRT_DEFAULT_URI}" undefine "regular" --remove-all-storage || echo not defined

vm-clean:
	@virsh --connect "${LIBVIRT_DEFAULT_URI}" destroy "${LIBVIRT_VM_NAME}" || echo not running
	@virsh --connect "${LIBVIRT_DEFAULT_URI}" undefine "${LIBVIRT_VM_NAME}" --remove-all-storage || echo not defined

ssh:
	@ssh-keygen -t ed25519 -f ~/.ssh/id_rsa -N ""
	@cat templates/config-qcow2.json | jq ".blueprint.customizations.user[0].key=\"$(shell cat ~/.ssh/id_rsa.pub)\"" > config/config-qcow2.json
	@cat templates/kickstart.ks | sed "s^SSHKEY^$(shell cat ~/.ssh/id_rsa.pub)^g" > config/kickstart.ks
	@ssh-add ~/.ssh/id_rsa

iso:
	sudo rm -f "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-custom.iso"
	sudo bash bin/embed-container "${CONTAINER}" "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}.iso" "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-custom.iso"

iso-download:
	sudo curl -L -o "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}.iso" "${ISO_URL}"

iso-clean:
	sudo rm -f "${LIBVIRT_STORAGE_DIR}/${ISO_NAME}-custom.iso"

registry:
	sudo cp certs/004-summit.conf /etc/containers/registries.conf.d/004-summit.conf
	podman kube play --replace "${REGISTRY_POD}"

registry-certs:
	openssl req -new -nodes -x509 -days 365 -keyout certs/ca.key -out certs/ca.crt -config certs/san.cnf

registry-certs-clean:
	rm -f certs/ca.crt certs/ca.key

registry-stop:
	@podman kube down "${REGISTRY_POD}" || echo no started

registry-purge:
	podman volume rm summit-registry || echo not found

setup-pull:
	podman pull "${BOOTC_IMAGE}" "${BOOTC_IMAGE_BUILDER}" \
		registry.access.redhat.com/ubi9/ubi-minimal registry.access.redhat.com/ubi9/ubi \
		docker.io/library/httpd:2.4.59 docker.io/library/registry:2.8.3

system-setup:
	sudo usermod -a -G libvirt lab-user
	sudo dnf install -y qemu-kvm jq
	sudo systemctl start libvirtd
	sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
	git config pull.rebase true
	sudo -u lab-user bash

build:
	podman build --file "${CONTAINERFILE}" --tag "${CONTAINER}"
push:
	podman push "${CONTAINER}"
run-test:
	podman run --rm --name http-test --detach --publish 80:80 "${CONTAINER}"
stop-test:
	podman stop http-test
