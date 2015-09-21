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
import errno
import json
import os
from rackspace_monitoring.providers import get_driver
from rackspace_monitoring.types import Provider
import re


USERNAME = os.environ['OS_USERNAME']
API_KEY = os.environ['OS_PASSWORD']

Cls = get_driver(Provider.RACKSPACE)
CM = Cls(USERNAME, API_KEY)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('tasks', help='MaaS tasks file used to setup Maas.')
    parser.add_argument('label_templates', nargs='*', default=[],
                        help='entity_label:template_mapping')
    parser.add_argument('--raw_output', action='store_true')
    parser.add_argument('--from_file')
    parser.add_argument('--base_dir', default='.')
    args = parser.parse_args()
    if args.tasks.endswith('.yml'):
        args.tasks = args.tasks[:-4]
    return args


def get_entities(labels):
    uniq_labels = set(labels)
    all_entities = CM.list_entities()
    matched_entities = []
    matched_labels = set()
    for entity in all_entities:
        if entity.label in uniq_labels:
            matched_entities.append(entity)
            matched_labels.add(entity.label)
    unmatched_labels = uniq_labels - matched_labels
    if unmatched_labels:
        raise Exception('The label(s), "%s", do not match any entities.' %
                        ', '.join(unmatched_labels))
    return tuple(matched_entities)


def get_api_data(labels):
    """Return MaaS data - includeing entities, checks, metrics and alarms."""
    entities = get_entities(labels)
    data = []
    for entity in entities:
        d = {}
        e_json = CM.connection.request("/entities/%s" % (entity.id)).body
        d['entity'] = json.loads(e_json)
        d['checks'] = []
        checks = CM.list_checks(entity)
        alarms = CM.list_alarms(entity)
        for check in checks:
            c_json = CM.connection.request("/entities/%s/checks/%s" %
                                           (entity.id, check.id)).body
            c = json.loads(c_json)
            c['alarms'] = []
            for alarm in alarms:
                if alarm.check_id == check.id:
                    a_json = CM.connection.request("/entities/%s/alarms/%s" %
                                                   (entity.id, alarm.id)).body
                    a = json.loads(a_json)
                    c['alarms'].append(a)
            m_json = CM.connection.request("/entities/%s/checks/%s/metrics" %
                                           (entity.id, check.id)).body
            c['metrics'] = json.loads(m_json)['values']

            d['checks'].append(c)
        data.append(d)
    return data


def things_by(by_what, things):
    """Convert list of dictionaries to dictionary of dictionaries.

    Positional arguments:
    things -- a list of dictionaries
    by_what -- key that must exist in all dictionaries in things. The value of
    this key is used as the key in the returned dictionary and so should be
    unique.
    """
    things_by = {}
    for thing in things:
        things_by[thing[by_what]] = thing
    return things_by


def remove_keys(dictionary):
    to_remove = {'created_at', 'updated_at', 'latest_alarm_states',
                 'check_id', 'entity_id', 'id', 'agent_id', 'label',
                 'notification_plan_id', 'uri'}
    for key in dictionary.keys():
        if key in to_remove:
            del dictionary[key]

if __name__ == '__main__':
    args = parse_args()
    directory = args.base_dir
    try:
        os.makedirs(directory)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise e
    template_mappings = {}
    for lt in args.label_templates:
        try:
            label, template = lt.split(':', 1)
        except ValueError:
            label = lt
            template = label
        template_mappings[label] = template
    labels = template_mappings.keys()

    if args.from_file:
        with open(args.from_file) as f:
            raw_data = json.loads(f.read())
    else:
        raw_data = get_api_data(labels)

    if args.raw_output:
        raw_filename = '{tasks}.raw'.format(
            tasks=args.tasks)
        path = os.path.join(directory, raw_filename)
        with open(path, 'w') as f:
            f.write(json.dumps(raw_data, indent=4, separators=(',', ': '),
                               sort_keys=True))

    entities = {}
    for host in raw_data:
        hostname = host['entity']['label']
        for check in host['checks']:
            check['alarms'] = things_by('label', check['alarms'])
            check['metrics'] = things_by('name', check['metrics'])
        host['checks'] = things_by('label', host['checks'])
        host['entity']['checks'] = host['checks']
        template = template_mappings[hostname]
        host['entity']['original_label'] = host['entity']['label']
        entities[template] = host['entity']

    for entity in entities.viewvalues():
        remove_keys(entity)
        remove_keys(entity['checks'])
        for check in entity['checks'].viewvalues():
            remove_keys(check)
            remove_keys(check['alarms'])
            for alarm in check['alarms'].viewvalues():
                remove_keys(alarm)

    json_bits = ['{']
    for entity_label, entity in entities.viewitems():
        original_label = entity['original_label']
        del entity['original_label']

        json_bit = json.dumps(entity)

        json_bit = re.sub(original_label, entity_label, json_bit)

        if entity['ip_addresses']:
            ip_addrs = []
            IP_Entry = collections.namedtuple('IPEntry',
                                              ('name', 'number',
                                               'version', 'ip_address'))
            for label, ip_address in entity['ip_addresses'].viewitems():
                regex = ('(?P<name>[a-z_]+)'
                         '(?P<number>[0-9]+)_v(?P<version>[46])')
                match = re.match(regex, label).groups()
                entry = IP_Entry(*match, ip_address=ip_address)
                ip_addrs.append(entry)
            ip_addrs = sorted(
                sorted(ip_addrs, key=lambda x: x.version),
                key=lambda x: x.name)
            previous_name = None
            count = None
            for entry in ip_addrs:
                if previous_name == entry.name:
                    count += 1
                else:
                    count = 0
                json_bit = re.sub('%s%s_v%s' % (entry.name,
                                                entry.number,
                                                entry.version),
                                  '%s%s_v%s' % (entry.name,
                                                count,
                                                entry.version),
                                  json_bit)
                previous_name = entry.name
        json_bits.extend(('"', entity_label, '":', json_bit, ','))
    json_bits[-1] = '}'
    json_blob = ''.join(json_bits)

    json_blob = re.sub(r'container-[0-9a-f]{8}', 'container-UID', json_blob)
    json_blob = re.sub(r'[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}',
                       'IP_ADDRESS', json_blob)
    regex = (r'[0-9a-f]{1,4}:[0-9a-f]{1,4}:[0-9a-f]{1,4}:'
             '[0-9a-f]{1,4}:[0-9a-f]{1,4}:[0-9a-f]{1,4}:'
             '[0-9a-f]{1,4}:[0-9a-f]{1,4}')

    json_blob = re.sub(regex, 'IP_ADDRESS', json_blob)

    filename = args.tasks
    path = os.path.join(directory, filename)
    with open(path, 'w') as f:
        f.write(json.dumps(json.loads(json_blob), indent=4,
                           separators=(',', ': '), sort_keys=True))
