#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -x

## Vars ----------------------------------------------------------------------

export QTEST_API_TOKEN=${RPC_ASC_QTEST_API_TOKEN}
VENV_NAME="venv-qtest"
VENV_PATH="${WORKSPACE}/${VENV_NAME}"
ZIGZAG_PYPI_PACKAGE="rpc-zigzag~=1.0"
ZIGZAG_CONFIG_FILE="asc_sys-tests_zigzag_config.json"

if [[ ${RE_JOB_ACTION} == "system_staging" ]]; then
    PROJECT_ID="84820"
else
    PROJECT_ID="76551"
fi

## ZigZag Config -------------------------------------------------------------
cat <<-EOF >$ZIGZAG_CONFIG_FILE
{
  "zigzag": {
    "test_cycle": "{{ RPC_PRODUCT_RELEASE }}",
    "project_id": "$PROJECT_ID",
    "module_hierarchy": [
      "{{ JOB_NAME }}",
      "{{ MOLECULE_TEST_REPO }}.{{ MOLECULE_SCENARIO_NAME }}",
      "{{zz_testcase_class}}"
    ],
    "path_to_test_exec_dir": "/molecule/{{ MOLECULE_SCENARIO_NAME }}",
    "build_url": "{{ BUILD_URL }}",
    "build_number": "{{ BUILD_NUMBER }}",
    "test_repo_name": "{{ MOLECULE_TEST_REPO }}",
    "test_branch": "{{ RE_JOB_BRANCH }}",
    "test_fork": "rcbops",
    "test_commit": "{{ MOLECULE_GIT_COMMIT }}"
  }
}
EOF

## Functions -----------------------------------------------------------------

source $(dirname ${0})/../../scripts/functions.sh

## Main ----------------------------------------------------------------------

# Create virtualenv for <TOOL NAME>
virtualenv --no-wheel "${VENV_PATH}"

# Activate virtualenv
source "${VENV_PATH}/bin/activate"

VENV_PIP="${VENV_PATH}/bin/pip"

# Install zigzag from PyPI
${VENV_PIP} install "${ZIGZAG_PYPI_PACKAGE}"

# Search for xml files in RE_HOOK_RESULT_DIR
xml_files=()
while IFS=  read -r -d $'\0' FILE; do
    xml_files+=("${FILE}")
done < <(find ${RE_HOOK_RESULT_DIR} -type f -name 'molecule_test_results.xml' -print0)

# Upload the files
echo "Attempting upload of ${#xml_files[@]} XML files"
printf '%s\n' "${xml_files[@]}"
for i in "${xml_files[@]}"; do
    # Use <TOOL NAME> to process and upload to qtest
    if zigzag $ZIGZAG_CONFIG_FILE $i; then
        echo "Upload Success: $i"
    else
        echo "Upload Failure: $i"
    fi
done

# exit is hardcoded since xml from tempest is known to to fail
exit 0
