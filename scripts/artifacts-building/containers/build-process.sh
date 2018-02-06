#!/usr/bin/env bash
# Copyright 2014-2017 , Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##
## This process is no longer required. See the following JIRA card for
## more details: https://rpc-openstack.atlassian.net/browse/RO-3856
##
## Instead of removing this code, the script is just set to exit
## immediately. This allows the CI jobs to continue functioning
## normally until the container artifact building is appropriately
## removed from all relevant RPC-O branches and repositories.
##
exit 0

## Shell Opts ----------------------------------------------------------------

set -e -u -x

## Vars ----------------------------------------------------------------------

# To provide flexibility in the jobs, we have the ability to set any
# parameters that will be supplied on the ansible-playbook CLI.
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:--v}

# Set this to YES if you want to replace any existing artifacts for the current
# release with those built in this job.
export REPLACE_ARTIFACTS=${REPLACE_ARTIFACTS:-no}

# Set this to YES if you want to push any changes made in this job to rpc-repo.
export PUSH_TO_MIRROR=${PUSH_TO_MIRROR:-no}

# The BASE_DIR needs to be set to ensure that the scripts
# know it and use this checkout appropriately.
export BASE_DIR=${PWD}

# We want the role downloads to be done via git
# This ensures that there is no race condition with the artifacts-git job
export ANSIBLE_ROLE_FETCH_MODE="git-clone"

## Main ----------------------------------------------------------------------

# Ensure no remnants (not necessary if ephemeral host, but useful for dev purposes
rm -f /opt/list

# The derive-artifact-version.sh script expects the git clone to
# be at /opt/rpc-openstack, so we link the current folder there.
if [[ "${PWD}" != "/opt/rpc-openstack" ]]; then
  ln -sfn ${PWD} /opt/rpc-openstack
fi

# Bootstrap Ansible
# This script is sourced to ensure that the common
# functions and vars are available.
cd /opt/rpc-openstack
source scripts/bootstrap-ansible.sh

# Bootstrap the AIO configuration
./scripts/bootstrap-aio.sh

# Copy the current user-space defaults file
cp "/opt/rpc-openstack/rpcd/etc/openstack_deploy/user_osa_variables_defaults.yml" /etc/openstack_deploy/

