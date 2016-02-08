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
import collections
import time

import ipaddr
from maas_common import get_auth_ref
from maas_common import get_keystone_client
from maas_common import get_nova_client
from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok
from novaclient.client import exceptions as exc

SERVER_STATUSES = ['ACTIVE', 'STOPPED', 'ERROR']


def check(auth_ref, args):
    keystone = get_keystone_client(auth_ref)
    tenant_id = keystone.tenant_id

    COMPUTE_ENDPOINT = (
        'http://{ip}:8774/v2/{tenant_id}'.format(ip=args.ip,
                                                 tenant_id=tenant_id)
    )

    try:
        if args.ip:
            nova = get_nova_client(bypass_url=COMPUTE_ENDPOINT)
        else:
            nova = get_nova_client()

        is_up = True
    except exc.ClientException:
        is_up = False
    # Any other exception presumably isn't an API error
    except Exception as e:
        status_err(str(e))
    else:
        # time something arbitrary
        start = time.time()
        nova.services.list()
        end = time.time()
        milliseconds = (end - start) * 1000

        servers = nova.servers.list(search_opts={'all_tenants': 1})
        # gather some metrics
        status_count = collections.Counter([s.status for s in servers])

    status_ok()
    metric_bool('nova_api_local_status', is_up)
    # only want to send other metrics if api is up
    if is_up:
        metric('nova_api_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')
        for status in SERVER_STATUSES:
            metric('nova_instances_in_state_%s' % status,
                   'uint32',
                   status_count[status], 'instances')


def main(args):
    auth_ref = get_auth_ref()
    check(auth_ref, args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(
            description='Check Nova API against local or remote address')
        parser.add_argument('ip', nargs='?',
                            type=ipaddr.IPv4Address,
                            help='Optional Nova API server address')
        args = parser.parse_args()
        main(args)
