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
import collections
import ipaddr
import time

from glanceclient import exc as exc
from maas_common import get_auth_ref
from maas_common import get_glance_client
from maas_common import metric
from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


IMAGE_STATUSES = ['active', 'queued', 'killed']


def check(auth_ref, args):
    GLANCE_ENDPOINT = (
        'http://{ip}:9292/v1'.format(ip=args.ip)
    )

    try:
        if args.ip:
            glance = get_glance_client(endpoint=GLANCE_ENDPOINT)
        else:
            glance = get_glance_client()

        is_up = True
    except exc.HTTPException:
        is_up = False
    # Any other exception presumably isn't an API error
    except Exception as e:
        status_err(str(e))
    else:
        # time something arbitrary
        start = time.time()
        glance.images.list(search_opts={'all_tenants': 1})
        end = time.time()
        milliseconds = (end - start) * 1000
        # gather some metrics
        images = glance.images.list(search_opts={'all_tenants': 1})
        status_count = collections.Counter([s.status for s in images])

    status_ok()
    metric_bool('glance_api_local_status', is_up)

    # only want to send other metrics if api is up
    if is_up:
        metric('glance_api_local_response_time',
               'double',
               '%.3f' % milliseconds,
               'ms')
        for status in IMAGE_STATUSES:
            metric('glance_%s_images' % status,
                   'uint32',
                   status_count[status],
                   'images')


def main(args):
    auth_ref = get_auth_ref()
    check(auth_ref, args)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(description="Check Glance API against"
                                         " local or remote address")
        parser.add_argument('ip', nargs='?',
                            type=ipaddr.IPv4Address,
                            help='Optional Glance API server address')
        args = parser.parse_args()
        main(args)
