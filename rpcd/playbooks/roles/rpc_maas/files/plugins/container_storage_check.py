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

import argparse
import os
import psutil

import lxc

from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


class Chroot(object):
    def __init__(self, path):
        self.path = path
        self.root = os.open('/', os.O_RDONLY)  # Get real root path
        self.cwd = os.getcwd()  # Get current dir

    def __enter__(self):
        os.chroot(self.path)

    def __exit__(self, type, value, traceback):
        os.fchdir(self.root)
        os.chroot('.')
        os.chdir(self.cwd)


def disk_usage(part):
    st = os.statvfs(part.mountpoint)
    used = (st.f_blocks - st.f_bfree) * st.f_frsize
    total = st.f_blocks * st.f_frsize
    return 100 * float(used) / float(total)


def container_check(thresh):
    containers = lxc.list_containers()
    for container in containers:
        c = lxc.Container(container)
        with Chroot('/proc/%s/root' % int(c.init_pid)):
            for partition in psutil.disk_partitions():
                percent_used = disk_usage(part=partition)
                if percent_used >= thresh:
                    return False
    else:
        return True


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--thresh',
        required=True,
        type=int,
        help='Critical threshold'
    )
    return parser.parse_args()


def main():
    args = get_args()
    _container_check = False
    try:
        _container_check = container_check(thresh=args.thresh)
    except Exception as e:
        status_err(str(e))
    else:
        status_ok()
    finally:
        metric_bool(
            'container_storage_percent_used_critical',
            _container_check
        )


if __name__ == '__main__':
    with print_output():
        main()
