text

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

keyboard --xlayouts='us'
lang en_US.UTF-8

%packages
@^minimal-environment
%end

firstboot --enable

ignoredisk --only-use=vda
autopart
clearpart --all --initlabel --disklabel=gpt

timezone America/New_York --utc

rootpw bifrost --allow-ssh
