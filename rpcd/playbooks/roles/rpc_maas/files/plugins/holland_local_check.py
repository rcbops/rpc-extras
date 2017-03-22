#!/usr/bin/env python

# Copyright 2016, Rackspace US, Inc.
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
import datetime
import shlex
import subprocess

from maas_common import metric
from maas_common import metric_bool
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
        description='Check holland backup completion')
    parser.add_argument('galera_container_name',
                        help='Name of the Galera container running holland')
    parser.add_argument('holland_binary', nargs='?',
                        help='Absolute path to the holland binary',
                        default='/usr/local/bin/holland')
    parser.add_argument('holland_backupset', nargs='?',
                        help='Name of the holland backupset',
                        default='rpc_support')
    return parser.parse_args()


def print_metrics(name, size):
    metric('hollabd_backup_size', 'double', size, 'Megabytes')


def container_holland_lb_check(container, binary, backupset):
    backupsets = []

    # Call holland directly inside container
    retcode, output, err = run_command('lxc-attach -n %s -- %s lb' %
                                       (container, binary))

    if retcode > 0:
            status_err('Could not list holland backupsets: %s' % (err))

    for line in output.split():
        if backupset + '/' in line:
            backupname = line.split('/')[-1]
            disksize = 0

            # Determine size of the backup
            retcode, output, err = \
                run_command('lxc-attach -n %s -- '
                            'du -ks /var/backup/holland_backups/%s/%s' %
                            (container, backupset, backupname))
            if retcode == 0:
                disksize = output.split()[0]

            # Populate backupset informations
            backupsets.append([backupname, disksize])

    return backupsets


def main():
    args = parse_args()
    galera_container = args.galera_container_name
    holland_bin = args.holland_binary
    holland_bs = args.holland_backupset

    today = datetime.date.today().strftime('%Y%m%d')
    yesterday = (datetime.date.today() -
                 datetime.timedelta(days=1)).strftime('%Y%m%d')

    # Get completed Holland backup set
    backupsets = \
        container_holland_lb_check(galera_container, holland_bin, holland_bs)

    if len([backup for backup in backupsets
            if yesterday or today in backup[0]]) > 0:
        status_ok()
        metric_bool('holland_backup_status', True)
    else:
        status_err('Could not find Holland backup from %s or %s'
                   % (yesterday, today))
        metric_bool('holland_backup_status', False)

    # Print metric about last backup
    print_metrics('holland_backup_size', float(backupsets[-1][1]) / 1024)


if __name__ == '__main__':
    with print_output():
        main()
