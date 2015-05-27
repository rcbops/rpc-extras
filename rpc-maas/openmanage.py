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
import sys
import subprocess

from maas_common import status_err, status_ok, metric_bool, print_output

SUPPORTED_VERSIONS = set([ "7.1.0", "7.4.0" ])
OM_PATTERN = '(?:%(field)s)\s+:\s+(%(group_pattern)s)'
CHASSIS = re.compile(OM_PATTERN % {'field': '^Health', 'group_pattern': '\w+'}, re.MULTILINE)
STORAGE = re.compile(OM_PATTERN % {'field': '^Status', 'group_pattern': '\w+'}, re.MULTILINE)
regex = {'storage': STORAGE, 'chassis': CHASSIS}


def hardware_report(report_type, report_request):
    """Return the report as a string."""
    return subprocess.check_output(['/opt/dell/srvadmin/bin/omreport', report_type, report_request])


def all_okay(report, regex_find):
    """Determine if the installed health and status fields are okay.

    :returns: True if all "Ok", False otherwise
    :rtype: bool
    """
    fields = regex_find.findall(report)
    if not fields:
        status_err('There were no Health or Status fields to check.')
    return all(v.lower() == 'ok' for v in fields)


def check_openmanage_version():
    """Error early if the version of OpenManage is not supported."""
    try:
        # Because of
        # https://github.com/rcbops/rcbops-maas/issues/82#issuecomment-52315709
        # we need to redirect sdterr to stdout just so MaaS does not see any
        # extra output
        output = subprocess.check_output(['/opt/dell/srvadmin/bin/omconfig', 'about'],
                                         stderr=subprocess.STDOUT)
    except OSError:
        # OSError happens when subprocess cannot find the executable to run
        status_err('The OpenManage tools do not appear to be installed.')
    except subprocess.CalledProcessError as e:
        status_err(str(e))

    match = re.search(OM_PATTERN % {'field': 'Version',
                                    'group_pattern': '[0-9.]+'},
                      output)
    if not match:
        status_err('Could not find the version information')

    version = match.groups()[0]
    if version not in SUPPORTED_VERSIONS:
        status_err(
            'Expected version in %s to be installed but found %s'
            % (SUPPORTED_VERSIONS, version)
        )


def main():
    if len(sys.argv[1:]) != 2:
        args = ' '.join(sys.argv[1:])
        status_err(
            'Requires 2 arguments, arguments provided: "%s"' % args
        )

    report_type = sys.argv[1].lower()
    report_request = sys.argv[2].lower()

    # If we're not using the correct version of OpenManage, error out
    check_openmanage_version()

    try:
        report = hardware_report(report_type, report_request)
    except (OSError, subprocess.CalledProcessError) as e:
        status_err(str(e))

    status_ok()
    metric_bool('hardware_%s_status' % report_request,
                all_okay(report, regex[report_type]))


if __name__ == '__main__':
    with print_output():
        main()
