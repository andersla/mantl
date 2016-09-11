#!/bin/bash -eux

update-ca-trust


# Install EPEL repository
#rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-6.noarch.rpm
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# Install Ansible
yum -y install ansible

# instal speciffic version of Ansible
# rpm -ivh ftp://195.220.108.108/linux/fedora/linux/releases/23/Everything/x86_64/os/Packages/a/ansible-1.9.3-2.fc23.noarch.rpm


