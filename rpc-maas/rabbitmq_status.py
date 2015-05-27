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


import optparse
import requests
import subprocess

from maas_common import (metric, metric_bool, status_ok, status_err,
                         print_output)

OVERVIEW_URL = "http://%s:%s/api/overview"
NODES_URL = "http://%s:%s/api/nodes"
CHANNEL_URL = "http://%s:%s/api/channels"

CLUSTERED = True
CLUSTER_SIZE = 3

# {metric_category: {metric_name: metric_unit}}
OVERVIEW_METRICS = {"queue_totals": {"messages": "messages",
                                     "messages_ready": "messages",
                                     "messages_unacknowledged": "messages"},
                    "message_stats": {"get": "messages",
                                      "ack": "messages",
                                      "deliver_get": "messages",
                                      "deliver": "messages",
                                      "publish": "messages"}}
# {metric_name: metric_unit}
NODES_METRICS = {"proc_used": "processes",
                 "proc_total": "processes",
                 "fd_used": "fd",
                 "fd_total": "fd",
                 "sockets_used": "fd",
                 "sockets_total": "fd",
                 "mem_used": "bytes",
                 "mem_limit": "bytes",
                 "mem_alarm": "status",
                 "disk_free_alarm": "status",
                 "uptime": "ms"}


def hostname():
    """Return the name of the current host/node."""
    return subprocess.check_output(['hostname']).strip()


def parse_args():
    parser = optparse.OptionParser(
        usage='%prog [-h] [-H hostname] [-P port] [-u username] [-p password]'
    )
    parser.add_option('-H', '--host', action='store', dest='host',
                      default='localhost',
                      help='Host address to use when connecting')
    parser.add_option('-P', '--port', action='store', dest='port',
                      default='15672',
                      help='Port to use when connecting')
    parser.add_option('-U', '--username', action='store', dest='username',
                      default='guest',
                      help='Username to use for authentication')
    parser.add_option('-p', '--password', action='store', dest='password',
                      default='guest',
                      help='Password to use for authentication')
    parser.add_option('-n', '--name', action='store', dest='name',
                      default=None,
                      help=("Check a node's cluster membership using the "
                            'provided name'))
    return parser.parse_args()


def main():
    (options, _) = parse_args()
    metrics = {}
    s = requests.Session()  # Make a Session to store the authenticate creds
    s.auth = (options.username, options.password)

    try:
        r = s.get(CHANNEL_URL % (options.host, options.port))
    except requests.exceptions.ConnectionError as e:
        status_err(str(e))

    if r.ok:
        resp_json = r.json()  # Parse the JSON once
        if any(channel['number'] > 1 for channel in resp_json):
            status_err('Detected RabbitMQ connections with multiple channels. Please check RabbitMQ and all Openstack consumers')
    else:
        status_err('Received status {0} from RabbitMQ API'.format(
            r.status_code))


    try:
        r = s.get(OVERVIEW_URL % (options.host, options.port))
    except requests.exceptions.ConnectionError as e:
        status_err(str(e))

    if r.ok:
        resp_json = r.json()  # Parse the JSON once
        for k in OVERVIEW_METRICS:
            if k in resp_json:
                for a, b in OVERVIEW_METRICS[k].items():
                    if a in resp_json[k]:
                        metrics[a] = {'value': resp_json[k][a], 'unit': b}
    else:
        status_err('Received status {0} from RabbitMQ API'.format(
            r.status_code))

    try:
        r = s.get(NODES_URL % (options.host, options.port))
    except requests.exceptions.ConnectionError as e:
        status_err(str(e))

    # Either use the option provided by the commandline flag or the current
    # hostname
    name = '@' + (options.name or hostname())
    is_cluster_member = False
    if r.ok:
        resp_json = r.json()
        for k, v in NODES_METRICS.items():
            metrics[k] = {'value': resp_json[0][k], 'unit': v}

        # Ensure this node is a member of the cluster
        is_cluster_member = any(n['name'].endswith(name) for n in resp_json)
        # Gather the queue lengths for all nodes in the cluster
        queues = [n['run_queue'] for n in resp_json]
        # Grab the first queue length
        first = queues.pop()
        # Check that all other queues are equal to it
        if not all(first == q for q in queues):
            # If they're not, the queues are not synchronized
            print "status err cluster not replicated across all nodes"
    else:
        status_err('Received status {0} from RabbitMQ API'.format(
            r.status_code))

    if CLUSTERED:
        if len(r.json()) < CLUSTER_SIZE:
            status_err('cluster too small')
        if not is_cluster_member:
            status_err('{0} not a member of the cluster'.format(name))



    status_ok()

    for k, v in metrics.items():
        if v['value'] is True or v['value'] is False:
            metric_bool('rabbitmq_%s_status' % k, not v['value'])
        else:
            metric('rabbitmq_%s' % k, 'int64', v['value'], v['unit'])


if __name__ == "__main__":
    with print_output():
        main()
