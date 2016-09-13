## How to deploy MANTL
[MANTL](http://mantl.io/) is a modern platform for rapidly deploying globally distributed services. The MANTL project defines a set of [Terraform](https://www.terraform.io/) and [Ansible](https://www.ansible.com/) configuration files to rapidly deploy a microservices infrastructure on many cloud providers. In this section we cover how to deploy a MANTL cluster on the PhenoMeNal project in the Google Cloud Engine (GCE).

>**Note**
>Before to continue please take a brief look to the [MANTL architecture](https://github.com/CiscoCloud/mantl/blob/master/README.md#architecture).

First of all you need to get MANTL, which is distributed through GitHub. Please clone the official MANTL repository and locate into it.

```bash
git clone https://github.com/CiscoCloud/mantl.git
cd mantl
```

>**N.B.** We assume that you will run all of the following commands in the mantl directory.

It is good practice to never run the current version of any product that is distributed through a git repository. This applies to MANTL as well. Therefore, we want to checkout a stable version of MANTL.

```bash
git checkout 1.0.2
```

First of all we need fire up the VMs on GCE. MANTL uses Terraform to provide cloud hosts provisioning, on multiple cloud providers. This is done through the definition of several Terraform modules, that make MANTL deployment simple and repeatable. However some minimal configuration it is needed (e.g. number of controllers, edges and workers, credentials etc.). For this tutorial we prepared a Terraform configuration file [gce.tf](https://github.com/phnmnl/workflow-demo/blob/master/mantl/gce.tf) that you can download and use. This file needs to be copied in the MANTL home directory, so you can just run the following command.

```bash
wget https://raw.githubusercontent.com/phnmnl/workflow-demo/master/mantl/gce.tf
```

In *gce.tf* we define a small development cluster with one control node, one edge node and two resource/worker nodes. You can learn how to define such file reading the [MANTL GCE documentation](http://microservices-infrastructure.readthedocs.org/en/latest/getting_started/gce.html). 

Since in this tutorial session many people are going to deploy their own MANTL cluster we need you to customize the cluster name, in order to avoid collisions. Please locate and edit the following lines in the *gce.tf* file before to proceed.

```bash
variable "long_name" {default = "myname-mantl"} #please customize this with your name
variable "short_name" {default = "myname"} #please customize this with your name
```

We are almost ready to fire up the machines, but we need a further very important step. In the cloud ssh access to the VMs is passwordless. Therefore, your ssh key needs to be injected in the VMs. The *gce.tf* file is configured to inject *~/.ssh/id_rsa* in the VMs, hence you will have to add this key to the authentication agent, running the following command.

```bash
ssh-add ~/.ssh/id_rsa
```

Now we can run the following commands to provision the infrastructure on GCE. 

```bash
terraform get # to get the required modules
terraform plan # to see what is going to be created on GCE
terraform apply # to provision the infrastructure on GCE. Go grab a coffee. 
```

If everything went fine, you should be able to ping the instances through Ansible.

```bash
ansible all -m ping # VMs needs some time to start, if it fails try again after a while
```

Now the infrastructure is running on GCE (VMs, network, public IPs and DNS records). However, we need to install and configure all of the software, required by MANTL, on the VMs. Luckly, MANTL comes with ansible playbook that do this job.

First, we need to upgrade all of the packages on the VMs.

```bash
ansible-playbook playbooks/upgrade-packages.yml # go grab a coffee
```

MANTL comes with many components, hence we might want to install different subsets of these for different use cases. This is done by defining roles in a root Ansible playbook. We prepared one that you can use for this tutorial. Please download it in the *mantl* folder running the following command.

```bash
wget https://raw.githubusercontent.com/phnmnl/workflow-demo/master/mantl/phenomenal.yml
```

Again, to avoid collisions with other users that are running their own cluster on the PhenoMeNal project, we need you to customize this file. Please locate and edit the following line in your *phenomenal.yml* file. 

```bash
traefik_marathon_domain: myname.phenomenal.cloud
```

>**N.B.** it is very important that you substitute *myname* with the same name you have used for the *"short_name"* variable in the *gce.tf* file. If you fail to do so, the edge nodes will not work properly. 

Now, before to install the software defined in *phenomenal.yml*, we need to setup security and define a password for our cluster. You can do this using the *security-setup* script.

```bash
./security-setup
```

Finally, we are ready to install the software via Ansible. Please run the following command.

```bash
ansible-playbook -e @security.yml phenomenal.yml # time for another coffee
```

If everything went fine you should be able to reach the MANTL UI at: *https://control.yourname.phenomenal.cloud/ui/*. 

>To access the MANTL UI add a https exception to your browser, and log in as admin using the password that you previously chose.

If you have a warning under the *Traefik* service, run the following command. 

```bash
ansible 'role=edge' -s -m service -a 'name=traefik state=restarted'
```

>We opend a ticket for this issue (https://github.com/CiscoCloud/mantl/issues/1073), and it is hopefully going to be fixed soon. 

## Deploy long-lasting microservices on Marathon
Now that you have your MANTL cluster running, you may want to deploy some services on that. In this section we cover how to run long-lasting services through the [Marathon](https://mesosphere.github.io/marathon/) REST API. As example we will run a Jupyter server that has previously been wrapped in a Docker image.

>**Note**
>Before to continue you may want to read a bit about [Marathon](https://mesosphere.github.io/marathon/).

First, please clone this repository and locate into it.

```bash
git clone https://github.com/phnmnl/workflow-demo.git
cd workflow-demo
```

We wrapped the Marathon submit REST call in a small script: [marathon_submit.sh](https://github.com/phnmnl/workflow-demo/blob/master/bin/marathon_submit.sh). You can use it to deploy Jupyter on your MANTL cluster running the following commands.

```bash
source bin/set_env.sh #you will asked to enter your control node hostname (without https://), and admin password 
bin/marathon_submit.sh Jupyter/jupyter.json
```

The jupyter.json file is sent to Marathon through the REST API, and it defines the application that we are going to deploy.

```json
{
	"cpus": 0.25, 
	"mem": 128,
	"id": "jupyter",
	"instances": 1,
	"labels": {"traefik.frontend.entryPoints":"http,https,ws"},
	"container": {
    "type": "DOCKER",
    "docker": {
      "image": "jupyter/minimal-notebook",
      "network": "BRIDGE",
			"privileged": true,
			"portMappings": [{
        "containerPort": 8888,
        "hostPort": 0,
        "protocol": "tcp"
      }]
    },
    "volumes": [{
      "containerPath": "/home/jovyan/work",
      "hostPath": "/mnt/container-volumes/jupyter",
      "mode": "RW"
    }]
  }
}
```

The format of this json is defined in the [Marathon REST API documentation](https://mesosphere.github.io/marathon/docs/rest-api.html). An important remark is that we mount the jupytet working directory under the `/mnt/container-volumes` folder. This is the location where the [GlusterFS](https://www.gluster.org/) distributed filesystem is mounted. Doing so, the Jupyter working directory will be accessible by other microservices, that can potentially run on other resource nodes. 

[Traefik](https://github.com/containous/traefik) is a reverse proxy that runs on the edge nodes, and it provides access to the services deployed via Marathon. Please read a bit about that. If everything went fine, you should be able to figure out the front end URL of your Jupyter deployment from the Traefik UI (which is linked in the MANTL UI).

**N.B.** Due to an issue (https://github.com/CiscoCloud/mantl/issues/1142), the Jupyter working directory won't be writable on GlusterFS. To fix this we need to ssh into a node and change the ownership of it. 

```bash
ssh centos@control.myname.phenomenal.cloud
sudo chown centos /mnt/container-volumes/jupyter/
exit # closes the ssh connection
```

## Deploy microservices workflows using Chronos
We prepared a Jupyter interactive notebook that you can use to get started with Chronos. You can download it [here](https://raw.githubusercontent.com/phnmnl/workflow-demo/master/Jupyter/Workflow.ipynb), and upload it to the Jupyter server that you previously deployed on MANTL. 

>**Note**
>Before going through the notebook, please read a bit about [Chronos](https://mesos.github.io/chronos/).


## How to destroy a MANTL cluster

When you are done with your testing, you can run the following command to delete your MANTL cluster. 

```bash
terraform destroy
```

It is important that you don't leave your cluster up and running, if you are not using it, otherwise we will waste GCE credits. 
