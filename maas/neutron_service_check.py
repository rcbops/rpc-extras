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
from maas_common import (get_neutron_client, status_err, status_ok,
                         metric_bool, print_output)


def check(args):

    NETWORK_ENDPOINT = 'http://{hostname}:9696'.format(hostname=args.hostname)
    try:
        neutron = get_neutron_client(endpoint_url=NETWORK_ENDPOINT)

    # not gathering api status metric here so catch any exception
    except Exception as e:
        status_err(str(e))

    # gather nova service states
    if args.host:
        agents = neutron.list_agents(host=args.host)['agents']
    else:
        agents = neutron.list_agents()['agents']

    if len(agents) == 0:
        status_err("No host(s) found in the agents list")

    # return all the things
    status_ok()
    for agent in agents:
        agent_is_up = True
        if agent['admin_state_up'] and not agent['alive']:
            agent_is_up = False

        if args.host:
            name = '%s_status' % agent['binary']
        else:
            name = '%s_%s_on_host_%s' % (agent['binary'],
                                         agent['id'],
                                         agent['host'])

        metric_bool(name, agent_is_up)


def main(args):
    check(args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check neutron agents')
        parser.add_argument('hostname',
                            type=str,
                            help='Neutron API hostname or IP address')
        parser.add_argument('--host',
                            type=str,
                            help='Only return metrics for specified host',
                            default=None)
        args = parser.parse_args()
        main(args)
