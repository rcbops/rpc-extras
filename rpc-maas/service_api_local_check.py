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

from maas_common import (status_ok, metric, metric_bool,
                         get_keystone_client, get_auth_ref, print_output)
import argparse
from ipaddr import IPv4Address
import requests
from requests import exceptions as exc


def check(args):
    headers = {'Content-type': 'application/json'}
    path_options = {}
    if args.auth:
        auth_ref = get_auth_ref()
        keystone = get_keystone_client(auth_ref)
        auth_token = keystone.auth_token
        tenant_id = keystone.tenant_id
        headers['auth_token'] = auth_token
        path_options['tenant_id'] = tenant_id

    scheme = args.ssl and 'https' or 'http'
    endpoint = '{scheme}://{ip}:{port}'.format(ip=args.ip, port=args.port,
                                               scheme=scheme)
    if args.version is not None:
        path_options['version'] = args.version
    path = args.path.format(path_options)

    s = requests.Session()

    s.headers.update(headers)

    if path and not path.startswith('/'):
        url = '/'.join((endpoint, path))
    else:
        url = ''.join((endpoint, path))
    try:
        r = s.get(url, verify=False, timeout=10)
    except (exc.ConnectionError,
            exc.HTTPError,
            exc.Timeout):
        up = False
    else:
        up = True

    status_ok()
    metric_bool('{name}_api_local_status'.format(name=args.name), up)

    if up and r.ok:
        milliseconds = r.elapsed.total_seconds() * 1000
        metric('{name}_api_local_response_time'.format(name=args.name),
               'double',
               '%.3f' % milliseconds,
               'ms')


def main(args):
    check(args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check service is up.')
        parser.add_argument('name', help='Service name.')
        parser.add_argument('ip', type=IPv4Address, help='Service IP address.')
        parser.add_argument('port', type=int, help='Service port.')
        parser.add_argument('--path', default='',
                            help='Service API path, this should include '
                                 'placeholders for the version "{version}" and '
                                 'tenant ID "{tenant_id}" if required.')
        parser.add_argument('--auth', action='store_true', default=False,
                            help='Does this API check require auth?')
        parser.add_argument('--ssl', action='store_true', default=False,
                            help='Should SSL be used.')
        parser.add_argument('--version', help='Service API version.')
        args = parser.parse_args()
        main(args)
