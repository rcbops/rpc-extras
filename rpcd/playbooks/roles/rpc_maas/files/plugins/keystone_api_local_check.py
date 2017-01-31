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
import time

import ipaddr
from keystoneclient.openstack.common.apiclient import exceptions as exc
from maas_common import get_auth_details
from maas_common import get_keystone_client
from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def check(args, auth_details):

    if auth_details['OS_AUTH_VERSION'] == '2':
        IDENTITY_ENDPOINT = 'http://{ip}:35357/v2.0'.format(ip=args.ip)
    else:
        IDENTITY_ENDPOINT = 'http://{ip}:35357/v3'.format(ip=args.ip)

    try:
        if args.ip:
            keystone = get_keystone_client(endpoint=IDENTITY_ENDPOINT)
        else:
            keystone = get_keystone_client()

        is_up = True
    except (exc.HttpServerError, exc.ClientException):
        is_up = False
    # Any other exception presumably isn't an API error
    except Exception as e:
        status_err(str(e))
    else:
        # time something arbitrary
        start = time.time()
        keystone.services.list()
        end = time.time()
        milliseconds = (end - start) * 1000

        # gather some vaguely interesting metrics to return
        if auth_details['OS_AUTH_VERSION'] == '2':
            project_count = len(keystone.tenants.list())
            user_count = len(keystone.users.list())
        else:
            project_count = len(keystone.projects.list())
            user_count = len(keystone.users.list(domain='Default'))

    status_ok()
    metric_bool('keystone_api_local_status', is_up)
    # only want to send other metrics if api is up
    if is_up:
        metric('keystone_api_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')
        metric('keystone_user_count', 'uint32', user_count, 'users')
        metric('keystone_tenant_count', 'uint32', project_count, 'tenants')


def main(args):
    auth_details = get_auth_details()
    check(args, auth_details)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(
            description='Check Keystone API against local or remote address')
        parser.add_argument(
            'ip',
            nargs='?',
            type=ipaddr.IPv4Address,
            help='Check Keystone API against local or remote address')
        args = parser.parse_args()
        main(args)
