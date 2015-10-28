#!/usr/bin/env python
# Copyright 2015, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
from rackspace_monitoring.drivers import rackspace
from rackspace_monitoring.providers import get_driver
from rackspace_monitoring.types import Provider

import argparse
import ConfigParser
import re
import sys


def main(args):
    config = ConfigParser.RawConfigParser()
    config.read('/root/.raxrc')

    driver = get_driver(Provider.RACKSPACE)
    conn = _get_conn(config, driver)

    if conn is None:
        print("Unable to get a client to MaaS, exiting")
        sys.exit(1)

    if args.command == 'alarms':
        alarms(args, conn)
    elif args.command == 'check':
        check(args, conn)
    elif args.command == 'checks':
        checks(args, conn)
    elif args.command == 'delete':
        delete(args, conn)
    elif args.command == 'remove-defunct-checks':
        remove_defunct_checks(args, conn)
    elif args.command == 'remove-defunct-alarms':
        remove_defunct_alarms(args, conn)


def alarms(args, conn):
    for entity in _get_entities(args, conn):
        alarms = conn.list_alarms(entity)
        if alarms:
            _write(args, entity, alarms)


def checks(args, conn):
    for entity in _get_entities(args, conn):
        checks = conn.list_checks(entity)
        if checks:
            _write(args, entity, checks)


def check(args, conn):
    for entity in _get_entities(args, conn):
        error = 0
        for check in conn.list_checks(entity):
            try:
                result = conn.test_existing_check(check)
            except rackspace.RackspaceMonitoringValidationError as e:
                print('Entity %s (%s):' % (entity.id, entity.label))
                print(' - %s' % e)
                break

            available = result[0]['available']
            status = result[0]['status']

            if available is False or status not in ('okay', 'success'):
                if error == 0:
                    print('Entity %s (%s):' % (entity.id, entity.label))
                    error = 1
                if available is False:
                    print(' - Check %s (%s) did not run correctly' %
                          (check.id, check.label))
                elif status not in ('okay', 'success'):
                    print(" - Check %s (%s) ran correctly but returned a "
                          "'%s' status" % (check.id, check.label, status))


def delete(args, conn):
    count = 0

    if args.force is False:
        print("*** Proceeding WILL delete ALL your checks (and data) ****")
        if raw_input("Type 'from orbit' to continue: ") != 'from orbit':
            return

    for entity in _get_entities(args, conn):
        for check in conn.list_checks(entity):
            conn.delete_check(check)
            count += 1

    print("Number of checks deleted: %s" % count)


def remove_defunct_checks(args, conn):
    check_count = 0

    for entity in _get_entities(args, conn):
        for check in conn.list_checks(entity):
            if re.match('filesystem--.*', check.label):
                conn.delete_check(check)
                check_count += 1

    print("Number of checks deleted: %s" % check_count)


def remove_defunct_alarms(args, conn):
    alarm_count = 0
    defunct_alarms = {'rabbit_mq_container': ['disk_free_alarm', 'mem_alarm'],
                      'galera_container': ['WSREP_CLUSTER_SIZE',
                                           'WSREP_LOCAL_STATE_COMMENT']}

    for entity in _get_entities(args, conn):
        for alarm in conn.list_alarms(entity):
            for container in defunct_alarms:
                for defunct_alarm in defunct_alarms[container]:
                    if re.match('%s--.*%s' % (defunct_alarm, container),
                                alarm.label):
                        conn.delete_alarm(alarm)
                        alarm_count += 1

    print("Number of alarms deleted: %s" % alarm_count)


def _get_conn(config, driver):
    conn = None

    if config.has_section('credentials'):
        try:
            user = config.get('credentials', 'username')
            api_key = config.get('credentials', 'api_key')
        except Exception as e:
            print(e)
        else:
            conn = driver(user, api_key)
    if not conn and config.has_section('api'):
        try:
            url = config.get('api', 'url')
            token = config.get('api', 'token')
        except Exception as e:
            print(e)
        else:
            conn = driver(None, None, ex_force_base_url=url,
                          ex_force_auth_token=token)

    return conn


def _get_entities(args, conn):
    entities = []

    for entity in conn.list_entities():
        if args.prefix is None or args.prefix in entity.label:
            entities.append(entity)

    return entities


def _write(args, entity, objects):
    if args.tab:
        for o in objects:
            print("\t".join([entity.id, entity.label, o.label, o.id]))
    else:
        print('Entity %s (%s):' % (entity.id, entity.label))
        for o in objects:
            print(' - %s' % o.label)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Test MaaS checks')
    parser.add_argument('command',
                        type=str,
                        choices=['alarms', 'check', 'checks', 'delete',
                                 'remove-defunct-checks',
                                 'remove-defunct-alarms'],
                        help='Command to execute')
    parser.add_argument('--force',
                        action="store_true",
                        help='Do stuff irrespective of consequence'),
    parser.add_argument('--prefix',
                        type=str,
                        help='Limit testing to checks on entities labelled w/ '
                             'this prefix',
                        default=None)
    parser.add_argument('--tab',
                        type=bool,
                        help='Output in tab-separated format, applies only to '
                             'alarms and checks commands',
                        default=False)
    args = parser.parse_args()

    main(args)
