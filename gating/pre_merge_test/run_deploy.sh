#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -euv
set -o pipefail

## Vars ----------------------------------------------------------------------
export DEPLOY_AIO="yes"

# These vars are set by the CI environment, but are given defaults
# here to cater for situations where someone is executing the test
# outside of the CI environment.
export RE_JOB_NAME="${RE_JOB_NAME:-}"
export RE_JOB_IMAGE="${RE_JOB_IMAGE:-}"
export RE_JOB_SCENARIO="${RE_JOB_SCENARIO:-swift}"
export RE_JOB_ACTION="${RE_JOB_ACTION:-deploy}"
export RE_JOB_FLAVOR="${RE_JOB_FLAVOR:-}"
export RE_JOB_TRIGGER="${RE_JOB_TRIGGER:-PR}"
export RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"

# These vars are being set to allow bootstrap-aio to work with
# the old job and new job definitions.
export JOB_NAME="${RE_JOB_NAME}"
export SCENARIO="${RE_JOB_SCENARIO}"
export TARGET="${TARGET:-aio}"
export TRIGGER="${TRIGGER:-pr}"

## Functions -----------------------------------------------------------------
export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

## Main ----------------------------------------------------------------------

# Set the appropriate scenario variables
if [[ "${RE_JOB_SCENARIO}" == "ceph" ]]; then
  export DEPLOY_CEPH="yes"
  export DEPLOY_SWIFT="no"
elif [[ "${RE_JOB_SCENARIO}" == "ironic" ]]; then
  export DEPLOY_IRONIC="yes"
fi

if [[ ${RE_JOB_IMAGE} =~ loose$ ]]; then

  # Set the apt artifact mode
  export RPCO_APT_ARTIFACTS_MODE="loose"

  # Upgrade to the absolute latest
  # available packages.
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
fi

# Run the deployment script
cd ${BASE_DIR}
source ${BASE_DIR}/scripts/deploy.sh

# Install tempest
cd ${BASE_DIR}/rpcd/playbooks
openstack-ansible ${BASE_DIR}/scripts/run_tempest.yml --skip-tags tempest_execute_tests

# Execute tempest tests (retry if it fails)
openstack-ansible ${BASE_DIR}/scripts/run_tempest.yml --tags tempest_execute_tests -vv ||\
  openstack-ansible ${BASE_DIR}/scripts/run_tempest.yml --tags tempest_execute_tests -vv

# Execute Kibana Selenium Tests
cd /opt/kibana-selenium

# Work around https://github.com/pypa/virtualenv/issues/1029
export VIRTUAL_ENV_DISABLE_PROMPT=true

set +x; source .venv/bin/activate; set -x

export PYTHONPATH=$(pwd)
export PATH=$PATH:./phantomjs-2.1.1-linux-x86_64/bin

# Remove any existing screenshots from old runs
rm -f *.png
export PASSWORD=$(grep -Ir kibana_password /etc/openstack_deploy/ | tail -1 | sed 's|.*:||')

python conf-gen.py --secure --password $PASSWORD \
  --vip-file /etc/openstack_deploy/openstack_user_config.yml

nosetests -sv --with-xunit testrepo/kibana/kibana.py
