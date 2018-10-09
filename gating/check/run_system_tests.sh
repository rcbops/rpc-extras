#!/bin/bash

## Deploy virtualenv for testing environment molecule/ansible-playbook/infratest

## Shell Opts ----------------------------------------------------------------

set -ex
set -o pipefail

## Variables -----------------------------------------------------------------

RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"
SYS_WORKING_DIR=$(mktemp  -d -t system_test_workingdir.XXXXXXXX)
export SYS_VENV_NAME="${SYS_VENV_NAME:-venv-molecule}"
SYS_TEST_SOURCE_BASE="${SYS_TEST_SOURCE_BASE:-https://github.com/rcbops}"
SYS_TEST_SOURCE="${SYS_TEST_SOURCE:-rpc-openstack-system-tests}"
SYS_TEST_SOURCE_REPO="${SYS_TEST_SOURCE_BASE}/${SYS_TEST_SOURCE}"
SYS_TEST_BRANCH="${RE_JOB_BRANCH:-master}"

# Switch system test branch to `dev` on the experimental-asc job.
# This job is specifically for running system tests under development.
if [[ ${RE_JOB_NAME} == experimental-asc* ]] ; then
    SYS_TEST_BRANCH=dev
fi

## Main ----------------------------------------------------------------------

# 1. Clone test repository into working directory.
pushd "${SYS_WORKING_DIR}"
git clone "${SYS_TEST_SOURCE_REPO}"
cd "${SYS_TEST_SOURCE}"

# Checkout defined branch
git checkout "${SYS_TEST_BRANCH}"
echo "${SYS_TEST_SOURCE} at SHA $(git rev-parse HEAD)"

# Gather submodules
git submodule init
git submodule update --recursive

# fail softly if the tests or artifact gathering fails
set +e

# 2. Execute script from repository
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
