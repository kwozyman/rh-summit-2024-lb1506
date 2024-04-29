FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf install -y httpd
RUN echo Hello RedHat > /var/www/html/index.html

RUN systemctl enable httpd.service
ENTRYPOINT /usr/sbin/httpd -DFOREGROUND
