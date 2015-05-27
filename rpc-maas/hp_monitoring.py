#!/usr/bin/env python

# Copyright 2015, Rackspace US, Inc.
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

import maas_common
import subprocess


class BadOutputError(maas_common.MaaSException):
    pass


def check_command(command, startswith, endswith):
    output = subprocess.check_output(command)
    lines = output.split('\n')
    matches = False
    for line in lines:
        line = line.strip()
        if line.startswith(startswith):
            matches = True
            if not line.endswith(endswith):
                status = 0
                break
    else:
        if matches:
            status = 1
        else:
            raise BadOutputError(
                'The output was not in the expected format:\n%s' % output)
    return status


def get_hpasmcli_status(thing):
    return check_command(('hpasmcli', '-s', 'show %s' % thing),
                         'Status', 'Ok')


def get_drive_status():
    return check_command(('hpssacli', 'ctrl', 'all', 'show', 'config'),
                         'logicaldrive', 'OK)')


def main():
    status = {}
    status['hardware_processors_status'] = get_hpasmcli_status('server')
    status['hardware_memory_status'] = get_hpasmcli_status('dimm')
    status['hardware_disk_status'] = get_drive_status()

    maas_common.status_ok()
    for name, value in status.viewitems():
        maas_common.metric_bool(name, value)


if __name__ == '__main__':
    with maas_common.print_output():
        main()
