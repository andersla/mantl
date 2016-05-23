variable subnet_cidr { default = "10.0.0.0/24" }
#variable public_key { default = "~/.ssh/id_rsa.pub" }
variable public_key { default = "/home/anders/projekt/phenomenal/ssh/cloud.key.pub" }

variable name { default = "datacenter1" } # cluster name
variable control_count { default = "1"} # number of control nodes
variable worker_count { default = "1"}  # number of worker nodes
variable edge_count { default = "1"}    # number of edge nodes

# Run 'nova network-list' to get these names and values
# Floating ips are optional
variable external_network_uuid { default = "8380006e-edd0-4fb5-b119-0a47e9bda4c4" }
variable floating_ip_pool { default = "public" }

# Run 'nova image-list' to get your image name
#variable image_name  { default = "CentOS7" }
#variable image_name  { default = "phenomenal-mantl-upgraded" }
variable image_name  { default = "phenomenal_installed_packaged" }

#  Openstack flavors control the size of the instance, i.e. m1.xlarge.
#  Run 'nova flavor-list' to list the flavors in your environment
variable control_flavor_name { default = "m1.small" }
variable worker_flavor_name { default = "m1.small" }
variable edge_flavor_name { default = "m1.small" }

module "ssh-key" {
  source = "./terraform/openstack/keypair_v2"
  public_key = "${var.public_key}"
  keypair_name = "${var.name}_key"
}


#Create a network with an externally attached router
module "network" {
  source = "./terraform/openstack/network"
  external_net_uuid = "${var.external_network_uuid}"
  subnet_cidr = "${var.subnet_cidr}"
  name= "${var.name}"
}

# Create floating IPs for each of the roles
# These are not required if your network is exposed to the internet
# or you don't want floating ips for the instances.
module "floating-ips-control" {
  source = "./terraform/openstack/floating-ip"
  count = "${var.control_count}"
  floating_pool = "${var.floating_ip_pool}"
}

module "floating-ips-worker" {
  source = "./terraform/openstack/floating-ip"
  count = "${var.worker_count}"
  floating_pool = "${var.floating_ip_pool}"
}

module "floating-ips-edge" {
  source = "./terraform/openstack/floating-ip"
  count = "${var.edge_count}"
  floating_pool = "${var.floating_ip_pool}"
}

# Create instances for each of the roles
module "instances-control" {
  source = "./terraform/openstack/instance"
  name = "${var.name}"
  count = "${var.control_count}"
  role = "control"
  volume_size = "20"
  network_uuid = "${module.network.network_uuid}"
  floating_ips = "${module.floating-ips-control.ip_list}"
  keypair_name = "${module.ssh-key.keypair_name}"
  flavor_name = "${var.control_flavor_name}"
  image_name = "${var.image_name}"
}

# moved edge creation to before worker
module "instances-edge" {
  source = "./terraform/openstack/instance"
  name = "${var.name}"
  count = "${var.edge_count}"
  volume_size = "20"
  count_format = "%02d"
  role = "edge"
  network_uuid = "${module.network.network_uuid}"
  floating_ips = "${module.floating-ips-edge.ip_list}"
  keypair_name = "${module.ssh-key.keypair_name}"
  flavor_name = "${var.edge_flavor_name}"
  image_name = "${var.image_name}"
}

module "instances-worker" {
  source = "./terraform/openstack/instance"
  name = "${var.name}"
  count = "${var.worker_count}"
  volume_size = "20"
  count_format = "%03d"
  role = "worker"
  network_uuid = "${module.network.network_uuid}"
  floating_ips = "${module.floating-ips-worker.ip_list}"
  keypair_name = "${module.ssh-key.keypair_name}"
  flavor_name = "${var.worker_flavor_name}"
  image_name = "${var.image_name}"
}

#
# Cloudflare DNS service
#
# The token can be set as environment var TF_VAR_token
# export TF_VAR_token=blablatoken82827827
# OR
# in file
#
variable "token" {}
provider "cloudflare" {
  email = "anders.larsson@icm.uu.se"
  token = "${var.token}"
  #token = "${file("path_to_credentials_file.txt")}"
}

# Cloudflare DNS service
module "cloudflare" {
 source = "./terraform/cloudflare"
 control_count = "${var.control_count}"
 control_ips = "${module.instances-control.ip_v4_list}"
 domain = "uservice.se"
 edge_count = "${var.edge_count}"
 edge_ips = "${module.instances-edge.ip_v4_list}"
 short_name = "${var.name}"
 subdomain = ".${var.name}"
 worker_count = "${var.worker_count}"
 worker_ips = "${module.instances-worker.ip_v4_list}"
}

