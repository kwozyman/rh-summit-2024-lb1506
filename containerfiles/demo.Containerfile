FROM registry.redhat.io/rhel9-beta/rhel-bootc:9.4

# Substitute YOUR public key for the public key giving the private key root access
# podman build --build-arg="SSHPUBKEY=$(cat $HOME/.ssh/id_rsa.pub)" ...
ARG SSHPUBKEY

RUN mkdir /usr/etc-system && \
	echo 'AuthorizedKeysFile /usr/etc-system/%u.keys' >> /etc/ssh/sshd_config.d/30-auth-system.conf && \
	echo $SSHPUBKEY > /usr/etc-system/root.keys && chmod 0600 /usr/etc-system/root.keys

# The following steps should be done in the bootc image.
CMD [ "/sbin/init" ]
STOPSIGNAL SIGRTMIN+3
RUN rpm --setcaps shadow-utils
