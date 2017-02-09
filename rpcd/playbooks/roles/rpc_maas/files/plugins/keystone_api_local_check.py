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
from maas_common import get_keystone_client
from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def check(args):

    IDENTITY_ENDPOINT = 'http://{ip}:35357/v3'.format(ip=args.ip)

    try:
        keystone = get_keystone_client(endpoint=IDENTITY_ENDPOINT)
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
        metric('keystone_tenant_count', 'uint32', project_count, 'tenants')


def main(args):
    check(args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check keystone API')
        parser.add_argument('ip',
                            type=ipaddr.IPv4Address,
                            help='keystone API IP address')
        args = parser.parse_args()
        main(args)
