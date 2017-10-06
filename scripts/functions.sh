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

## Vars ----------------------------------------------------------------------

# OSA SHA
export OSA_RELEASE=${OSA_RELEASE:-"27fbd63f21baa74319a273310d94e2c9477ae601"} # Head of stable/ocata as of 2017-09-20

# Gating
export BUILD_TAG=${BUILD_TAG:-}
export INFLUX_IP=${INFLUX_IP:-}
export INFLUX_PORT=${INFLUX_PORT:-"8086"}

# Other
export ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
export DEPLOY_AIO=${DEPLOY_AIO:-"no"}
export DEPLOY_OA=${DEPLOY_OA:-"yes"}
export DEPLOY_ELK=${DEPLOY_ELK:-"yes"}
export DEPLOY_MAAS=${DEPLOY_MAAS:-"no"}
export DEPLOY_TELEGRAF=${DEPLOY_TELEGRAF:-"no"}
export DEPLOY_INFLUX=${DEPLOY_INFLUX:-"no"}
export DEPLOY_TEMPEST=${DEPLOY_TEMPEST:-"no"}
export DEPLOY_UPGRADE_TOOLS=${DEPLOY_UPGRADE_TOOLS:-"no"}
export DEPLOY_RALLY=${DEPLOY_RALLY:-"no"}
export DEPLOY_CEPH=${DEPLOY_CEPH:-"no"}
export DEPLOY_SWIFT=${DEPLOY_SWIFT:-"yes"}
export DEPLOY_HARDENING=${DEPLOY_HARDENING:-"yes"}
export DEPLOY_RPC=${DEPLOY_RPC:-"yes"}
export DEPLOY_ARA=${DEPLOY_ARA:-"no"}
export DEPLOY_SUPPORT_ROLE=${DEPLOY_SUPPORT_ROLE:-"no"}
export BOOTSTRAP_OPTS=${BOOTSTRAP_OPTS:-""}
export UNAUTHENTICATED_APT=${UNAUTHENTICATED_APT:-no}

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
export OA_DIR="${BASE_DIR}/openstack-ansible"
export OA_OVERRIDES='/etc/openstack_deploy/user_osa_variables_overrides.yml'
export RPCD_DIR="${BASE_DIR}/rpcd"
export RPCD_OVERRIDES='/etc/openstack_deploy/user_rpco_variables_overrides.yml'
export RPCD_SECRETS='/etc/openstack_deploy/user_rpco_secrets.yml'

export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-''}

export HOST_SOURCES_REWRITE=${HOST_SOURCES_REWRITE:-"yes"}
export HOST_UBUNTU_REPO=${HOST_UBUNTU_REPO:-"http://mirror.rackspace.com/ubuntu"}
export HOST_RCBOPS_REPO=${HOST_RCBOPS_REPO:-"http://rpc-repo.rackspace.com"}

# Derive the rpc_release version from the group vars
export RPC_RELEASE="$(/opt/rpc-openstack/scripts/artifacts-building/derive-artifact-version.sh)"

# Read the OS information
source /etc/os-release
source /etc/lsb-release

## Functions -----------------------------------------------------------------

# Cater for the use of the FORKS env var for backwards compatibility (Newton
#  and older). It should be removed in Pike.
if [ -n "${FORKS+set}" ]; then
  export ANSIBLE_FORKS=${FORKS}
fi

# The default SSHD configuration has MaxSessions = 10. If a deployer changes
#  their SSHD config, then the ANSIBLE_FORKS may be set to a higher number. We
#  set the value to 10 or the number of CPU's, whichever is less. This is to
#  balance between performance gains from the higher number, and CPU
#  consumption. If ANSIBLE_FORKS is already set to a value, then we leave it
#  alone.
#  ref: https://bugs.launchpad.net/openstack-ansible/+bug/1479812
if [ -z "${ANSIBLE_FORKS:-}" ]; then
  CPU_NUM=$(grep -c ^processor /proc/cpuinfo)
  if [ ${CPU_NUM} -lt "10" ]; then
    export ANSIBLE_FORKS=${CPU_NUM}
  else
    export ANSIBLE_FORKS=10
  fi
fi

function run_ansible {
  openstack-ansible ${ANSIBLE_PARAMETERS} $@
}

