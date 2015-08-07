#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# (c) 2015, Nolan Brubaker <nolan.brubaker@rackspace.com>
set -eux -o pipefail

FAILED=0

function run_or_print() {
        command="$@"
        if [ $FAILED -ne 0 ]; then
                echo "  ${command}"
        else
                eval "$command"
                FAILED=$?
                if [ $FAILED -ne 0 ]; then
                    echo "******************** FAILURE ********************"
                    echo "The upgrade script has failed. Please rerun the following task to continue"
                    echo "Failed on task ${command}"
                    echo "Do NOT rerun the upgrade script!"
                    echo "Please execute the remaining tasks:"
                fi
        fi
}

BASE_DIR=$( cd "$( dirname ${0} )" && cd ../ && pwd )
OSAD_DIR="$BASE_DIR/os-ansible-deployment"
RPCD_DIR="$BASE_DIR/rpcd"

resume.sh < upgrade.steps
