text
network --bootproto=dhcp --device=link --activate

# Basic partitioning
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype xfs

# Here's where we reference the container image to install - notice the kickstart
# has no `%packages` section!  What's being installed here is a container image.
ostreecontainer --url quay.io/kwozyman/r4e:bifrost --no-signature-verification

firewall --disabled
services --enabled=sshd

# if desired, inject a SSH key for root
rootpw --iscrypted locked
sshkey --username root "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPkccS+SKCZEWGJzH7ew0eNPItvqeGFpOhZprmL9owO fortress_of_solitude" #paste your ssh key here
poweroff
