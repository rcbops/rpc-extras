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

# Example usages
# python swift-recon.py replication --ring-type account
# python swift-recon.py replication --ring-type container
# python swift-recon.py replication --ring-type object
# python swift-recon.py async-pendings
# python swift-recon.py md5
# python swift-recon.py quarantine

import argparse
import maas_common
import re
import subprocess


class ParseError(maas_common.MaaSException):
    pass


class CommandNotRecognized(maas_common.MaaSException):
    pass


def recon_output(for_ring, options=None):
    """Run swift-recon and filter out extraneous printed lines.

    ::

        >>> recon_output('account', '-r')
        ['[2014-11-21 00:25:16] Checking on replication',
         '[replication_failure] low: 0, high: 0, avg: 0.0, total: 0, Failed: 0.0%, no_result: 0, reported: 2',
         '[replication_success] low: 2, high: 4, avg: 3.0, total: 6, Failed: 0.0%, no_result: 0, reported: 2',
         '[replication_time] low: 0, high: 0, avg: 0.0, total: 0, Failed: 0.0%, no_result: 0, reported: 2',
         '[replication_attempted] low: 1, high: 2, avg: 1.5, total: 3, Failed: 0.0%, no_result: 0, reported: 2',
         'Oldest completion was 2014-11-21 00:24:51 (25 seconds ago) by 192.168.31.1:6002.',
         'Most recent completion was 2014-11-21 00:24:56 (20 seconds ago) by 192.168.31.2:6002.']

    :param str for_ring: Which ring to run swift-recon on
    :param list options: Command line options with which to run swift-recon
    :returns: Strings from output that are most important
    :rtype: list
    """
    command = ['swift-recon', for_ring]
    command.extend(options or [])
    out = subprocess.check_output(command)
    return filter(lambda s: s and not s.startswith(('==', '-')),
                  out.split('\n'))


def stat_regexp_generator(data):
    """Generate a regeular expression that will swift-recon stats.

    Lines printed by swift-recon look like::

        [data] low: 0, high: 0, avg: 0.0, total: 0, Failed: 0.0%, no_result: 0, reported: 0

    Where data above is the value of the ``data`` parameter passed to the
    function.
    """
    expression = """\s+low:\s+(?P<low>\d+),     # parse out the low result
                    \s+high:\s+(?P<high>\d+),   # parse out the high result
                    \s+avg:\s+(?P<avg>\d+.\d+), # you get the idea now
                    \s+total:\s+(?P<total>\d+),
                    \s+Failed:\s+(?P<failed>\d+.\d+%),
                    \s+no_result:\s+(?P<no_result>\d+),
                    \s+reported:\s+(?P<reported>\d+)"""
    return re.compile('\[' + data + '\]' + expression, re.VERBOSE)


def _parse_into_dict(line, parsed_by):
    match = parsed_by.match(line)
    if match:
        return match.groupdict()
    else:
        raise ParseError("Cannot parse '{0}' for statistics.".format(line))


def recon_stats_dicts(for_ring, options, starting_with, parsed_by):
    """Return a list of dictionaries of parsed statistics.

    Swift-recon has a standard format for it's statistics:

    [name] low: 0, high: 0, avg: 0.0, total: 0, Failed: 0.0%, no_result: 0, reported: 0

    Using the regular expression passed by the user in ``parsed_by``, we parse
    this out and return dictionaries of lines that start with
    ``starting_with``. This is after we get the recon output for the ring and
    options.

    :param str for_ring: Which ring to run swift-recon on
    :param list options: Command line options with which to run swift-recon
    :param str starting_with: String with which to filter lines
    :param parsed_by: Compiled regular expression to match and parse with
    :type parsed_by: _sre.SRE_Pattern (the result of calling re.compile)
    :returns: list of dictionaries of parse data
    """
    return map(lambda l: _parse_into_dict(l, parsed_by),
               filter(lambda s: s.startswith(starting_with),
                      recon_output(for_ring, options)))


def swift_replication(for_ring):
    """Parse swift-recon's replication statistics and return them.

    ::

        >>> swift_replication('account')
        {'attempted': {'avg': '1.5',
                       'failed': '0.0%',
                       'high': '2',
                       'low': '1',
                       'no_result': '0',
                       'reported": '5',
                       'total': '3'},
         'failure': {'avg': '0.0',
                     'failed': '0.0%',
                     'high': '0',
                     'low': '0',
                     'no_result': '0',
                     'reported": '5',
                     'total': '0'},
         'success': {'avg': '3.0',
                     'failed': '0.0%',
                     'high': '4',
                     'low': '2',
                     'no_result': '0',
                     'reported": '5',
                     'total': '6'},
         'time': {'avg': '0.0',
                  'failed': '0.0%',
                  'high': '0',
                  'low': '0',
                  'no_result': '0',
                  'reported": '5',
                  'total': '0'}}

    :param str for_ring: Which ring to run swift-recon on
    :returns: Dictionary of attempted, failed, success, and time statistics
    :rtype: dict
    """
    regexp = stat_regexp_generator(r'replication_(?P<replication_type>\w+)')
    replication_dicts = recon_stats_dicts(for_ring, ['-r'], '[replication_',
                                          regexp)

    # reduce could work here but would require an enclosed function which is
    # less readable than this loop
    replication_statistics = {}
    for rep_dict in replication_dicts:
        replication_statistics[rep_dict.pop('replication_type')] = rep_dict

    return replication_statistics