function copy_default_user_space_files {
    # Copy the current default user space files and make them read-only
    cp ${RPCD_DIR}/etc/openstack_deploy/user_*_defaults.yml /etc/openstack_deploy/
    chmod 0440 /etc/openstack_deploy/user_*_defaults.yml

    # Remove previous defaults files to ensure no conflicts
    # with the current defaults.
    if [[ -e /etc/openstack_deploy/user_rpcm_variables.yml ]]; then
      rm -f /etc/openstack_deploy/user_rpcm_variables.yml
    fi
    if [[ -e /etc/openstack_deploy/user_rpcm_default_variables.yml ]]; then
      rm -f /etc/openstack_deploy/user_rpcm_default_variables.yml
    fi

    # Copy the default override files if they do not exist
    if [[ ! -f "${OA_OVERRIDES}" ]]; then
      cp "${RPCD_DIR}/${OA_OVERRIDES}" "${OA_OVERRIDES}"
    fi

    if [[ ! -f "${RPCD_OVERRIDES}" ]]; then
      cp "${RPCD_DIR}/${RPCD_OVERRIDES}" "${RPCD_OVERRIDES}"
    fi
}

function apt_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/apt-mirror/integrated/dists/${RPC_RELEASE}-${DISTRIB_CODENAME}"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function git_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/git-archives/${RPC_RELEASE}/requirements.checksum"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function python_artifacts_available {

  ARCH=$(uname -p)
  CHECK_URL="${HOST_RCBOPS_REPO}/os-releases/${RPC_RELEASE}/${ID}-${VERSION_ID}-${ARCH}/MANIFEST.in"

  if curl --output /dev/null --silent --head --fail ${CHECK_URL}; then
    return 0
  else
    return 1
  fi

}

function container_artifacts_available {

  CHECK_URL="${HOST_RCBOPS_REPO}/meta/1.0/index-system"

  if curl --silent --fail ${CHECK_URL} | grep "^${ID};${DISTRIB_CODENAME};.*${RPC_RELEASE};" > /dev/null; then
    return 0
  else
    return 1
  fi

}

function configure_apt_sources {

  # Replace the existing apt sources with the artifacted sources.

  sed -i '/^deb-src /d' /etc/apt/sources.list
  sed -i '/-backports /d' /etc/apt/sources.list
  sed -i '/-security /d' /etc/apt/sources.list
  sed -i '/-updates /d' /etc/apt/sources.list

  # Add the RPC-O apt repo source
  echo "deb ${HOST_RCBOPS_REPO}/apt-mirror/integrated/ ${RPC_RELEASE}-${DISTRIB_CODENAME} main" \
    > /etc/apt/sources.list.d/rpco.list

  # Install the RPC-O apt repo key
  curl --silent --fail ${HOST_RCBOPS_REPO}/apt-mirror/rcbops-release-signing-key.asc | apt-key add -

}

function downgrade_installed_packages {
  # Once the apt sources are reconfigured, this function is used
  # to downgrade any installed packages to the latest versions
  # available in the configured apt sources.
  # This is essential when using older apt artifacts on newly
  # built images (eg: public cloud) or when packages were installed
  # from updated sources before the sources were changed (rpc-gating).

  # Update the apt cache
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  # Check whether there are any installed packages which
  # are not available in a configured source.
  if apt list --installed 2>/dev/null | egrep '\[.*local.*\]'; then
    # Create a list of those packages, excluding those which cannot be downgraded:
    pkg_downgrade_list=$(apt list --installed 2>/dev/null | egrep '\[.*local.*\]' | cut -d/ -f1 | grep -v "^linux-\|^rax-")

    # Work through the list, checking for the latest available version of
    # each package in the configured sources. Put together a list of the
    # packages and their versions in the format that 'apt-get install'
    # expects it.
    pkg_downgrade_list_versioned=""
    for pkg_name in ${pkg_downgrade_list}; do
      # 'apt-cache madison' provides an easy to parse format:
      #   libc-bin | 2.19-0ubuntu6.9 | http://rpc-repo.rackspace.com/apt-mirror/integrated/ r14.0.0rc1-trusty/main amd64 Packages
      #   libc-bin | 2.19-0ubuntu6 | http://mirror.rackspace.com/ubuntu/ trusty/main amd64 Packages
      # The top entry is always the latest package available from a configured source.
      pkg_version="$(apt-cache madison ${pkg_name} | head -n 1 | awk '{ print $3 }')"
      pkg_downgrade_list_versioned="${pkg_downgrade_list_versioned} ${pkg_name}=${pkg_version}"
    done
    # Execute the downgrade of all the packages at the same time so that
    # we reduce the likelihood of conflicts.
    apt-get install -y --force-yes ${pkg_downgrade_list_versioned}
  fi
}
