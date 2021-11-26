#
# Variable to use for preparation
#

# the base URL to download image artifacts from
export RPCO_ARTIFACT_URL="https://a5ce27333a8948d82738-b28e2b85e22a27f072118ea786afca3a.ssl.cf5.rackcdn.com/"
export RPCO_IMAGE_MANIFEST_URL="${RPCO_ARTIFACT_URL}/${RPC_RELEASE}-${RE_JOB_IMAGE}-${RE_JOB_SCENARIO}/manifest.json"

# Check whether there is a manifest file available
if curl --fail --silent --show-error --retry 5 --output /dev/null ${RPCO_IMAGE_MANIFEST_URL}; then
  export RPCO_IMAGES_AVAILABLE="true"
else
  export RPCO_IMAGES_AVAILABLE="false"
fi

#
# Environment settings
#
if [[ ${RE_JOB_IMAGE} =~ .*xenial.* ]]; then
  export DEFAULT_IMAGE="ubuntu-16.04-amd64"
elif [[ ${RE_JOB_IMAGE} =~ .*bionic.* ]]; then
  export DEFAULT_IMAGE="ubuntu-18.04-amd64"
fi
export DEFAULT_MIRROR_HOSTNAME=mirror.rackspace.com
export DEFAULT_MIRROR_DIR=/ubuntu
export INFRA_VM_SERVER_RAM=16384
export MNAIO_ANSIBLE_PARAMETERS="-e default_vm_disk_mode=file"
export OSA_BRANCH="${OSA_RELEASE:-master}"

# TODO(odyssey4me):
# This can be removed once https://review.openstack.org/604059
# merges.
export DNS_NAMESERVER="8.8.8.8"

#
# Steps to execute when running build.sh
#
export SETUP_HOST="true"
export CONFIG_PREROUTING="false"
export SETUP_PXEBOOT="true"
export SETUP_DHCPD="true"
export DEPLOY_VMS="${DEPLOY_VMS:-false}"
export PRE_CONFIG_OSA="false"
export DEPLOY_OSA="false"
export RUN_OSA="false"
export CONFIGURE_OPENSTACK="false"

#
# Enable Ceph backend if specified by the RE_JOB_SCENARIO
#
if [[ ${RE_JOB_SCENARIO} =~ .*ceph.* ]]; then
  export ENABLE_CEPH_STORAGE="true"
fi

# If there is no set of images available yet, or this
# is the deploy action, then we need to build from scratch.
if [[ "${RPCO_IMAGES_AVAILABLE}" == "false" ]] || [[ "${RE_JOB_ACTION}" == "deploy" ]]; then
  export DEPLOY_VMS="true"
fi

#
# Non-MNAIO RPC Specific settings
#
export RPC_BRANCH="${RE_JOB_BRANCH}"
export DEPLOY_MAAS=false

# ssh command used to execute tests on infra1
export MNAIO_SSH="ssh -ttt -oStrictHostKeyChecking=no root@infra1"

# Function to execute playbooks with all the right vars
function run_mnaio_playbook() {
  ansible-playbook \
                 -i ${MNAIO_INVENTORY:-"playbooks/inventory"} \
                 -e setup_host=${SETUP_HOST:-"true"} \
                 -e setup_pxeboot=${SETUP_PXEBOOT:-"true"} \
                 -e setup_dhcpd=${SETUP_DHCPD:-"true"} \
                 -e deploy_vms=${DEPLOY_VMS:-"true"} \
                 -e deploy_osa=${DEPLOY_OSA:-"true"} \
                 -e deploy_elk=${DEPLOY_ELK:-"false"} \
                 -e osa_repo=${OSA_REPO:-"https://git.openstack.org/openstack/openstack-ansible"} \
                 -e os_ops_repo=${OS_OPS_REPO:-"https://git.openstack.org/openstack/openstack-ansible-ops"} \
                 -e osa_branch=${OSA_BRANCH:-"master"} \
                 -e os_ops_branch=${OS_OPS_BRANCH:-"master"} \
                 -e default_network=${DEFAULT_NETWORK:-"eth0"} \
                 -e default_image=${DEFAULT_IMAGE:-"ubuntu-16.04-amd64"} \
                 -e vm_disk_size=${VM_DISK_SIZE:-92160} \
                 -e http_proxy=${http_proxy:-''} \
                 -e run_osa=${RUN_OSA:-"true"} \
                 -e run_elk=${RUN_ELK:-"false"} \
                 -e pre_config_osa=${PRE_CONFIG_OSA:-"true"} \
                 -e configure_openstack=${CONFIGURE_OPENSTACK:-"true"} \
                 -e config_prerouting=${CONFIG_PREROUTING:-"false"} \
                 -e default_ubuntu_kernel=${DEFAULT_KERNEL:-"linux-image-generic"} \
                 -e default_ubuntu_mirror_hostname=${DEFAULT_MIRROR_HOSTNAME:-"archive.ubuntu.com"} \
                 -e default_ubuntu_mirror_directory=${DEFAULT_MIRROR_DIR:-"/ubuntu"} \
                 -e cinder_vm_server_ram=${CINDER_VM_SERVER_RAM:-"2048"} \
                 -e compute_vm_server_ram=${COMPUTE_VM_SERVER_RAM:-"8196"} \
                 -e infra_vm_server_ram=${INFRA_VM_SERVER_RAM:-"8196"} \
                 -e loadbalancer_vm_server_ram=${LOADBALANCER_VM_SERVER_RAM:-"2048"} \
                 -e logging_vm_server_ram=${LOGGING_VM_SERVER_RAM:-"16384"} \
                 -e swift_vm_server_ram=${SWIFT_VM_SERVER_RAM:-"2048"} \
                 -e enable_ceph_storage=${ENABLE_CEPH_STORAGE:-"false"} \
                 -e container_tech=${CONTAINER_TECH:-"lxc"} \
                 -e ipxe_kernel_base_url=${IPXE_KERNEL_BASE_URL:-"http://boot.ipxe.org"} \
                 -e ipxe_path_url=${IPXE_PATH_URL:-""} ${MNAIO_ANSIBLE_PARAMETERS} \
                 --force-handlers \
                 --flush-cache \
                 $@
}
