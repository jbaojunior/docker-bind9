FROM centos:8

RUN yum install bind bind-utils -y

# Creating the mount points to read the configurations
RUN mkdir -p /opt/named/{data,conf.d,zones,template} && mkdir /template

# Copy the named.conf to be used
COPY files/named.conf.tpl /template/

COPY files/named-init /usr/local/bin

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["/usr/local/bin/named-init"]
