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
from ipaddr import IPv4Address
from maas_common import (status_ok, status_err, metric, metric_bool,
                         print_output)
from requests import exceptions as exc


def check(args):
    metadata_endpoint = ('http://{ip}:8775'.format(ip=args.ip))
    is_up = True

    s = requests.Session()

    try:
        # looks like we can only get / (ec2 versions) without specifying
        # an instance ID and other headers
        versions = s.get('%s/' % metadata_endpoint,
                         verify=False,
                         timeout=10)
        milliseconds = versions.elapsed.total_seconds() * 1000
        if not versions.ok or '1.0' not in versions.content.splitlines():
            is_up = False
    except (exc.ConnectionError, exc.HTTPError, exc.Timeout) as e:
        is_up = False
    except Exception as e:
        status_err(str(e))

    status_ok()
    metric_bool('nova_api_metadata_local_status', is_up)
    # only want to send other metrics if api is up
    if is_up:
        metric('nova_api_metadata_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')


def main(args):
    check(args)

if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(
            description='Check nova-api-metdata API')
        parser.add_argument('ip',
                            type=IPv4Address,
                            help='nova-api-metadata IP address')
        args = parser.parse_args()
        main(args)
