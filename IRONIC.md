# Ironic Configuration

This document will guide you through the necessary steps to properly configure
and setup Ironic in RPC-O.

## openstack\_user\_config

### New networks

There are new networks that need to be defined for ironic's use.

	cidr_networks:
	  tftp: <IP network>/<netmask>
	  ironic-ipmi: <IP network>/<netmask>

The `` tftp `` network is the base network for ironic hosts, that being those
hosts that will be bootable and available to end users.  This network contains
both the interfaces used to provision the host via tftp and the way that the
ironic hosts will be able to connect to the outside world (default route).

The `` ironic-ipmi `` network is the network that touches the ipmi devices
(drac, ilo or other) of the ironic hosts.  It allows ironic-conductor to
control the power status of the ironic hosts.

Be sure to add used IPs from these networks to the `` used_ips `` list.

### global\_overrides

There will be two new networks added to the `` provider_networks `` section.

	- network:
	    container_bridge: "br-ironic-ipmi"
	    container_type: "veth"
	    container_interface: "eth_ipmi"
	    ip_from_q: "ironic-ipmi"
	    type: "raw"
	    group_binds:
	      - ironic-infra_hosts

This network connects the `` ironic-ipmi `` network to the ironic-conductor
containers.


	- network:
	    container_bridge: "br-tftp"
	    container_type: "veth"
	    container_interface: "eth_tftp"
	    ip_from_q: "ironic-ipmi"
	    type: "flat"
	    net_name: "tftp"
	    ip_from_q: "tftp"
	    group_binds:
	      - neutron_linuxbridge_agent
	      - ironic_all

This network connects both neutron and all ironic containers to the base
network of the ironic nodes.  Neutron needs to be connected as it controls the
ip assignment of ironic, along with possibly providing gateway access.  Ironic
itself needs access to provision the nodes.

### defining host groups

	ironic-compute_hosts:
	  infra01:
	    ip: <infra01_management_ip>
	  infra02:
	    ip: <infra02_management_ip>
	  infra03:
	    ip: <infra03_management_ip>
	ironic-infra_hosts:
	  infra01:
	    ip: <infra01_management_ip>
	  infra02:
	    ip: <infra02_management_ip>
	  infra03:
	    ip: <infra02_management_ip>

By default if ironic-compute\_hosts and ironic-infra\_hosts are not defined
they will not be deployed.  It is currently recommended to put these containers
on the infrastructure hosts.

## Variable Overrides

### Set up ironic endpoints for Swift/Ironic health checks

The ironic agent needs to be on the ironic-tftp network in order to access
ironic-api and Swift.

The following variables need to be inserted and upated with the correct values
inside of `` user_osa_variables_overrides.yml ``.

	extra_lb_vip_addresses:
	  - <IP address>
	ironic_openstack_api_url: "<IP address>:{{ ironic_service_port }}"
	ironic_swift_endpoint: "<IP address>:8080"

The IP addresses referenced should be the same one referenced in
`` extra_lb_vip_addresses `` that have been setup during installation.

### Configure neutron DHCP to be non-authoritative

To prevent us from having conflicts with an existing authoritative DHCP server,
neutron needs to be set to non-authoritative.

In order to do this, a few variables need to be set, so we need to include the
following variables in `` user_osa_variables_overrides.yml ``:

        neutron_dhcp_config:
          dhcp-option-force: "26,1500"
          dhcp-ignore: "tag:!known"
          log-facility: "/var/log/neutron/dnsmasq.log"

## Post deployment setup of neturon

Ironic / OpenStack needs to be deployed before you can finish the configuration
of Ironic.  Once the initial deployment is done, you can proceed.

### Set up the neutron network and configure the cleaning network

	neutron net-create --shared --provider:physical_network tftp --provider:network_type flat tftp
	neutron subnet-create --name ironic-tftp \
	  --allocation-pool start=<NON_ALLOCATED_TFTP_RANGE_START>,end=<NON_ALLOCATED_TFTP_RANGE_END> \
	  --dns-nameserver=4.4.4.4 tftp <TFTP_NETWORK>/<TFTP_NETMASK>

Once the network is created, take the output of
`` neutron net-list | grep tftp | awk '{print $2}' `` and add the following
section to your `` user_osa_variables_overrides.yml ``.

	ironic_ironic_conf_overrides:
	  neutron:
	    cleaning_network_uuid: "<NEUTRON_TFTP_NETWORK_UUID>"
	  conductor:
	    automated_clean: true

