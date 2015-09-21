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
import collections
import json
import re
import tabulate


def print_tables(data, data_type=None):
    for host, lines in data.viewitems():
        if lines:
            title = '{dt} - {host}'.format(dt=data_type, host=host)
            print(title)
            print('-' * len(title))
            print(tabulate.tabulate(lines, headers='keys', tablefmt='rst'))
            print('\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('filenames', nargs='+')
    args = parser.parse_args()

    AlarmDocLine = collections.namedtuple(
        'AlarmDocLine', ('Check', 'Alarm', 'Condition', 'Status'))

    MetricDocLine = collections.namedtuple(
        'MetricDocLine', ('Check', 'Metric_Name', 'Metric_Unit'))

    regex = (r'if\s+\((?P<condition>.+?)\s*\)\s*\{\s*return\s+new\s+'
             'AlarmStatus\((?P<status>[A-Z]+)')

    criteria_pattern = re.compile(regex)
    metrics_by_entity = collections.defaultdict(set)
    alarms_by_entity = collections.defaultdict(set)

    for filename in args.filenames:
        with open(filename) as f:
            data = f.read()

        entities = json.loads(data)

        for entity_label, entity in entities.viewitems():
            metrics = set()
            alarms = set()
            for check_name, check in entity['checks'].viewitems():
                check_name_stem = check_name.split('--')[0]
                for metric in check['metrics'].viewvalues():
                    line = MetricDocLine(Check=check_name_stem,
                                         Metric_Name=metric['name'],
                                         Metric_Unit=metric['unit'])
                    metrics.add(line)
                metrics_by_entity[entity_label].update(metrics)

                for alarm_name, alarm in check['alarms'].viewitems():
                    for match in criteria_pattern.finditer(alarm['criteria']):
                        condition = match.group('condition')
                        status = match.group('status')
                        line = AlarmDocLine(Check=check_name_stem,
                                            Alarm=alarm_name.split('--')[0],
                                            Condition=condition,
                                            Status=status)
                        alarms.add(line)
                alarms_by_entity[entity_label].update(alarms)

    for entity, metrics in metrics_by_entity.viewitems():
        sorted_metrics = sorted(metrics, key=lambda m: m.Metric_Name)
        sorted_metrics.sort(key=lambda m: m.Check)
        metrics_by_entity[entity] = sorted_metrics
    print_tables(metrics_by_entity, data_type='Metrics')

    for entity, alarms in alarms_by_entity.viewitems():
        sorted_alarms = sorted(alarms, key=lambda a: a.Status, reverse=True)
        sorted_alarms.sort(key=lambda a: a.Alarm)
        sorted_alarms.sort(key=lambda a: a.Check)
        alarms_by_entity[entity] = sorted_alarms
    print_tables(alarms_by_entity, data_type='Alarms')
