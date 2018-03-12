#!/bin/bash

## Deploy virtualenv for testing environment molecule/ansible-playbook/infratest

## Shell Opts ----------------------------------------------------------------

set -v
set -o pipefail

## Variables -----------------------------------------------------------------

# RC is a sentinel value to capture failed exit codes of portions of the script
RC=0
RE_HOOK_ARTIFACT_DIR="${RE_HOOK_ARTIFACT_DIR:-/tmp/artifacts}"
export RE_HOOK_RESULT_DIR="${RE_HOOK_RESULT_DIR:-/tmp/results}"
SYS_WORKING_DIR=$(mktemp  -d -t system_test_workingdir.XXXXXXXX)
export SYS_VENV_NAME="${SYS_VENV_NAME:-venv-molecule}"
SYS_TEST_SOURCE_BASE="${SYS_TEST_SOURCE_BASE:-https://github.com/rcbops}"
SYS_TEST_SOURCE="${SYS_TEST_SOURCE:-rpc-openstack-system-tests}"
SYS_TEST_SOURCE_REPO="${SYS_TEST_SOURCE_BASE}/${SYS_TEST_SOURCE}"
SYS_TEST_BRANCH="${SYS_TEST_BRANCH:-master}"
export SYS_INVENTORY="/opt/openstack-ansible/playbooks/inventory"

## Functions -----------------------------------------------------------------

# Update the RC return code value unless it has previously been set to a
# non-zero value.
update_return_code() {
    if [ "$RC" -eq "0" ]; then
        RC=$1
    fi
}

# Return the RC return code value unless it has not previously been set.
# If that is the case, pass through the exit code of the last call.
my_exit() {
    if [ "$RC" -eq "0" ]; then
        exit $1
    else
        exit $RC
    fi
}

## Main ----------------------------------------------------------------------

# Trap script termination to return a captured RC value without prematurely
# terminating the script.
trap 'my_exit $?' INT TERM EXIT


# fail hard if the setup fails
set -e
# 1. Clone test repo into working directory.

pushd "${SYS_WORKING_DIR}"
git clone "${SYS_TEST_SOURCE_REPO}"
pushd "${SYS_TEST_SOURCE}"

# Checkout defined branch
git checkout "${SYS_TEST_BRANCH}"
echo "${SYS_TEST_SOURCE} at SHA $(git rev-parse HEAD)"

# Gather submodules
git submodule init
git submodule update --recursive


# fail softly if the tests or artifact gathering fails
set +e
# 2. Execute script from repo
./execute_tests.sh
update_return_code $?

# 3. Collect results from script
mkdir -p "${RE_HOOK_RESULT_DIR}" || true      #ensure that result dir exists
tar -xf test_results.tar -C "${RE_HOOK_RESULT_DIR}"
update_return_code $?

# 4. Collect logs from script
mkdir -p "${RE_HOOK_ARTIFACT_DIR}" || true    #ensure that artifact dir exists
# Molecule does not produce logs outside of STDOUT
update_return_code $?

popd
# End run_system_tests.sh
