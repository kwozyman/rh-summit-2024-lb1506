FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf install -y httpd
RUN echo Hello RedHat > /var/www/html/index.html

ADD certs/004-summit.conf /etc/containers/registries.conf.d/004-summit.conf
ADD templates/30-auth-system.conf /etc/ssh/sshd_config.d/30-auth-system.conf
ARG SSHPUBKEY
RUN mkdir -p /usr/ssh
RUN echo ${SSHPUBKEY} > /usr/ssh/root.keys && chmod 0600 /usr/ssh/root.keys
