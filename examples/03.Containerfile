FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf install -y httpd
RUN echo Hello RedHat > /var/www/html/index.html

ADD certs/004-summit.conf /etc/containers/registries.conf.d/004-summit.conf

systemctl enable httpd.service