This will autoclean the nodes on checkin and when they are initially registered
to Ironic.

### Redeploy Ironic

Rerun the `` os-ironic-install.yml `` play to get the new settings in place.

# Post deployment image registration and node enrollment

## Creating and registering images

The standard way of creating images for Ironic is to use diskimage-builder.
Follow the documentation to install diskimage-builder located:
https://docs.openstack.org/diskimage-builder/latest/ .  After that is done,
clone https://github.com/osic/osic-elements to `` /opt/osic-elements ``.

Next we will create and upload the deploy image, this is the initial image used
to lay down he final image.  It needs raid tools, in this case for HP gear.

	export DIB_HPSSACLI_URL="http://downloads.hpe.com/pub/softlib2/software1/pubsw-linux/p1857046646/v109216/hpssacli-2.30-6.0.x86_64.rpm"
	export IRONIC_AGENT_VERSION="stable/ocata"
	disk-image-create --install-type source -o ironic-deploy ironic-agent fedora devuser proliant-tools

	glance image-create --name ironic-deploy.kernel \
	                    --visibility public \
	                    --disk-format aki \
	                    --property hypervisor_type=baremetal \
	                    --protected=True \
	                    --container-format aki < ironic-deploy.kernel
	glance image-create --name ironic-deploy.initramfs \
	                    --visibility public \
	                    --disk-format ari \
	                    --property hypervisor_type=baremetal \
	                    --protected=True \
	                    --container-format ari < ironic-deploy.initramfs

Now we create the final deploy images, these images are what are delivered to
the end user.  The steps below create images for Ubuntu Xenial, Trusty and
CentOS 7.

	export ELEMENTS_PATH="/opt/osic-elements"
	export DIB_CLOUD_INIT_DATASOURCES="Ec2, ConfigDrive, OpenStack"
	export DIB_RELEASE=xenial
	export DISTRO_NAME=ubuntu

	disk-image-create -o baremetal-$DISTRO_NAME-$DIB_RELEASE $DISTRO_NAME baremetal bootloader osic-dfw

	VMLINUZ_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz \
	                                    --visibility public \
	                                    --disk-format aki \
	                                    --property hypervisor_type=baremetal \
	                                    --protected=True \
	                                    --container-format aki < baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz | awk '/\| id/ {print $4}')"
	INITRD_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd \
	                                   --visibility public \
	                                   --disk-format ari \
	                                   --property hypervisor_type=baremetal \
	                                   --protected=True \
	                                   --container-format ari < baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd | awk '/\| id/ {print $4}')"
	glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE \
	                    --visibility public \
	                    --disk-format qcow2 \
	                    --container-format bare \
	                    --property hypervisor_type=baremetal \
	                    --property kernel_id=${VMLINUZ_UUID} \
	                    --protected=True \
	                    --property ramdisk_id=${INITRD_UUID} < baremetal-$DISTRO_NAME-$DIB_RELEASE.qcow2

	export DIB_RELEASE=trusty
	export DISTRO_NAME=ubuntu

	disk-image-create -o baremetal-$DISTRO_NAME-$DIB_RELEASE $DISTRO_NAME baremetal bootloader osic-dfw

	VMLINUZ_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz \
	                                    --visibility public \
	                                    --disk-format aki \
	                                    --property hypervisor_type=baremetal \
	                                    --protected=True \
	                                    --container-format aki < baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz | awk '/\| id/ {print $4}')"
	INITRD_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd \
	                                   --visibility public \
	                                   --disk-format ari \
	                                   --property hypervisor_type=baremetal \
	                                   --protected=True \
	                                   --container-format ari < baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd | awk '/\| id/ {print $4}')"
	glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE \
	                    --visibility public \
	                    --disk-format qcow2 \
	                    --container-format bare \
	                    --property hypervisor_type=baremetal \
	                    --property kernel_id=${VMLINUZ_UUID} \
	                    --protected=True \
	                    --property ramdisk_id=${INITRD_UUID} < baremetal-$DISTRO_NAME-$DIB_RELEASE.qcow2

	export DIB_RELEASE=7
	export DISTRO_NAME=centos

	disk-image-create -o baremetal-$DISTRO_NAME-$DIB_RELEASE $DISTRO_NAME baremetal bootloader osic-dfw

	VMLINUZ_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz \
	                                    --visibility public \
	                                    --disk-format aki \
	                                    --property hypervisor_type=baremetal \
	                                    --protected=True \
	                                    --container-format aki < baremetal-$DISTRO_NAME-$DIB_RELEASE.vmlinuz | awk '/\| id/ {print $4}')"
	INITRD_UUID="$(glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd \
	                                   --visibility public \
	                                   --disk-format ari \
	                                   --property hypervisor_type=baremetal \
	                                   --protected=True \
	                                   --container-format ari < baremetal-$DISTRO_NAME-$DIB_RELEASE.initrd | awk '/\| id/ {print $4}')"
	glance image-create --name baremetal-$DISTRO_NAME-$DIB_RELEASE \
	                    --visibility public \
	                    --disk-format qcow2 \
	                    --container-format bare \
	                    --property hypervisor_type=baremetal \
	                    --property kernel_id=${VMLINUZ_UUID} \
	                    --protected=True \
	                    --property ramdisk_id=${INITRD_UUID} < baremetal-$DISTRO_NAME-$DIB_RELEASE.qcow2

