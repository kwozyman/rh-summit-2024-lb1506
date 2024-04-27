#BOOTC_IMAGE ?= registry.redhat.io/rhel9/rhel-bootc:9.4
#BOOTC_IMAGE ?= registry.redhat.io/rhel9-beta/rhel-bootc:9.4
BOOTC_IMAGE ?= quay.io/centos-bootc/centos-bootc:stream9

#BOOTC_IMAGE_BUILDER ?= registry.redhat.io/rhel9/bootc-image-builder:9.4
#BOOTC_IMAGE_BUILDER ?= registry.redhat.io/rhel9-beta/bootc-image-builder:9.4
BOOTC_IMAGE_BUILDER ?= quay.io/centos-bootc/bootc-image-builder:latest

LIBVIRT_DEFAULT_URI ?= qemu:///system
LIBVIRT_NETWORK ?= summit-network
LIBVIRT_STORAGE ?= summit-storage

ISO_URL ?= https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-20240422.0-x86_64-boot.iso
ISO_NAME ?= rhel-boot

virt-setup: virt-setup-network virt-setup-storage

virt-setup-network:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" net-create --file libvirt/network.xml

virt-setup-storage:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" pool-create --file libvirt/storage.xml --build

virt-clean-network:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" net-destroy --network "${LIBVIRT_NETWORK}" || echo not defined

virt-clean-storage:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" pool-destroy --pool "${LIBVIRT_STORAGE}" || echo not defined

virt-vm:
	#virt-install --connect "${LIBVIRT_DEFAULT_URI}" --install kernel=/var/lib/libvirt/images/summit/vmlinuz,initrd=/var/lib/libvirt/images/summit/initrd.img,kernel_args="inst.stage2=hd:LABEL=RHEL-9-4-0-BaseOS-x86_64 inst.ks=http://192.168.150.1:8088/basic.ks console=ttyS0" --disk size=20 --disk device=cdrom,path=/var/lib/libvirt/images/rhel-9.4-beta-x86_64-boot.iso,format=iso --osinfo rhel9.4 --name foo --memory 4096 --graphics none --noreboot
	virt-install --connect "${LIBVIRT_DEFAULT_URI}" --disk size=50 --cdrom "${ISO}.iso" --osinfo rhel9.4 --name foo --memory 4096

virt-clean-vm:
	virsh --connect "${LIBVIRT_DEFAULT_URI}" destroy foo || echo not running
	virsh --connect "${LIBVIRT_DEFAULT_URI}" undefine foo || echo not defined
	sudo rm -f /var/lib/libvirt/images/foo.qcow2

ssh:
	@ssh-keygen -t ed25519 -f ~/.ssh/id_rsa -N ""
	@cat templates/config-qcow2.json | jq ".blueprint.customizations.user[0].key=\"$(shell cat ~/.ssh/id_rsa.pub)\"" > config/config-qcow2.json
	@cat templates/kickstart.ks | sed "s^SSHKEY^$(shell cat ~/.ssh/id_rsa.pub)^g" > config/kickstart.ks
	@ssh-add ~/.ssh/id_rsa

iso-download:
	curl -L -o "${ISO}.iso" "${ISO_URL}"

pod:
	podman kube play --replace podman-kube/summit-pod.yaml

clean-pod:
	podman kube down podman-kube/summit-pod.yaml

clean-data:
	podman volume rm summit-registry

podman-pull:
	podman pull "${BOOTC_IMAGE}" "${BOOTC_IMAGE_BUILDER}" \
		registry.access.redhat.com/ubi9/ubi-minimal registry.access.redhat.com/ubi9/ubi \
		docker.io/library/httpd:2.4.59 docker.io/library/registry:2.8.3

system-setup:
	sudo usermod -a -G libvirt lab-user
	sudo dnf install -y jq
	sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80

clean: clean-pod clean-virt
