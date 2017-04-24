#!/bin/bash
# Copyright 2017, Rackspace US, Inc.
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
#
# -----------------------------------------------------------------------------
#
# Check for bad swift disks using the following methodology
#
# Current_Pending_Sector > 0
# Reallocated_Event_Count > 10
#

for DISK in $(ls -l /dev/disk/by-label | grep disk[0-9]* | tr -d '../' | awk '{ print $NF ":" $(NF-2) }'); do
    DEV="/dev/$(echo ${DISK} | awk -F: '{ print $1 }')"
    LABEL=$(echo ${DISK} | awk -F: '{ print $2 }')
    SMART=$(/usr/sbin/smartctl -a ${DEV})
    RESULTS=$(echo "${SMART}" | awk '/Serial Number|Current_Pending_Sector|Reallocated_Event_Count/')
    SN=$(echo "${RESULTS}" | awk '/Serial Number/ { print $NF }')
    CPS=$(echo "${RESULTS}" | awk '/Current_Pending_Sector/ { print $NF }')
    REC=$(echo "${RESULTS}" | awk '/Reallocated_Event_Count/ { print $NF }')

    if [[ ${CPS} > 0 && ${REC} > 10 ]]; then
        echo -e "${LABEL} (SN: ${SN}) should be replaced. Current_Pending_Sector: ${CPS}, Reallocated_Event_Count: ${REC}."
    elif [[ ${CPS} > 0 ]]; then
        echo -e "${LABEL} (SN: ${SN}) should be replaced. Current_Pending_Sector: ${CPS}."
    elif [[ ${REC} > 10 ]]; then
        echo -e "${LABEL} (SN: ${SN}) should be replaced. Reallocated_Event_Count: ${REC}."
    fi
done
