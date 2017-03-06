#!/usr/bin/env python
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
"""Check for failed (or failing) disks."""
import argparse
import os
import re
import shlex
import subprocess


from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def run_cmd(command, command_input=None):
    """Run a command and get the output."""
    if isinstance(command, str):
        command = shlex.split(command)

    try:
        output = subprocess.check_output(command)
    except Exception:
        return False

    return output


def adaptec_check():
    """Query SMART data for JBODs connected to Adaptec HBAs."""
    script_path = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            'jbod_checker.sh'
        )
    )
    output = run_cmd(script_path)
    if 'should be replaced' in output:
        failing_disks = 1
    else:
        failing_disks = 0

    report = {
        'failed_disks': 0,
        'failing_disks': failing_disks,
    }

    return report


def hpssacli_check():
    """Use hpssacli to check for failed/failing disks."""
    # Query the RAID status.
    status_cmd = 'hpssacli ctrl all show config'
    output = run_cmd(status_cmd)

    # Search for disks without "OK" as their status
    physical_disks = re.findall(
        r"^\s+(physicaldrive.*)$",
        output,
        re.MULTILINE
    )
    failed_disks = len([x for x in physical_disks if ', OK)' not in x])

    # HP's RAID tools don't provide predictive failure data.
    report = {
        'failed_disks': failed_disks,
        'failing_disks': 0,
    }

    return report


def omreport_check():
    """Use omreport to check for failed/failing disks."""
    failed_disks = 0
    failing_disks = 0

    # Get a list of controllers.
    vdisk_cmd = "omreport storage vdisk"
    output = run_cmd(vdisk_cmd)
    controllers = re.findall(r"^ID\s+:\s+([0-9])+$", output, re.MULTILINE)

    # Loop through each controller to examine physical disks.
    for controller in controllers:
        pdisk_cmd = "omreport storage pdisk controller={}".format(controller)
        output = run_cmd(pdisk_cmd)

        # Find any disks that have failed already.
        disk_states = re.findall(
            r"^State\s+:\s+(.*)$",
            output,
            re.MULTILINE
        )
        failed_disks += len([x for x in disk_states if x != 'Online'])

        # Find any disks that are about to fail.
        disk_predictions = re.findall(
            r"^Failure Predicted\s+:\s+(.*)$",
            output,
            re.MULTILINE
        )
        failing_disks += len([x for x in disk_predictions if x != 'No'])

    report = {
        'failed_disks': failed_disks,
        'failing_disks': failing_disks,
    }

    return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Monitor failed/failing disks'
    )
    parser.add_argument(
        '--raid-type',
        choices=['adaptec', 'hp', 'dell'],
        help="RAID type"
    )
    args = parser.parse_args()

    results = []

    # Check for failed disks in a JBOD connected to an Adaptec HBA.
    if args.raid_type == 'arcconf':
        adaptec_hba = adaptec_check()
        results.append(adaptec_hba)

    # Check for failed disks in HP Smart Arrays.
    if args.raid_type == 'hp':
        hp_raid = hpssacli_check()
        results.append(hp_raid)

    # Check for failed disks in Dell PERC controllers.
    if args.raid_type == 'dell':
        dell_raid = omreport_check()
        results.append(dell_raid)

    with print_output():

        # Did we actually get results?
        if len(results) > 0:
            failed_disks = sum(x['failed_disks'] for x in results)
            failing_disks = sum(x['failing_disks'] for x in results)

            # Print our metrics.
            status_ok()
            metric_bool('failed_disks', failed_disks > 0)
            metric_bool('failing_disks', failing_disks > 0)
        else:
            status_err("Unable to find a RAID device")