def swift_async():
    """Parse swift-recon's async pendings statistics and return them.

    ::

        >>> swift_async()
        {'avg': '0.0',
         'failed': '0.0%',
         'high': '0',
         'low': '0',
         'no_result': '0',
         'reported': '2',
         'total': '0'}

    :returns: Dictionary of average, failed, high, low, no_result, reported,
        and total statistics.
    """
    regexp = stat_regexp_generator('async_pending')
    async_dicts = recon_stats_dicts('object', ['-a'], '[async_pending]',
                                    regexp)
    stats = {}
    for async_dict in async_dicts:
        if async_dict:
            stats = async_dict
            # Break will skip the for-loop's else block
            break
    else:
        # If we didn't find a non-empty dict, error out
        maas_common.status_err(
            'No data could be collected about pending async operations'
            )
    return {'async': stats}


def swift_quarantine():
    """Parse swift-recon's quarantined objects and return them.

    ::

        >>> swift_quarantine()
        {'accounts': {'avg': '0.0',
                      'failed': '0.0%',
                      'high': '0',
                      'low': '0',
                      'no_result': '0',
                      'reported': '2',
                      'total': '0'},
         'containers': {'avg': '0.0',
                        'failed': '0.0%',
                        'high': '0',
                        'low': '0',
                        'no_result': '0',
                        'reported': '2',
                        'total': '0'},
         'objects': {'avg': '0.0',
                     'failed': '0.0%',
                     'high': '0',
                     'low': '0',
                     'no_result': '0',
                     'reported': '2',
                     'total': '0'}}

    :returns: Dictionary of objects, accounts, and containers.
    """
    regexp = stat_regexp_generator('quarantined_(?P<ring>\w+)')
    quarantined_dicts = recon_stats_dicts('-q', [], '[quarantined_',
                                          regexp)

    quarantined_statistics = {}
    for quar_dict in quarantined_dicts:
        quarantined_statistics[quar_dict.pop('ring')] = quar_dict

    return quarantined_statistics


def swift_md5():
    """Parse swift-recon's md5 check output and return it.

    ::

        >>> swift_md5()
        {'ring': {'errors': '0', 'success': '2', 'total': '2'},
         'swiftconf': {'errors': '0', 'success': '2', 'total': '2'}}

    :returns: Dictioanry
    """
    check_re = re.compile('Checking\s+(?P<check>[^\s]+)\s+md5sums?')
    error_re = re.compile('https?://(?P<address>[^:]+):\d+')
    result_re = re.compile(
        '(?P<success>\d+)/(?P<total>\d+)[^\d]+(?P<errors>\d+).*'
        )
    output = recon_output('--md5')  # We need to pass --md5 as a string here
    md5_statistics = {}
    checking_dict = {}
    for line in output:
        check_match = check_re.search(line)
        if check_match and not checking_dict:
            checking_dict = check_match.groupdict()
            # First line of a grouping we care about, might as well skip all
            # other checks in the loop
            continue
        # If there was an error checking the md5sum, error out immediately
        if line.startswith('!!'):
            error_dict = error_re.search(line).groupdict()
            maas_common.status_err('md5 mismatch for {0} on host {1}'.format(
                checking_dict.get('check'), error_dict['address']
                ))
        results_match = result_re.match(line)
        if results_match:
            check_name = checking_dict['check'].replace('.', '_')
            md5_statistics[check_name] = results_match.groupdict()
            checking_dict = {}

    return md5_statistics


def print_nested_stats(statistics):
    """Print out nested statistics.

    Nested statistics would be retrieved from ``swift_quarantine`` or
    ``swift_replication``.

    The following will show what you'll see

    ::

        >>> a = {'accounts': {'avg': '0.0',
                              'failed': '0.0%',
                              'high': '0',
                              'low': '0',
                              'no_result': '0',
                              'reported': '2',
                              'total': '0'}}
        >>> print_nested_stats(a)
        metric accounts_avg double 0.0
        metric accounts_failed double 0.0
        metric accounts_high uint64 0
        metric accounts_low uint64 0
        metric accounts_no_result uint64 0
        metric accounts_total uint64 0

    """
    for ring, stats in statistics.items():
        print_stats(ring, stats)


metrics_per_stat = {
    'avg': lambda name, val: maas_common.metric(name, 'double', val),
    'failed': lambda name, val: maas_common.metric(name, 'double', val[:-1])
    }

DEFAULT_METRIC = lambda name, val: maas_common.metric(name, 'uint64', val)


def print_stats(prefix, statistics):
    """Print out statistics.

    """
    for name, value in statistics.items():
        metric = metrics_per_stat.get(name, DEFAULT_METRIC)
        metric('{0}_{1}'.format(prefix, name), value)


def make_parser():
    parser = argparse.ArgumentParser(
        description='Process and print swift-recon statistics'
        )
    parser.add_argument('recon',
                        help='Which statistics to collect. Acceptable recon: '
                             '"async-pendings", "md5", "quarantine", '
                             '"replication"')
    parser.add_argument('--ring-type', dest='ring',
                        help='Which ring to run statistics for. Only used by '
                             'replication recon.')
    return parser


def get_stats_from(args):
    stats = {}
    if args.recon == 'async-pendings':
        stats = swift_async()
    elif args.recon == 'md5':
        stats = swift_md5()
    elif args.recon == 'quarantine':
        stats = swift_quarantine()
    elif args.recon == 'replication':
        if args.ring not in {"account", "container", "object"}:
            maas_common.status_err('no ring provided to check')
        stats = swift_replication(args.ring)
    else:
        raise CommandNotRecognized('unrecognized command "{0}"'.format(
            args.recon))
    return stats


def main():
    parser = make_parser()
    args = parser.parse_args()

    try:
        stats = get_stats_from(args)
    except (ParseError, CommandNotRecognized) as e:
        maas_common.status_err(str(e))

    if stats:
        maas_common.status_ok()
        print_nested_stats(stats)


if __name__ == '__main__':
    with maas_common.print_output():
        main()
