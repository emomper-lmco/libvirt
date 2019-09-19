#Dockerfile used for the bulid of libvirt-lmm
#Docker build command: docker build -t <image_name> <libvirt-lmm_location>
#Access bash in container:docker exec -it <name> bash
#Copy file from contianer:docker cp <image_name>:<container_directory> <host_directory>

#Runner stage
#runner base images available:
#registry.oa.net:5000/lmco/runner-base-image/rhel7.5:4.5.0
#registry.oa.net:5000/lmco/runner-base-image/rhel7.6:4.5.0
#registry.oa.net:5000/lmco/runner-base-image/rhel8:4.5.0
FROM registry.oa.net:5000/lmco/runner-base-image/rhel${ENV_VERSION}:4.5.0

USER root

WORKDIR /root/rpmbuild

COPY dist/ ./

RUN cd x86_64/ && yum localinstall -y $(ls -q)

CMD /usr/sbin/libvirtd

ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in ; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); rm -f /lib/systemd/system/multi-user.target.wants/; rm -f /etc/systemd/system/.wants/; rm -f /lib/systemd/system/local-fs.target.wants/; rm -f /lib/systemd/system/sockets.target.wants/udev; rm -f /lib/systemd/system/sockets.target.wants/initctl; rm -f /lib/systemd/system/basic.target.wants/; rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ “/sys/fs/cgroup” ]
CMD ["/usr/sbin/init"]
