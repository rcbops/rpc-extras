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
import subprocess

from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok
import requests

OVERVIEW_URL = "http://%s:%s/api/overview"
NODES_URL = "http://%s:%s/api/nodes"
CONNECTIONS_URL = "http://%s:%s/api/connections?columns=channels"
QUEUES_URL = "http://%s:%s/api/queues"

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

CONNECTIONS_METRICS = {"max_channels_per_conn": "channels"}


def hostname():
    """Return the name of the current host/node."""
    return subprocess.check_output(['hostname', '-s']).strip()


def rabbit_version(node):
    if ('applications' in node and 'rabbit' in node['applications']
            and 'version' in node['applications']['rabbit']):
        version_string = node['applications']['rabbit']['version']
        return tuple(int(part) for part in version_string.split('.'))
    else:
        return tuple()


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


def _get_rabbit_json(session, url):
    try:
        response = session.get(url)
    except requests.exceptions.ConnectionError as e:
        status_err(str(e))

    if response.ok:
        return response.json()
    else:
        status_err('Received status {0} from RabbitMQ API'.format(
            response.status_code))


def _get_connection_metrics(session, metrics, host, port):

    response = _get_rabbit_json(session, CONNECTIONS_URL % (host, port))

    max_chans = max(connection['channels'] for connection in response
                    if 'channels' in connection)
    for k in CONNECTIONS_METRICS:
        metrics[k] = {'value': max_chans, 'unit': CONNECTIONS_METRICS[k]}


def _get_overview_metrics(session, metrics, host, port):
    response = _get_rabbit_json(session, OVERVIEW_URL % (host, port))

    for k in OVERVIEW_METRICS:
        if k in response:
            for a, b in OVERVIEW_METRICS[k].items():
                if a in response[k]:
                    metrics[a] = {'value': response[k][a], 'unit': b}


def _get_node_metrics(session, metrics, host, port, name):
    response = _get_rabbit_json(session, NODES_URL % (host, port))

    # Either use the option provided by the commandline flag or the current
    # hostname
    name = '@' + (name or hostname())
    is_cluster_member = False

    # Ensure this node is a member of the cluster
    nodes_matching_name = [n for n in response
                           if n['name'].endswith(name)]
    is_cluster_member = any(nodes_matching_name)

    if CLUSTERED:
        if len(response) < CLUSTER_SIZE:
            status_err('cluster too small')
        if not is_cluster_member:
            status_err('{0} not a member of the cluster'.format(name))

    for k, v in NODES_METRICS.items():
        metrics[k] = {'value': nodes_matching_name[0][k], 'unit': v}

    # We don't know exactly which version introduces data for all
    #   nodes in the cluster returned by the NODES_URL, but we know it is
    #   in 3.5.x at least.
    if rabbit_version(nodes_matching_name[0]) > (3, 5):
        # Gather the queue lengths for all nodes in the cluster
        queues = [n['run_queue'] for n in response
                  if n.get('run_queue', None)]
        # Grab the first queue length
        first = queues.pop()
        # Check that all other queues are equal to it
        if not all(first == q for q in queues):
            # If they're not, the queues are not synchronized
            status_err('Cluster not replicated across all nodes')


def _get_queue_metrics(session, metrics, host, port):
    response = _get_rabbit_json(session, QUEUES_URL % (host, port))
    notification_messages = sum([q['messages'] for q in response
                                if q['name'].startswith('notifications.')])

    metrics['notification_messages'] = {
        'value': notification_messages,
        'unit': 'messages'
    }
    metrics['msgs_excl_notifications'] = {
        'value': metrics['messages']['value'] - notification_messages,
        'unit': 'messages'
    }


def main():
    (options, _) = parse_args()
    metrics = {}
    session = requests.Session()  # Make a Session to store the auth creds
    session.auth = (options.username, options.password)

    _get_connection_metrics(session, metrics, options.host, options.port)
    _get_overview_metrics(session, metrics, options.host, options.port)
    _get_node_metrics(session, metrics, options.host, options.port,
                      options.name)
    _get_queue_metrics(session, metrics, options.host, options.port)

    status_ok()

    for k, v in metrics.items():
        if v['value'] is True or v['value'] is False:
            metric_bool('rabbitmq_%s_status' % k, not v['value'])
        else:
            metric('rabbitmq_%s' % k, 'int64', v['value'], v['unit'])


if __name__ == "__main__":
    with print_output():
        main()
