#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -x

## Vars ----------------------------------------------------------------------

export QTEST_API_TOKEN=${RPC_ASC_QTEST_API_TOKEN}
VENV_NAME="venv-qtest"
VENV_PATH="${WORKSPACE}/${VENV_NAME}"
PROJECT_ID="76551"

## Functions -----------------------------------------------------------------

source $(dirname ${0})/../../scripts/functions.sh

## Main ----------------------------------------------------------------------

# Create virtualenv for <TOOL NAME>
virtualenv --no-wheel "${VENV_PATH}"

# Activate virtualenv
source "${VENV_PATH}/bin/activate"

VENV_PIP="${VENV_PATH}/bin/pip"

# Install zigzag from PyPI
${VENV_PIP} install rpc-zigzag

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
    if zigzag $i ${PROJECT_ID}; then
        echo "Upload Success: $i"
    else
        echo "Upload Failure: $i"
    fi
done

# exit is hardcoded since xml from tempest is known to to fail
exit 0
