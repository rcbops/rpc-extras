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
import requests
from ipaddr import IPv4Address
from maas_common import (status_ok, status_err, metric, metric_bool,
                         get_keystone_client, get_auth_ref, print_output)
from requests import exceptions as exc

VOLUME_STATUSES = ['available', 'in-use', 'error']

# NOTE(mancdaz): until https://review.openstack.org/#/c/111051/
# lands, there is no way to pass a custom (local) endpoint to
# cinderclient. Only way to test local is direct http. :sadface:


def check(auth_ref, args):

    keystone = get_keystone_client(auth_ref)
    auth_token = keystone.auth_token
    VOLUME_ENDPOINT = ('http://{ip}:8776/v1/{tenant}'.format
                       (ip=args.ip, tenant=keystone.tenant_id))

    s = requests.Session()

    s.headers.update(
        {'Content-type': 'application/json',
         'x-auth-token': auth_token})

    try:
        vol = s.get('%s/volumes/detail' % VOLUME_ENDPOINT,
                    verify=False,
                    timeout=10)
        milliseconds = vol.elapsed.total_seconds() * 1000
        snap = s.get('%s/snapshots/detail' % VOLUME_ENDPOINT,
                     verify=False,
                     timeout=10)
        is_up = vol.ok and snap.ok
    except (exc.ConnectionError,
            exc.HTTPError,
            exc.Timeout) as e:
        is_up = False
    except Exception as e:
           status_err(str(e))
    else:
        # gather some metrics
        vol_statuses = [v['status'] for v in vol.json()['volumes']]
        vol_status_count = collections.Counter(vol_statuses)
        total_vols = len(vol.json()['volumes'])

        snap_statuses = [v['status'] for v in snap.json()['snapshots']]
        snap_status_count = collections.Counter(snap_statuses)
        total_snaps = len(snap.json()['snapshots'])

    status_ok()
    metric_bool('cinder_api_local_status', is_up)
    # only want to send other metrics if api is up
    if is_up:
        metric('cinder_api_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')
        metric('total_cinder_volumes', 'uint32', total_vols, 'volumes')
        for status in VOLUME_STATUSES:
            metric('cinder_%s_volumes' % status,
                   'uint32',
                   vol_status_count[status], 'volumes')
        metric('total_cinder_snapshots', 'uint32', total_snaps, 'snapshots')
        for status in VOLUME_STATUSES:
            metric('cinder_%s_snaps' % status,
                   'uint32',
                   snap_status_count[status], 'snapshots')


def main(args):
    auth_ref = get_auth_ref()
    check(auth_ref, args)

if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check cinder API')
        parser.add_argument('ip',
                            type=IPv4Address,
                            help='cinder API IP address')
        args = parser.parse_args()
        main(args)
