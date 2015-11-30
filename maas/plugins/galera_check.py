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
from __future__ import division

import optparse
import shlex
import subprocess


from maas_common import metric
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def galera_check(arg):
    proc = subprocess.Popen(shlex.split(arg),
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            shell=False)

    out, err = proc.communicate()
    ret = proc.returncode
    return ret, out, err


def generate_query(host, port, type='status'):
    if host:
        host = ' -h %s' % host
    else:
        host = ''

    if port:
        port = ' -P %s' % port
    else:
        port = ''
    if type == 'status':
        return ('/usr/bin/mysql --defaults-file=/root/.my.cnf '
                '%s%s -e "SHOW GLOBAL STATUS"') % (host, port)
    elif type == 'variables':
        return ('/usr/bin/mysql --defaults-file=/root/.my.cnf '
                '%s%s -e "SHOW VARIABLES"') % (host, port)


def parse_args():
    parser = optparse.OptionParser(usage='%prog [-h] [-H hostname] [-P port]')
    parser.add_option('-H', '--host', action='store', dest='host',
                      default=None,
                      help='Host to override the defaults with')
    parser.add_option('-P', '--port', action='store', dest='port',
                      default=None,
                      help='Port to override the defauults with')
    return parser.parse_args()


def print_metrics(replica_status):
    status_ok()
    metric('wsrep_replicated_bytes', 'int64',
           replica_status['wsrep_replicated_bytes'], 'bytes')
    metric('wsrep_received_bytes', 'int64',
           replica_status['wsrep_received_bytes'], 'bytes')
    metric('wsrep_commit_window_size', 'double',
           replica_status['wsrep_commit_window'], 'sequence_delta')
    metric('wsrep_cluster_size', 'int64',
           replica_status['wsrep_cluster_size'], 'nodes')
    metric('queries_per_second', 'int64',
           replica_status['Queries'], 'qps')
    metric('wsrep_cluster_state_uuid', 'string',
           replica_status['wsrep_cluster_state_uuid'])
    metric('wsrep_cluster_status', 'string',
           replica_status['wsrep_cluster_status'])
    metric('wsrep_local_state_uuid', 'string',
           replica_status['wsrep_local_state_uuid'])
    metric('wsrep_local_state_comment', 'string',
           replica_status['wsrep_local_state_comment'])
    metric('max_configured_connections', 'int64',
           replica_status['max_connections'], 'connections')
    metric('current_connections', 'int64',
           replica_status['Threads_connected'], 'connections')
    metric('max_seen_connections', 'int64',
           replica_status['Max_used_connections'], 'connections')
    metric('percentage_used_connections', 'int64',
           (int(int(replica_status['Threads_connected']) /
            int(replica_status['max_connections'])) * 100))


def main():
    options, _ = parse_args()

    replica_status = {}
    for i in ['status', 'variables']:
        retcode, output, err = galera_check(
            generate_query(options.host, options.port, type=i)
        )

        if retcode > 0:
            status_err(err)

        if not output:
            status_err('No output received from mysql. Cannot gather metrics.')

        show_list = output.split('\n')[1:-1]
        for i in show_list:
            replica_status[i.split('\t')[0]] = i.split('\t')[1]

    if replica_status['wsrep_cluster_status'] != "Primary":
        status_err("there is a partition in the cluster")

    if (replica_status['wsrep_local_state_uuid'] !=
            replica_status['wsrep_cluster_state_uuid']):
        status_err("the local node is out of sync")

    if (int(replica_status['wsrep_local_state']) == 4 and
            replica_status['wsrep_local_state_comment'] == "Synced"):
        print_metrics(replica_status)


if __name__ == '__main__':
    with print_output():
        main()
