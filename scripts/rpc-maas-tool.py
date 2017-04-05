#!/usr/bin/env python
# Copyright 2015, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

from __future__ import print_function

import argparse
import ConfigParser
import datetime
import logging
import os
from Queue import Queue
import re
import sys
import yaml

import concurrent.futures

from rackspace_monitoring.drivers import rackspace
from rackspace_monitoring.providers import get_driver
from rackspace_monitoring.types import Provider

DEFAULT_CONFIG_FILE = '/root/.raxrc'
logging.basicConfig(level=logging.DEBUG,
                    datefmt="",
                    format="%(message)s",
                    stream=sys.stdout)
LOGGER = logging.getLogger(__name__)


class RpcMaas(object):
    """Class representing a connection to the MAAS Service"""

    def __init__(self, entity_match='', entities=None,
                 config_file=DEFAULT_CONFIG_FILE):
        self.entity_label_whitelist = entities
        self.entity_match = entity_match
        self.config_file = config_file
        self.driver = get_driver(Provider.RACKSPACE)
        self._get_conn()
        self._get_overview()
        self._add_links()
        self._filter_entities()
        self.q = Queue()

    def _filter_entities(self):
        if not self.entity_label_whitelist:
            self.entities = [e['entity'] for e in self.overview
                             if self.entity_match in e['entity'].label]
        else:
            self.entities = []
            for entry in self.overview:
                entity = entry['entity']
                for label in self.entity_label_whitelist:
                    if entity.label == label:
                        self.entities.append(entity)
        if not self.entities:
            raise Exception("No Entities found matching --entity or "
                            "--entitymatch")

    def _get_conn(self):
        """Read config file and use extracted creds to connect to MAAS"""
        self.config = ConfigParser.RawConfigParser()
        self.config.read(self.config_file)
        self.conn = None

        try:
            user = self.config.get('credentials', 'username')
            api_key = self.config.get('credentials', 'api_key')
            self.conn = self.driver(user, api_key)
        except (ConfigParser.NoSectionError, ConfigParser.NoOptionError):
            url = self.config.get('api', 'url')
            token = self.config.get('api', 'token')
            self.conn = self.driver(None, None, ex_force_base_url=url,
                                    ex_force_auth_token=token)

    def _get_overview(self):
        self.overview = self.conn.ex_views_overview()

    def _add_links(self):
        """Add missing parent/child links to objects"""

        # Entity --> Check
        for entry in self.overview:
            entity = entry['entity']
            entity.checks = entry['checks']
            entity.alarms = []
            entity.metrics = []

            # Check --> Entity
            for check in entity.checks:
                check.entity = entity
                check.metrics = []

                # Check <--> Alarm
                check.alarms = []

                for alarm in self.get_alarms(check=check, entry=entry):
                    alarm.check = check
                    alarm.entity = entity
                    check.alarms.append(alarm)
                    entity.alarms.append(alarm)

    def _add_metrics_list_to_check(self, check):
        """Called via ThreadPoolExecutor, result returned via queue."""
        metrics = self.conn.list_metrics(check.entity.id, check.id)
        self.q.put((check, metrics))

    def add_metrics(self):
        """Add metrics list to each checks

        Requires a call per check, so ThreadPoolExecutor is used to
        parallelise and reduce time taken
        """
        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
            for entity in self.get_entities():
                for check in entity.checks:
                    executor.submit(self._add_metrics_list_to_check, check)
        while not self.q.empty():
            check, metrics = self.q.get()
            for metric in metrics:
                metric.check = check
                metric.entity = check.entity
                check.metrics.append(metric)
                check.entity.metrics.append(metric)

    def get_entities(self):
        """Return list of known entities

        entity_match filter not required as this is done in __init__
        """
        return self.entities

    def get_checks(self, check_match=''):
        """List checks for entities matching a string"""

        checks = []
        for entity in self.entities:
            checks.extend([c for c in entity.checks
                           if check_match in c.label])
        return checks

    def get_alarms(self, entry, check):
        """Get list of alarms

        Params:
            entry: overview dictionary for one entity.

        This function adds a state field to each alarm object
        using information from the 'latest_alarm_states' entry key.
        """
        alarms = []
        for alarm in entry['alarms']:
            if not alarm.check_id == check.id:
                continue
            # add state to the alarm object from latest_alarm_states
            alarm_states = sorted(
                (als for als in entry['latest_alarm_states']
                    if als.alarm_id == alarm.id),
                key=lambda x: x.timestamp
            )
            if alarm_states:
                alarm.state = alarm_states[-1].state
            else:
                alarm.state = "UNKNOWN"
            alarms.append(alarm)
        return alarms


