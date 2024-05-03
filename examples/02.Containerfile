FROM registry.redhat.io/rhel9/rhel-bootc:9.4

RUN dnf install -y httpd
RUN echo Hello RedHat > /var/www/html/index.html

RUN systemctl enable httpd.service
ENTRYPOINT /usr/sbin/httpd -DFOREGROUND
