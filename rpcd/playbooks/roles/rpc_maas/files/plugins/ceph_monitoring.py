#!/usr/bin/env python

# Copyright 2015, Rackspace US, Inc.
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
import json
import maas_common
import subprocess


STATUSES = {'HEALTH_OK': 2, 'HEALTH_WARN': 1, 'HEALTH_ERR': 0}


def check_command(command):
    output = subprocess.check_output(command, stderr=subprocess.STDOUT)
    lines = output.strip().split('\n')
    return json.loads(lines[-1])


def get_ceph_report(client, keyring, fmt='json'):
    return check_command(('ceph', '--format', fmt, '--name', client,
                          '--keyring', keyring, 'report'))


def get_mon_statistics(report=None, host=None):
    mon = [m for m in report['monmap']['mons']
           if m['name'] == host]
    mon_in = mon[0]['rank'] in report['quorum']
    maas_common.metric_bool('mon_in_quorum', mon_in)
    health_status = 0
    for each in report['health']['health']['health_services'][0]['mons']:
        if each['name'] == host:
            health_status = STATUSES[each['health']]
            break
    maas_common.metric('mon_health', 'uint32', health_status)


def get_osd_statistics(report=None, osd_ids=None):
    for osd_id in osd_ids:
        osd_ref = 'osd.%s' % osd_id
        for _osd in report['osdmap']['osds']:
            if _osd['osd'] == osd_id:
                osd = _osd
                break
        else:
            msg = 'The OSD ID %s does not exist.' % osd_id
            raise maas_common.MaaSException(msg)

        key = 'up'
        name = '_'.join((osd_ref, key))
        maas_common.metric_bool(name, osd[key])

        for _osd in report['pgmap']['osd_stats']:
            if _osd['osd'] == osd_id:
                osd = _osd
                break


def get_cluster_statistics(report=None):
    metrics = []

    # Get overall cluster health
    metrics.append({'name': 'cluster_health',
                    'type': 'uint32',
                    'value': STATUSES[report['health']['overall_status']]})

    # Collect epochs for the mon and osd maps
    for map_name in ('monmap', 'osdmap'):
        metrics.append({'name': "%(map)s_epoch" % {'map': map_name},
                        'type': 'uint32',
                        'value': report[map_name]['epoch']})

    # Collect OSDs per state
    osds = {'total': 0, 'up': 0, 'in': 0}
    for osd in report['osdmap']['osds']:
        osds['total'] += 1
        if osd['up'] == 1:
            osds['up'] += 1
        if osd['in'] == 1:
            osds['in'] += 1
    for k in osds:
        metrics.append({'name': 'osds_%s' % k,
                        'type': 'uint32',
                        'value': osds[k]})

    # Collect cluster size & utilisation
    osds_stats = ('kb', 'kb_avail', 'kb_used')
    for k in report['pgmap']['osd_stats_sum']:
        if k in osds_stats:
            metrics.append({'name': 'osds_%s' % k,
                            'type': 'uint64',
                            'value': report['pgmap']['osd_stats_sum'][k]})

    # Collect num PGs and num healthy PGs
    pgs = {'total': 0, 'active_clean': 0}
    for pg in report['pgmap']['pg_stats']:
        pgs['total'] += 1
        if pg['state'] == 'active+clean':
            pgs['active_clean'] += 1
    for k in pgs:
        metrics.append({'name': 'pgs_%s' % k,
                        'type': 'uint32',
                        'value': pgs[k]})

    # Submit gathered metrics
    for m in metrics:
        maas_common.metric(m['name'], m['type'], m['value'])


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--name', required=True, help='Ceph client name')
    parser.add_argument('--keyring', required=True, help='Ceph client keyring')

    subparsers = parser.add_subparsers(dest='subparser_name')

    parser_mon = subparsers.add_parser('mon')
    parser_mon.add_argument('--host', required=True, help='Mon hostname')

    parser_osd = subparsers.add_parser('osd')
    parser_osd.add_argument('--osd_ids', required=True,
                            help='Space separated list of OSD IDs')

    subparsers.add_parser('cluster')
    return parser.parse_args()


def main(args):
    get_statistics = {'cluster': get_cluster_statistics,
                      'mon': get_mon_statistics,
                      'osd': get_osd_statistics}
    report = get_ceph_report(client=args.name, keyring=args.keyring)
    kwargs = {'report': report}
    if args.subparser_name == 'osd':
        kwargs['osd_ids'] = [int(i) for i in args.osd_ids.split(' ')]
    if args.subparser_name == 'mon':
        kwargs['host'] = args.host
    get_statistics[args.subparser_name](**kwargs)
    maas_common.status_ok()


if __name__ == '__main__':
    with maas_common.print_output():
        args = get_args()
        main(args)
