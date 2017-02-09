#!/usr/bin/env python

# Copyright 2014, Rackspace US, Inc.
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

import shlex
import subprocess

from maas_common import metric
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def utilisation(time):
    output = subprocess.check_output(shlex.split('iostat -x -d %s 2' % time))
    device_lines = output.split('\nDevice:')[-1].strip().split('\n')[1:]
    devices = [d for d in device_lines if not d.startswith(('dm-', 'nb'))]
    devices = [d.split() for d in devices]
    utils = [(d[0], d[-1]) for d in devices]
    return utils

if __name__ == '__main__':
    with print_output():
        try:
            utils = utilisation(5)
        except Exception as e:
            status_err(e)
        else:
            status_ok()
            for util in utils:
                metric('disk_utilisation_%s' % util[0], 'double', util[1], '%')
