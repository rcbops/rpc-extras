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

import argparse
from ipaddr import IPv4Address
import requests
import re
from maas_common import (get_auth_details, metric, metric_bool, status_err,
                         status_ok, print_output)
from requests import exceptions as exc
from lxml import html


def check(args):
    # disable warning for insecure cert on horizon
    requests.packages.urllib3.disable_warnings()

    splash_status_code = 0
    splash_milliseconds = 0.0
    login_status_code = 0
    login_milliseconds = 0.0

    is_up = True

    auth_details = get_auth_details()
    OS_USERNAME = auth_details['OS_USERNAME']
    OS_PASSWORD = auth_details['OS_PASSWORD']
    HORIZON_URL = 'https://{ip}'.format(ip=args.ip)
    HORIZON_PORT = '443'

    s = requests.Session()

    try:
        r = s.get('%s:%s' % (HORIZON_URL, HORIZON_PORT),
                  verify=False,
                  timeout=10)
    except (exc.ConnectionError,
            exc.HTTPError,
            exc.Timeout) as e:
        is_up = False
    else:
        if not (r.ok and
                re.search('openstack dashboard', r.content, re.IGNORECASE)):
            status_err('could not load login page')

        splash_status_code = r.status_code
        splash_milliseconds = r.elapsed.total_seconds() * 1000

        csrf_token = html.fromstring(r.content).xpath(
            '//input[@name="csrfmiddlewaretoken"]/@value')[0]
        region = html.fromstring(r.content).xpath(
            '//input[@name="region"]/@value')[0]
        s.headers.update(
            {'Content-type': 'application/x-www-form-urlencoded',
                'Referer': HORIZON_URL})
        payload = {'username': OS_USERNAME,
                   'password': OS_PASSWORD,
                   'csrfmiddlewaretoken': csrf_token,
                   'region': region}
        try:
            l = s.post(
                ('%s:%s/auth/login/') % (HORIZON_URL, HORIZON_PORT),
                data=payload,
                verify=False)
        except (exc.ConnectionError,
                exc.HTTPError,
                exc.Timeout) as e:
            status_err('While logging in: %s' % e)

        if not (l.ok and re.search('overview', l.content, re.IGNORECASE)):
            status_err('could not log in')

        login_status_code = l.status_code
        login_milliseconds = l.elapsed.total_seconds() * 1000

    status_ok()
    metric_bool('horizon_local_status', is_up)

    if is_up:
        metric('splash_status_code', 'uint32', splash_status_code, 'http_code')
        metric('splash_milliseconds', 'double', splash_milliseconds, 'ms')
        metric('login_status_code', 'uint32', login_status_code, 'http_code')
        metric('login_milliseconds', 'double', login_milliseconds, 'ms')


def main(args):
    check(args)

if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description='Check horizon dashboard')
        parser.add_argument('ip',
                            type=IPv4Address,
                            help='horizon dashboard IP address')
        args = parser.parse_args()
        main(args)
