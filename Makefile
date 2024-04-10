SHELL:=/bin/bash

virt-install:
	virt-install --connect qemu:///system --install kernel=/var/lib/libvirt/images/summit/vmlinuz,initrd=/var/lib/libvirt/images/summit/initrd.img,kernel_args="inst.stage2=hd:LABEL=RHEL-9-4-0-BaseOS-x86_64 inst.ks=http://192.168.150.1:8088/basic.ks console=ttyS0" --disk size=20 --disk device=cdrom,path=/var/lib/libvirt/images/rhel-9.4-beta-x86_64-boot.iso,format=iso --osinfo rhel9.4 --name foo --memory 4096 --graphics none --noreboot

clean-virt:
	virsh --connect qemu:///system destroy foo || echo not running
	virsh --connect qemu:///system undefine foo || echo not defined
	rm -f /var/lib/libvirt/images/foo.qcow2

http:
	sudo podman kube play podman-kube/httpd.yaml

clean-http:
	sudo podman kube down podman-kube/httpd.yaml

clean: clean-http clean-virt
