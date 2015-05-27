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

import errno
import maas_common


class MissingModuleError(maas_common.MaaSException):
    pass

def get_value(path):
    try:
        with open(path) as f:
            value = f.read()
    except IOError as e:
        if e.errno == errno.ENOENT:
            msg = ('Unable to read "%s", the appropriate kernel module is '
                   'probably not loaded.' % path)
            raise MissingModuleError(msg)

    return value.strip()


def get_metrics():
    metrics = {
        'nf_conntrack_count': {
            'path': '/proc/sys/net/netfilter/nf_conntrack_count'},
        'nf_conntrack_max': {
            'path': '/proc/sys/net/netfilter/nf_conntrack_max'}}

    for data in metrics.viewvalues():
        data['value'] = get_value(data['path'])

    return metrics


def main():
    try:
        metrics = get_metrics()
    except maas_common.MaaSException as e:
        maas_common.status_err(str(e))
    else:
        maas_common.status_ok()
        for name, data in metrics.viewitems():
            maas_common.metric(name, 'uint32', data['value'])


if __name__ == '__main__':
    with maas_common.print_output():
        main()