# Remove all host group allocations to ensure
# that no containers are created in the inventory.
rm -f /etc/openstack_deploy/conf.d/*

# Figure out when it is safe to automatically replace artifacts
if [[ "$(echo ${PUSH_TO_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then

  if container_artifacts_available; then
    # If there are artifacts for this release already, and it is not
    # safe to replace them, then set PUSH_TO_MIRROR to NO to prevent
    # them from being overwritten.
    if ! safe_to_replace_artifacts; then
      export PUSH_TO_MIRROR="NO"

    # If there are artifacts for this release already, and it is safe
    # to replace them, then set REPLACE_ARTIFACTS to YES to ensure
    # that they do get replaced.
    else
      export REPLACE_ARTIFACTS="YES"
    fi
  fi
fi

# If REPLACE_ARTIFACTS is YES then set PUSH_TO_MIRROR to YES
if [[ "$(echo ${REPLACE_ARTIFACTS} | tr [a-z] [A-Z])" == "YES" ]]; then
  export PUSH_TO_MIRROR="YES"
fi

# Remove the AIO configuration relating to the use
# of container artifacts. This needs to be done
# because the container artifacts do not exist yet.
./scripts/artifacts-building/remove-container-aio-config.sh

# Set override vars for the artifact build
cd scripts/artifacts-building/
cp user_*.yml /etc/openstack_deploy/

# If we have no pre-built python artifacts available, the whole
# container build process will fail as it is unable to find the
# right artifacts to use. To ensure that we can still do a PR test
# when there are no python artifacts, we need to override a few
# things.
if ! python_artifacts_available; then
    # As there are no wheels available for this release, we will
    # need to enable developer_mode for the role install.
    echo "developer_mode: yes" >> ${OA_OVERRIDES}

    # As there are is not pre-build constraints file available
    # we will need to use those from upstream.
    OSA_SHA=$(pushd ${OA_DIR} >/dev/null; git rev-parse HEAD; popd >/dev/null)
    REQUIREMENTS_SHA=$(awk '/requirements_git_install_branch:/ {print $2}' ${OA_DIR}/playbooks/defaults/repo_packages/openstack_services.yml)
    OSA_PIN_URL="https://raw.githubusercontent.com/openstack/openstack-ansible/${OSA_SHA}/global-requirement-pins.txt"
    REQ_PIN_URL="https://raw.githubusercontent.com/openstack/requirements/${REQUIREMENTS_SHA}/upper-constraints.txt"
    echo "pip_install_upper_constraints: ${OSA_PIN_URL} --constraint ${REQ_PIN_URL}" >> ${OA_OVERRIDES}

    # As there is no get-pip.py artifact available from rpc-repo
    # we set the var to ensure that it uses the default upstream
    # URL.
    echo "pip_upstream_url: https://bootstrap.pypa.io/get-pip.py" >> ${OA_OVERRIDES}

    # As there is no repo server in this build, and rpc-repo
    # has no packages available, ensure that the lock down
    # is disabled.
    echo "pip_lock_to_internal_repo: no" >> ${OA_OVERRIDES}

    # As newton reaches EOL, developer_mode no longer works
    # as it tries to make use of the stable/newton branch
    # which no longer exists.
    # We implement the override here to cater for PR tests
    # only.
    eol_repo_list="cinder glance heat horizon ironic keystone magnum_dashboard"
    eol_repo_list="${eol_repo_list} neutron neutron_dynamic_routing"
    eol_repo_list="${eol_repo_list} neutron_fwaas neutron_lbaas"
    eol_repo_list="${eol_repo_list} neutron_vpnaas nova swift"
    for svc in ${eol_repo_list}; do
      echo "${svc}_git_install_branch: newton-eol" >> ${OA_OVERRIDES}
    done
fi

# Run playbooks
cd /opt/rpc-openstack/openstack-ansible/playbooks

# If the apt artifacts are not available, then this is likely
# a PR test which is not going to upload anything, so the
# artifacts we build do not need to be strictly set to use
# the RPC-O apt repo.
if apt_artifacts_available; then
    # The host must only have the base Ubuntu repository configured.
    # All updates (security and otherwise) must come from the RPC-O apt artifacting.
    # The host sources are modified to ensure that when the containers are prepared
    # they have our mirror included as the default. This happens because in the
    # lxc_hosts role the host apt sources are copied into the container cache.
    openstack-ansible /opt/rpc-openstack/rpcd/playbooks/configure-apt-sources.yml \
                      -e "host_ubuntu_repo=http://mirror.rackspace.com/ubuntu" \
                      ${ANSIBLE_PARAMETERS}
fi

# Setup the host
openstack-ansible setup-hosts.yml --limit lxc_hosts,hosts

# Move back to artifacts-building dir
cd /opt/rpc-openstack/scripts/artifacts-building/

# Build the base container
openstack-ansible containers/artifact-build-chroot.yml \
                  -e role_name=pip_install \
                  -e image_name=default \
                  ${ANSIBLE_PARAMETERS}

# Build the list of roles to build containers for
role_list=""
role_list="${role_list} elasticsearch kibana logstash memcached_server"
role_list="${role_list} os_cinder os_glance os_heat os_horizon os_ironic"
role_list="${role_list} os_keystone os_neutron os_nova os_swift os_tempest"
role_list="${role_list} rabbitmq_server repo_server rsyslog_server"

# Build all the containers
for cnt in ${role_list}; do
  openstack-ansible containers/artifact-build-chroot.yml \
                    -e role_name=${cnt} \
                    ${ANSIBLE_PARAMETERS}
done

# If there are no python artifacts, then the containers built are unlikely
# to be idempotent, so skip this test.
if python_artifacts_available; then
    # test one container build contents
    openstack-ansible containers/test-built-container.yml
    openstack-ansible containers/test-built-container-idempotency-test.yml | tee /tmp/output.txt; grep -q 'changed=0.*failed=0' /tmp/output.txt && { echo 'Idempotence test: pass';  } || { echo 'Idempotence test: fail' && exit 1; }
fi

if [[ "$(echo ${PUSH_TO_MIRROR} | tr [a-z] [A-Z])" == "YES" ]]; then
  if [ -z ${REPO_USER_KEY+x} ] || [ -z ${REPO_USER+x} ] || [ -z ${REPO_HOST+x} ] || [ -z ${REPO_HOST_PUBKEY+x} ]; then
    echo "Skipping upload to rpc-repo as the REPO_* env vars are not set."
    exit 1
  else
    # Prep the ssh key for uploading to rpc-repo
    mkdir -p ~/.ssh/
    set +x
    REPO_KEYFILE=~/.ssh/repo.key
    cat $REPO_USER_KEY > ${REPO_KEYFILE}
    chmod 600 ${REPO_KEYFILE}
    set -x

    # Ensure that the repo server public key is a known host
    grep "${REPO_HOST}" ~/.ssh/known_hosts || echo "${REPO_HOST} $(cat $REPO_HOST_PUBKEY)" >> ~/.ssh/known_hosts

    # Create the Ansible inventory for the upload
    echo '[mirrors]' > /opt/inventory
    echo "repo ansible_host=${REPO_HOST} ansible_user=${REPO_USER} ansible_ssh_private_key_file='${REPO_KEYFILE}' " >> /opt/inventory

    # Ship it!
    openstack-ansible containers/artifact-upload.yml -i /opt/inventory -v

    # test the uploaded metadata: fetching the metadata file, fetching a
    # container, and checking integrity of the downloaded artifact.
    openstack-ansible containers/test-uploaded-container-metadata.yml -v
  fi
else
  echo "Skipping upload to rpc-repo as the PUSH_TO_MIRROR env var is not set to 'YES'."
fi

