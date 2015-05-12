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

import re
import subprocess

import maas_common

# Example output::
# $ swift-dispersion-report --container-only
# > Queried 3 containers for dispersion reporting, 0s, 0 retries
# > 100.00% of container copies found (6 of 6)
# > Sample represents 1.17% of the container partition space
# $ swift-dispersion-report --object-only
# > Queried 2 objects for dispersion reporting, 0s, 0 retries
# > There were 2 partitions missing 0 copy.
# > 100.00% of object copies found (10 of 10)
# > Sample represents 0.78% of the object partition space

PARSE_RE = re.compile(
    # First line of both types of output
    "Queried (?P<num_objects>\d+) \w+ for dispersion reporting, "
    "(?P<seconds>\d+)s, (?P<retries>\d+) retries\s+"
    # Second line if working with object output only
    "(?:There were (?P<num_partitions>\d+) partitions? missing "
    "(?P<partition_copies>\d+) cop(y|ies)\.?\s+)?"
    # Second line for containers, third for objects
    "(?P<percent>\d+\.\d+)% of \w+ copies found \((?P<copies_found>\d+) of "
    "(?P<total_copies>\d+)\)\s+"
    # Last line for both types
    "Sample represents (?P<partition_percent>\d+.\d+)% of the \w+ "
    "partition space"
    )


def generate_report(on):
    """Report on either object or container dispersion.

    :param str on: Either "object" or "container"
    :returns: string of ouptut
    """
    if on not in {'object', 'container'}:
        return ''
    call = ['swift-dispersion-report', '--%s-only' % on]
    return subprocess.check_output(call)


def print_metrics(report_for, match):
    group = match.groupdict()
    for (k, v) in group.items():
        if v is None:
            # This happens for container output. The named "num_partitions"
            # and "partition_copies" groups end up in the dictionary with
            # value None so we need to ignore them when they are found.
            continue
        if k.endswith('percent'):
            metric_type = 'double'
        else:
            metric_type = 'uint64'

        # Add units when we can
        unit = 's' if k == 'seconds' else None
        maas_common.metric('{0}_{1}'.format(report_for, k), metric_type, v,
                           unit)


def main():
    # It's easier to parse the output if we make them independent reports
    # If we simply use swift-dispersion-report then we'll have both outputs
    # one after the other and we'll likely have a bad time.
    try:
        object_out = generate_report('object')
        object_match = PARSE_RE.search(object_out)
    except OSError:
        # If the subprocess call returns anything other than exit code 0.
        # we should probably error out too.
        maas_common.status_err('Could not access object dispersion report')

    try:
        container_out = generate_report('container')
        container_match = PARSE_RE.search(container_out)
    except OSError:
        # If the subprocess call returns anything other than exit code 0.
        # we should probably error out too.
        maas_common.status_err('Could not access container dispersion report')

    if not (object_match and container_match):
        maas_common.status_err('Could not parse dispersion report output')

    maas_common.status_ok()
    print_metrics('object', object_match)
    print_metrics('container', container_match)

# Example output::
# $ python swift-dispersion.py
# > status okay
# > metric object_retries uint64 0
# > metric object_seconds uint64 0 s
# > metric object_num_partitions uint64 2
# > metric object_num_objects uint64 2
# > metric object_percent double 100.00
# > metric object_copies_found uint64 10
# > metric object_partition_copies uint64 0
# > metric object_partition_percent double 0.78
# > metric object_total_copies uint64 10
# > metric container_retries uint64 0
# > metric container_seconds uint64 0 s
# > metric container_num_objects uint64 3
# > metric container_percent double 100.00
# > metric container_copies_found uint64 6
# > metric container_partition_percent double 1.17
# > metric container_total_copies uint64 6

if __name__ == '__main__':
    with maas_common.print_output():
        main()
