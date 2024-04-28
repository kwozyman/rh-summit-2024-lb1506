FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf install -y httpd
RUN echo Hello RedHat > /var/www/html/index.html

systemctl enable httpd.service