class RpcMaasAgentConfig(object):
    """Read MAAS Agent configuration files

    Parse them as yaml and store that.
    """
    def __init__(self, agentconfdpath):
        self.agentconfdpath = agentconfdpath
        self.checks = self._parse_maas_configs()

    def _parse_maas_configs(self):
        """Read all config files in agentconfdpath"""
        self.checks = {}
        for path in os.listdir(self.agentconfdpath):
            check = self._parse_config_file(os.path.join(self.agentconfdpath,
                                                         path))
            self.checks[check['label']] = check
        return self.checks

    def _parse_config_file(self, path):
        """Parse one yaml config file"""
        with open(path, 'r') as config_file:
            blob = yaml.load(config_file)
        return blob


class RpcMassCli(object):
    """CLI interface for RPC Maas"""
    def __init__(self):
        self.parse_args()
        LOGGER.addHandler(logging.FileHandler(self.args.logfile))
        self.rpcm = RpcMaas(self.args.entitymatch,
                            self.args.entity,
                            self.args.raxrcpath)
        self.rpcmac = RpcMaasAgentConfig(self.args.agentconfdir)

    def parse_args(self):
        parser = argparse.ArgumentParser(description='Test MaaS checks')
        parser.add_argument('command',
                            type=str,
                            choices=['list-alarms', 'run-checks',
                                     'list-checks', 'delete',
                                     'compare-checks',
                                     'compare-alarms',
                                     'checks-without-alarms',
                                     'overview',
                                     'verify-created',
                                     'verify-status',
                                     'remove-defunct-checks',
                                     'remove-defunct-alarms'],
                            help='Command to execute')
        parser.add_argument('--force',
                            action="store_true",
                            help='Do stuff irrespective of consequence'),
        parser.add_argument('--entitymatch',
                            type=str,
                            help='Limit testing to checks on entities '
                                 ' whose label contains this string.',
                            default='')
        parser.add_argument('--entity',
                            type=str,
                            help='Limit testing to entities whose labels'
                                 ' exactly match this string. Can be specified'
                                 ' multiple times',
                            action='append',
                            default=[])
        parser.add_argument('--checkmatch',
                            type=str,
                            help='Limit testing to checks '
                                 ' whose label contains this string',
                            default='')
        parser.add_argument('--tab',
                            action="store_true",
                            help='Output in tab-separated format, applies '
                                 'only to alarms and checks commands')
        parser.add_argument('--raxrcpath',
                            type=str,
                            help='path to config file to read',
                            default=DEFAULT_CONFIG_FILE)
        parser.add_argument('--agentconfdir',
                            type=str,
                            help='path to config file to read',
                            default='/etc/rackspace-monitoring-agent.conf.d')
        parser.add_argument('--logfile',
                            type=str,
                            help='path to log file to write',
                            default='/var/log/rpc_maas_tool.log')
        parser.add_argument('--verbose',
                            action="store_true",
                            help='Show items without failures when listing'
                                 'alarms or running checks')
        parser.add_argument('--excludedcheck',
                            action="append",
                            help='A check that should not be present'
                                 'can be specified multiple times',
                            default=[])
        self.args = parser.parse_args()

    def main(self):
        if self.rpcm.conn is None:
            LOGGER.error("Unable to get a client to MaaS, exiting")
            sys.exit(1)

        dd = {'list-alarms': self.alarms,
              'run-checks': self.run_checks,
              'list-checks': self.checks,
              'compare-checks': self.compare_checks,
              'checks-without-alarms': self.checks_without_alarms,
              'compare-alarms': self.compare_alarms,
              'overview': self.overview,
              'verify-created': self.verify_created,
              'verify-status': self.verify_status,
              'delete': self.delete,
              'remove-defunct-checks': self.remove_defunct_checks,
              'remove-defunct-alarms': self.remove_defunct_alarms}
        result = dd[self.args.command]()
        if result is None:
            return 0
        else:
            return result

    def checks_without_alarms(self):
        """list checks with no alarms"""
        no_alarms = [c for c in self.rpcm.get_checks(self.args.checkmatch)
                     if not c.alarms and c.type != 'remote.ping']
        if no_alarms:
            LOGGER.info("The following checks have 0 alarms "
                        "registered with the maas api:")
            self._write(no_alarms)
            return 1

    def excluded_checks(self):
        """List checks that are present but shouldn't be"""
        present_but_excluded_checks = []
        checks = self.rpcm.get_checks(self.args.entitymatch)
        for check in checks:
            for exclude in self.args.excludedcheck:
                # ping is a default check and may not have an alarm
                if exclude in check.label:
                    present_but_excluded_checks.append(check)
        if present_but_excluded_checks:
            LOGGER.info("The following checks are in the excluded_checks list"
                        " but are still present in the API:")
            self._write(present_but_excluded_checks)
            return 1

    def compare_checks(self):
        """Compare checks

        Check that all checks found in config files are registered with The
        maas api.
        """

        api_checks = self.rpcm.get_checks(self.args.checkmatch)
        missing_checks = [configcheck for configcheck in
                          self.rpcmac.checks.keys()
                          if configcheck not in
                          [apicheck.label for apicheck in api_checks]]
        if missing_checks:
            LOGGER.info("The following checks have config files but are not "
                        "registered with the maas api: %(missing_checks)s "
                        % {'missing_checks': missing_checks})
            return 1

    def _compare_alarm(self, config_alarm, api_alarm):
        """Compare one config alarm with one api alarm"""
        return (config_alarm['label'] == api_alarm.label
                and config_alarm['criteria'] == api_alarm.criteria)

    def compare_alarms(self):
        """Compare alarms.

        Check that all alarms found in MAAS agent config files are also
        listed by the maas api.
        """
        api_alarms = []
        for entity in self.rpcm.get_entities():
            api_alarms.extend(entity.alarms)

        config_alarms = {}
        for check in self.rpcmac.checks.values():
            config_alarms.update(check['alarms'])

        missing_alarms = []
        for config_alarm in config_alarms.values():
            if not any([self._compare_alarm(config_alarm, api_alarm)
                        for api_alarm in api_alarms]):
                missing_alarms.append(config_alarm)

        if missing_alarms:
            LOGGER.info("The following alarms are present in config files but "
                        "are not registered with the maas api: "
                        "%(missing_alarms)s "
                        % {'missing_alarms':
                            [a['label'] for a in missing_alarms]})
            return 1

    def verify_created(self):
        """Verify that all checks and alarms have been created"""
        LOGGER.info("--- %(datestamp)s ---"
                    % {'datestamp': datetime.datetime.now()})
        result = 0
        for step in [self.compare_checks,
                     self.compare_alarms,
                     self.checks_without_alarms,
                     self.excluded_checks]:

            step_result = step()
            if step_result is not None:
                result += step_result

        if result > 0:
            return 1
        else:
            LOGGER.info("All expected checks and alarms are present")

    def verify_status(self):
        """Verify MAAS configuration and status"""
        LOGGER.info("--- %(datestamp)s ---"
                    % {'datestamp': datetime.datetime.now()})

        alarms, failed_alarms = self._get_failed_alarms()
        if self.args.verbose:
            checks, failed_checks = self._get_failed_checks()
        else:
            # run checks that have at least one failed alarm
            # in most situations this much quicker than executing all checks
            checks_with_failed_alarms = set(a.check for a in failed_alarms)
            checks, failed_checks = self._get_failed_checks(
                checks_with_failed_alarms)

        failures = failed_checks + failed_alarms

        if self.args.verbose:
            LOGGER.info("Registered Checks and Alarms:")
            self._write(checks + alarms)
        elif failures:
            LOGGER.info("Checks and Alarms with failures:")
            self._write(failures)
            return 1
        else:
            LOGGER.info("MAAS Verify completed succesfully")

    def _get_failed_alarms(self):
        alarms = []
        failed_alarms = []
        for entity in self.rpcm.get_entities():
            for alarm in entity.alarms:
                alarms.append(alarm)
                if alarm.state not in ["OK", "UNKNOWN"]:
                    failed_alarms.append(alarm)
                    alarm.bullet = "!"
        return (alarms, failed_alarms)

    def alarms(self):
        """List Alarms"""
        alarms, failed_alarms = self._get_failed_alarms()

        if self.args.verbose:
            self._write(alarms)
        else:
            self._write(failed_alarms)

        if len(failed_alarms) > 0:
            return 1

    def checks(self):
        """List Checks"""
        self._write(self.rpcm.get_checks(self.args.checkmatch))

    def _get_failed_checks(self, checks=None):
        failed_checks = []
        if checks is None:
            checks = []
            for entity in self.rpcm.get_entities():
                for check in entity.checks:
                    if self.args.checkmatch not in check.label:
                        continue
                    checks.append(check)
        for check in checks:
            try:
                result = self.rpcm.conn.test_existing_check(check)
            except rackspace.RackspaceMonitoringValidationError as e:
                completed = False
            else:
                status = result[0]['status']
                completed = result[0]['available']
                check.state = (" Completed:%(completed)s Status:%(status)s"
                               % {'completed': completed, 'status': status})

            if not completed:
                check.bullet = "!"
                failed_checks.append(check)

        return (checks, failed_checks)

    def run_checks(self):
        """Execute Checks and list results"""
        checks, failed_checks = self._get_failed_checks()
        if self.args.verbose:
            self._write(checks)
        else:
            self._write(failed_checks)

        if len(failed_checks) > 0:
            return 1

    def overview(self):
        """List checks alarms and metrics"""
        entities = self.rpcm.get_entities()
        checks = []
        alarms = []
        metrics = []
        self.rpcm.add_metrics()

        for entity in entities:
            checks.extend(entity.checks)
            alarms.extend(entity.alarms)
            for check in entity.checks:
                metrics.extend(check.metrics)
        self._write(checks + alarms + metrics)

    def delete(self):
        count = 0

        if self.args.force is False:
            print("*** Proceeding WILL delete ALL your checks (and data) ****")
            sys.stdout.flush()
            if raw_input("Type 'from orbit' to continue: ") != 'from orbit':
                return

        for entity in self.rpcm.get_entities():
            for check in entity.checks:
                self.rpcm.conn.delete_check(check)
                count += 1

        LOGGER.info("Number of checks deleted: %s" % count)

    def remove_defunct_checks(self):
        check_count = 0

        for entity in self.rpcm.get_entities():
            for check in entity.checks:
                if re.match('filesystem--.*', check.label):
                    self.rpcm.conn.delete_check(check)
                    check_count += 1

        LOGGER.info("Number of checks deleted: %s" % check_count)

    def remove_defunct_alarms(self):
        alarm_count = 0
        defunct_alarms = {'rabbit_mq_container': ['disk_free_alarm',
                                                  'mem_alarm'],
                          'galera_container': ['WSREP_CLUSTER_SIZE',
                                               'WSREP_LOCAL_STATE_COMMENT']}

        for entity in self.rpcm.get_entities():
            for alarm in entity.alarms:
                for container in defunct_alarms:
                    for defunct_alarm in defunct_alarms[container]:
                        if re.match(
                                '%s--.*%s' % (defunct_alarm, container),
                                alarm.label):
                            self.rpcm.conn.delete_alarm(alarm)
                            alarm_count += 1

        LOGGER.info("Number of alarms deleted: %s" % alarm_count)

    def _os(self, obj, indent=0, ps=''):
        """ObjectString

        Create a string from an objects
        """
        bullet = " %s " % getattr(obj, 'bullet', "-")
        objclass = obj.__class__.__name__
        nameattr = 'label'
        checktype = ""
        if hasattr(obj, 'name'):
            nameattr = 'name'
        if hasattr(obj, 'type'):
            checktype = ":%(type)s" % {'type': obj.type}
        if hasattr(obj, 'state'):
            ps += ":%(state)s" % {'state': obj.state}
        if not hasattr(obj, 'id'):
            obj.id = ""
        if self.args.tab:
            bullet = ""
        return ("%(indent)s%(bullet)s%(objclass)s%(checktype)s"
                ":%(id)s:%(label)s%(ps)s"
                % {'id': obj.id,
                    'bullet': bullet,
                    'indent': ' ' * indent * 2,
                    'objclass': objclass,
                    'label': getattr(obj, nameattr),
                    'checktype': checktype,
                    'ps': ps})

    def _write(self,
               objs,
               sep="\t"):

        if self.args.tab:
            # Tab seperated output
            def _line_segment(obj, line=""):
                # entity
                if hasattr(obj, 'checks'):
                    return self._os(obj) + sep + line
                # check
                elif hasattr(obj, 'alarms'):
                    return (_line_segment(obj.entity, self._os(obj))
                            + sep + line)
                # alarm or metric
                else:
                    return (_line_segment(obj.check, self._os(obj))
                            + sep + line)
            for obj in objs:
                LOGGER.info(_line_segment(obj))
        else:
            # Tree style output
            entities = set()
            checks = set()
            for obj in objs:
                entities.add(getattr(obj, 'entity', obj))
                checks.add(getattr(obj, 'check', obj))

            for entity in entities:
                LOGGER.info(self._os(entity))
                for check in [c for c in checks if c.entity == entity]:
                    LOGGER.info(self._os(check, indent=1))
                    for obj in objs:
                        if (getattr(obj, 'check', None) == check
                                and getattr(obj, 'entity', None) == entity):
                            LOGGER.info(self._os(obj, indent=2))

if __name__ == "__main__":
    cli = RpcMassCli()
    sys.exit(cli.main())