## Registering the nodes

This section relies on information that makes it highly dependant on the
specific hardware you deploy, the code examples below may not work for you.

	# Node details
	inventory_hostname=node-hostname
	Port1NIC_MACAddress="aa:bb:cc:dd:ee:ff"

	# IPMI details
	ipmi_address="127.1.1.1"
	ipmi_password="secrete"
	ipmi_user="root"

	# Image details belonging to a particular node
	image_vcpu=48
	image_ram=254802
	image_disk=80
	image_total_disk_size=3600
	image_cpu_arch="x86_64"

	KERNEL_IMAGE=$(glance image-list | awk '/ubuntu-user-image.vmlinuz/ {print $2}')
	INITRAMFS_IMAGE=$(glance image-list | awk '/ubuntu-user-image.initrd/ {print $2}')
	DEPLOY_RAMDISK=$(glance image-list | awk '/ironic-deploy.initramfs/ {print $2}')
	DEPLOY_KERNEL=$(glance image-list | awk '/ironic-deploy.kernel/ {print $2}')

	if ironic node-list | grep "$inventory_hostname"; then
	    NODE_UUID=$(ironic node-list | awk "/$inventory_hostname/ {print \$2}")
	else
	    NODE_UUID=$(ironic node-create \
	      -d agent_ipmitool \
	      -i ipmi_address="$ipmi_address" \
	      -i ipmi_password="$ipmi_password" \
	      -i ipmi_username="$ipmi_user" \
	      -i deploy_ramdisk="${DEPLOY_RAMDISK}" \
	      -i deploy_kernel="${DEPLOY_KERNEL}" \
	      -n $inventory_hostname | awk '/ uuid / {print $4}')
	    ironic port-create -n "$NODE_UUID" \
	                       -a $Port1NIC_MACAddress
	fi
	ironic node-update "$NODE_UUID" add \
	          driver_info/deploy_kernel=$DEPLOY_KERNEL \
	          driver_info/deploy_ramdisk=$DEPLOY_RAMDISK \
	          instance_info/deploy_kernel=$KERNEL_IMAGE \
	          instance_info/deploy_ramdisk=$INITRAMFS_IMAGE \
	          instance_info/root_gb=40 \
	          properties/cpus=$image_vcpu \
	          properties/memory_mb=$image_ram \
	          properties/local_gb=$image_disk \
	          properties/size=$image_total_disk_size \
	          properties/cpu_arch=$image_cpu_arch
	          properties/capabilities=memory_mb:$image_ram,local_gb:$image_disk,cpu_arch:$image_cpu_arch,cpus:$image_vcpu,boot_option:local,disk_label:gpt

	ironic --ironic-api-version 1.15 node-set-provision-state $NODE_UUID provide

The above needs to be done for every Ironic node, there exists an ansible docs
to do this on a large amount of nodes at a time from osic.  For refrence they
are located https://github.com/osic/osic-clouds/blob/master/nextgen/admin-node-enrollment.md
It uses Ironic's ability to alter the raid configuration, the docs are located
https://docs.openstack.org/ironic/latest/admin/raid.html
