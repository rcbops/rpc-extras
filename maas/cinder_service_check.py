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
import requests
from maas_common import (status_ok, status_err, get_keystone_client,
                         metric_bool, get_auth_ref, print_output)
from requests import exceptions as exc

# NOTE(mancdaz): until https://review.openstack.org/#/c/111051/
# lands, there is no way to pass a custom (local) endpoint to
# cinderclient. Only way to test local is direct http. :sadface:


def check(auth_ref, args):

    keystone = get_keystone_client(auth_ref)
    auth_token = keystone.auth_token
    VOLUME_ENDPOINT = 'http://{hostname}:8776/v1/{tenant}' \
                      .format(hostname=args.hostname,
                              tenant=keystone.tenant_id)

    s = requests.Session()

    s.headers.update(
        {'Content-type': 'application/json',
         'x-auth-token': auth_token})

    try:
        # We cannot do /os-services?host=X as cinder returns a hostname of
        # X@lvm for cinder-volume binary
        r = s.get('%s/os-services' % VOLUME_ENDPOINT, verify=False, timeout=10)
    except (exc.ConnectionError,
            exc.HTTPError,
            exc.Timeout) as e:
        status_err(str(e))

    if not r.ok:
        status_err('could not get response from cinder api')

    services = r.json()['services']

    if len(services) == 0:
        status_err('No host(s) found in the service list')

    status_ok()
    for service in services:
        service_is_up = True
        if service['status'] == 'enabled' and service['state'] != 'up':
            service_is_up = False

        # We need to match against a host of X and X@lvm (or whatever backend)
        if args.host and args.host in service['host']:
            name = '%s_status' % service['binary']
        else:
            name = '%s_on_host_%s' % (service['binary'], service['host'])

        metric_bool(name, service_is_up)


def main(args):
    auth_ref = get_auth_ref()
    check(auth_ref, args)

if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check cinder services')
        parser.add_argument('hostname',
                            type=str,
                            help='Cinder API hostname or IP address')
        parser.add_argument('--host',
                            type=str,
                            help='Only return metrics for the specified host')
        args = parser.parse_args()
        main(args)
