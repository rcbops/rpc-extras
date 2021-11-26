#!/bin/bash

## Deploy virtualenv for testing environment molecule/ansible-playbook/infratest

## Shell Opts ----------------------------------------------------------------

set -ex
set -o pipefail

## Variables -----------------------------------------------------------------

# The RPC_PRODUCT_RELEASE and RPC_RELEASE need to be brought into scope
# before running health check tests.
if [[ ${RE_JOB_IMAGE} =~ .*mnaio.* ]]; then
  source /opt/rpc-openstack/scripts/functions.sh
fi

RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"
HC_WORKING_DIR=$(mktemp  -d -t healthcheck_test_workingdir.XXXXXXXX)
export HC_VENV_NAME="${HC_VENV_NAME:-healthcheck-molecule}"
HC_TEST_SOURCE_BASE="${HC_TEST_SOURCE_BASE:-https://github.com/rcbops}"
HC_TEST_SOURCE="${HC_TEST_SOURCE:-rpc-openstack-healthcheck}"
HC_TEST_SOURCE_REPO="${HC_TEST_SOURCE_BASE}/${HC_TEST_SOURCE}"
HC_TEST_BRANCH="${RE_JOB_BRANCH:-master}"

## Main ----------------------------------------------------------------------

# 1. Clone test repository into working directory.
pushd "${HC_WORKING_DIR}"
git clone "${HC_TEST_SOURCE_REPO}"
cd "${HC_TEST_SOURCE}"

# Checkout defined branch
git checkout "${HC_TEST_BRANCH}"
echo "${HC_TEST_SOURCE} at SHA $(git rev-parse HEAD)"

# fail softly if the tests or artifact gathering fails
set +e

# 2. Execute script from repository
chmod 755 execute_tests.sh
./execute_tests.sh
[[ $? -ne 0 ]] && RC=$?  # record non-zero exit code

# 3. Collect results from script, if they exist
mkdir -p "${RE_HOOK_RESULT_DIR}" || true  # ensure that result directory exists
if [[ -e test_results.tar ]]; then
  tar -xf test_results.tar -C "${RE_HOOK_RESULT_DIR}"
fi

# 4. Collect logs from script, if they exist
mkdir -p "${RE_HOOK_ARTIFACT_DIR}" || true  # ensure that artifact directory exists
if [[ -e test_results.tar ]]; then
  cp test_results.tar "${RE_HOOK_ARTIFACT_DIR}/molecule_test_results.tar"
fi
popd

# if exit code is recorded, use it, otherwise let it exit naturally
[[ -z ${RC+x} ]] && exit ${RC}
