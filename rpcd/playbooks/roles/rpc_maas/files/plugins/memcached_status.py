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

import argparse
import re

import ipaddr
from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok
import memcache


VERSION_RE = re.compile('STAT version (\d+\.\d+\.\d+)(?![-+0-9\\.])')
VERSIONS = ['1.4.14 (Ubuntu)', '1.4.15']
MEMCACHE_METRICS = {'total_items': 'items',
                    'get_hits': 'cache_hits',
                    'get_misses': 'cache_misses',
                    'curr_connections': 'connections'}


def item_stats(host, port):
    """Check the stats for items and connection status."""

    stats = None
    try:
        mc = memcache.Client(['%s:%s' % (host, port)])
        stats = mc.get_stats()[0][1]
    except IndexError:
        raise
    finally:
        return stats


def main(args):

    bind_ip = str(args.ip)
    port = args.port
    is_up = True

    try:
        stats = item_stats(bind_ip, port)
        current_version = stats['version']
    except (TypeError, IndexError):
        is_up = False
    else:
        is_up = True
        if current_version not in VERSIONS:
            status_err('This plugin has only been tested with version %s '
                       'of memcached, and you are using version %s'
                       % (VERSIONS, current_version))

    status_ok()
    metric_bool('memcache_api_local_status', is_up)
    if is_up:
        for m, u in MEMCACHE_METRICS.iteritems():
            metric('memcache_%s' % m, 'uint64', stats[m], u)


if __name__ == '__main__':
    with print_output():
        parser = argparse.ArgumentParser(description='Check memcached status')
        parser.add_argument('ip', type=ipaddr.IPv4Address,
                            help='memcached IP address.')
        parser.add_argument('--port', type=int,
                            default=11211, help='memcached port.')
        args = parser.parse_args()
        main(args)
