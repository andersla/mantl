#!/bin/bash -eux

#Fix for MANTL 1.0.2 (already in master)
update-ca-trust

# Install EPEL repository
rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-7.noarch.rpm

# Install Ansible
yum -y install ansible
