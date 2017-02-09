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
import argparse
import shlex
import subprocess


from maas_common import metric
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def run_command(arg):
    proc = subprocess.Popen(shlex.split(arg),
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            shell=False)

    out, err = proc.communicate()
    ret = proc.returncode
    return ret, out, err


def parse_args():
    parser = argparse.ArgumentParser(
        description='Check space in a volume group')
    parser.add_argument('vgname',
                        help='Name of volume group to query')
    return parser.parse_args()


def print_metrics(sizes, vgname):
    status_ok()
    metric('%s_vg_total_space' % vgname, 'int64',
           sizes['totalsize'], 'Megabytes')
    metric('%s_vg_free_space' % vgname, 'int64',
           sizes['free'], 'Megabytes')
    metric('%s_vg_used_space' % vgname, 'int64',
           sizes['used'], 'Megabytes')


def main():
    args = parse_args()
    vgname = args.vgname
    command = ('vgs %s --noheadings --units M '
               '--nosuffix -o vg_size,vg_free') % (vgname)
    retcode, output, err = run_command(command)

    if retcode > 0:
        status_err(err)

    if not output:
        status_err('No output received from vgs command. '
                   'Cannot gather metrics.')

    totalsize, free = [int(float(x)) for x in output.split()]
    used = totalsize - free
    sizes = {}
    sizes['totalsize'] = totalsize
    sizes['free'] = free
    sizes['used'] = used
    print_metrics(sizes, vgname)


if __name__ == '__main__':
    with print_output():
        main()
