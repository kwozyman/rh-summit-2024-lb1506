text
network --bootproto=dhcp --device=link --activate

# Basic partitioning
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs

# Here's where we reference the container image to install - notice the kickstart
# has no `%packages` section!  What's being installed here is a container image.
ostreecontainer --url quay.io/[my_account]/lamp-bootc:latest

firewall --disabled
services --enabled=sshd

# optionally add a user
user --name=cloud-user --groups=wheel --plaintext --password=bifrost
sshkey --username cloud-user "SSHKEY"

# if desired, inject a SSH key for root
rootpw --iscrypted locked
sshkey --username root "SSHKEY" #paste your ssh key here
reboot

