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
import collections

import ipaddr
from maas_common import get_auth_ref
from maas_common import get_nova_client
from maas_common import metric
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok

# The actual stat names from novaclient are nasty, so this mapping is used to
# translate them to something more consistent and usable, as well as set the
# units for each metric
stats_mapping = {
    'hypervisor_count': {
        'stat_name': 'count', 'unit': 'hypervisors', 'type': 'uint32'
    },
    'total_disk_space': {
        'stat_name': 'local_gb', 'unit': 'Gigabytes', 'type': 'uint32'
    },
    'used_disk_space': {
        'stat_name': 'local_gb_used', 'unit': 'Gigabytes', 'type': 'uint32'
    },
    'free_disk_space': {
        'stat_name': 'free_disk_gb', 'unit': 'Gigabytes', 'type': 'uint32'
    },
    'total_memory': {
        'stat_name': 'memory_mb', 'unit': 'Megabytes', 'type': 'uint32'
    },
    'used_memory': {
        'stat_name': 'memory_mb_used', 'unit': 'Megabytes', 'type': 'uint32'
    },
    'free_memory': {
        'stat_name': 'free_ram_mb', 'unit': 'Megabytes', 'type': 'uint32'
    },
    'total_vcpus': {
        'stat_name': 'vcpus', 'unit': 'vcpu', 'type': 'uint32'
    },
    'used_vcpus': {
        'stat_name': 'vcpus_used', 'unit': 'vcpu', 'type': 'uint32'
    }
}


def check(args):
    auth_ref = get_auth_ref()
    auth_token = auth_ref['auth_token']
    tenant_id = auth_ref['project']['id']

    COMPUTE_ENDPOINT = (
        'http://{ip}:8774/v2/{tenant_id}'.format(ip=args.ip,
                                                 tenant_id=tenant_id)
    )

    try:
        nova = get_nova_client(auth_token=auth_token,
                               bypass_url=COMPUTE_ENDPOINT)
    except Exception as e:
        status_err(str(e))
    else:
        # get some cloud stats
        stats = nova.hypervisor_stats.statistics()
        cloud_stats = collections.defaultdict(dict)
        for metric_name, vals in stats_mapping.iteritems():
            multiplier = 1
            if metric_name == 'total_vcpus':
                multiplier = args.cpu_allocation_ratio
            elif metric_name == 'total_memory':
                multiplier = args.mem_allocation_ratio
            cloud_stats[metric_name]['value'] = \
                (getattr(stats, vals['stat_name']) * multiplier)
            cloud_stats[metric_name]['unit'] = \
                vals['unit']
            cloud_stats[metric_name]['type'] = \
                vals['type']

    status_ok()
    for metric_name in cloud_stats.iterkeys():
        metric('cloud_resource_%s' % metric_name,
               cloud_stats[metric_name]['type'],
               cloud_stats[metric_name]['value'],
               cloud_stats[metric_name]['unit'])


def main(args):
    check(args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(
            description='Check Nova hypervisor stats')
        parser.add_argument('--cpu',
                            type=float,
                            default=1.0,
                            required=False,
                            action='store',
                            dest='cpu_allocation_ratio',
                            help='cpu allocation ratio')
        parser.add_argument('--mem',
                            type=float,
                            default=1.0,
                            required=False,
                            action='store',
                            dest='mem_allocation_ratio',
                            help='mem allocation ratio')
        parser.add_argument('ip', nargs='?',
                            type=ipaddr.IPv4Address,
                            help='nova API IP address')
        args = parser.parse_args()
        main(args)
