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
from time import time
from ipaddr import IPv4Address
from maas_common import (get_neutron_client, metric,
                         status_err, status_ok, metric_bool, print_output)
from neutronclient.client import exceptions as exc


def check(args):

    NETWORK_ENDPOINT = 'http://{ip}:9696'.format(ip=args.ip)

    try:
        neutron = get_neutron_client(endpoint_url=NETWORK_ENDPOINT)
        is_up = True
    # if we get a NeutronClientException don't bother sending any other metric
    # The API IS DOWN
    except exc.NeutronClientException:
        is_up = False
    # Any other exception presumably isn't an API error
    except Exception as e:
        status_err(str(e))
    else:
        # time something arbitrary
        start = time()
        neutron.list_agents()
        end = time()
        milliseconds = (end - start) * 1000

        # gather some metrics
        networks = len(neutron.list_networks()['networks'])
        agents = len(neutron.list_agents()['agents'])
        routers = len(neutron.list_routers()['routers'])
        subnets = len(neutron.list_subnets()['subnets'])

    status_ok()
    metric_bool('neutron_api_local_status', is_up)
    # only want to send other metrics if api is up
    if is_up:
        metric('neutron_api_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')
        metric('neutron_networks', 'uint32', networks, 'networks')
        metric('neutron_agents', 'uint32', agents, 'agents')
        metric('neutron_routers', 'uint32', routers, 'agents')
        metric('neutron_subnets', 'uint32', subnets, 'subnets')


def main(args):
    check(args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check neutron API')
        parser.add_argument('ip',
                            type=IPv4Address,
                            help='neutron API IP address')
        args = parser.parse_args()
        main(args)
