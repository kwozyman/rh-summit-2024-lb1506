LB1506 - Red Hat Summit lab
===

Welcome to LB1506, "Unleashing container OS". This repo contains all the necessary code to succesfully complete the lab.

1. repo and system setup
---

First, clone this repo on the provided host:

```
git clone https://github.com/kwozyman/rh-summit-2024-lb1506.git
```

Change directory to the newly cloned repo and prepare the host system. This step should install a few packages and it should end with a fresh shell.

```
cd rh-summit-2024-lb1506/
make system-setup
```

Download and pull all the required container images and the installation iso:

```
make setup
```

Start local registry:

```
make registry
```

...and check if it's up:

```
]$ podman ps
CONTAINER ID  IMAGE                                    COMMAND               CREATED        STATUS        PORTS                 NAMES
24afac6d41d8  localhost/podman-pause:4.6.1-1705652564                        4 seconds ago  Up 3 seconds  0.0.0.0:443->443/tcp  17ab9c8c510a-infra
73974d580144  docker.io/library/registry:2.8.3         /etc/docker/regis...  3 seconds ago  Up 3 seconds  0.0.0.0:443->443/tcp  summit-registry
```

2. Create standard http
---

Create the first simple container. Edit a file named `Containerfile` in the current directory with the following contents:

```
FROM registry.access.redhat.com/ubi9/ubi

RUN dnf install -y httpd
RUN echo "Hello Red Hat" > /var/www/html/index.html

ENTRYPOINT /usr/sbin/httpd -DFOREGROUND
```

The above can also be found in `examples/01.Containerfile` and you can simply copy it over:

```
$ cp examples/01.Containerfile Containerfile
```

In order to build it, we can run the prepared Makefile target:

```
$ make build
```

or manually:

```
$ podman build --file Containerfile --tag summit.registry/lb1506:latest
```

Any of the above, if succesful will create a simple container tagged `summit.registry/lb1506:latest` which is running an Apache http server on port 80, serving the classic "Hello Red Hat" as it's index.html. In order to run and test it:

```
$ make run-test
```

or manually:

```
$ podman run --rm --name http-test --detach --publish 80:80 summit.registry/lb1506:latest
```

We can see if it's running with the same `podman ps` command we used previously:

```
$ podman ps
CONTAINER ID  IMAGE                                    COMMAND               CREATED        STATUS        PORTS                 NAMES
24afac6d41d8  localhost/podman-pause:4.6.1-1705652564                        7 minutes ago  Up 7 minutes  0.0.0.0:443->443/tcp  17ab9c8c510a-infra
73974d580144  docker.io/library/registry:2.8.3         /etc/docker/regis...  7 minutes ago  Up 7 minutes  0.0.0.0:443->443/tcp  summit-registry
d016e08062ab  summit.registry/lb1506:latest                                 2 seconds ago  Up 2 seconds  0.0.0.0:80->80/tcp    http-test
```

...and we can test it easily:

```
$ curl http://localhost/
Hello Red Hat
```

We can now stop the container:

```
$ make stop-test
```

or manually:

```
$ podman stop http-test
```

3. Tranform simple http container to bootable container
---

In order to transform the previous Containerfile into a bootable container, the two lines must be edited and changed. The first is the base image, changed from the usual Universal Basic Image to the bootc image. Example for both CentOS Stream and RHEL:

```
FROM registry.access.redhat.com/ubi9/ubi    ---->   FROM quay.io/centos-bootc/centos-bootc:stream9
FROM registry.access.redhat.com/ubi9/ubi    ---->   FROM registry.redhat.io/rhel9/rhel-bootc:9.4
```

The second change is simply enabling Apache to run at boot. This is done with a simple SystemD directive, usually just above the `ENTRYPOINT`:

```
RUN systemctl enable httpd.service
```

The whole Containerfile should look like this:

```
FROM quay.io/centos-bootc/centos-bootc:stream9

RUN dnf install -y httpd
RUN echo "Hello Red Hat" > /var/www/html/index.html

RUN systemctl enable httpd.service

ENTRYPOINT /usr/sbin/httpd -DFOREGROUND
```

We can repeat the build steps above:

```
$ make build
```

and test it again locally:

```
$ make run-test
$ podman run --rm --name http-test --detach --publish 80:80 "summit.registry/lb1506:latest"
292cc9f0954e1b56444593a5d79b6555188670211a339cc8dd137b5cbf7e0f14

$ curl http://localhost/                                                                                                                                              
Hello Red Hat

$ make stop-test
```

4. Deploy bootc container in virtual machine
---

**But now it can also be installed in a virtual machine!**

First, we need to prepare the installation iso. The following command will embed the built container and a specially crafter Kickstart in an regular installation iso:

```
$ make iso
```

If the build is succesful, we can start the installation in a virtual machine:

```
$ make vm
```

After a few minutes, the deployment should be complete and our vm stopped. It can be started with a simple `virsh` command:

```
$ virsh --connect qemu:///system start iso
```

After giving it some time to boot, we can directly test our vm!

```
$ curl http://iso-vm/
Hello Red Hat
$ curl http://192.168.150.100/
Hello Red Hat
```

5. Exploring the bootc machine
---

```
# password is 'lb1506'
$ ssh lab-user@iso-vm

$ rpm-ostree status
```

TODO:
  * write and talk about the output above
  * mention self signed certificate on local registry and what is the fix
  * go back to host, regenerate container with fix
  * ssh back to vm and rebase to new container
  * reboot and see the fix

6. Use your own container as base for others
---


