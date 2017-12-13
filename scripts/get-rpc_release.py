#!/usr/bin/env python
# Copyright 2014-2017, Rackspace US, Inc.
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
import os
import sys
import yaml


# Sourced from: https://stackoverflow.com/a/10551190
class EnvDefault(argparse.Action):
    def __init__(self, envvar, required=True, default=None, **kwargs):
        if not default and envvar:
            if envvar in os.environ:
                default = os.environ[envvar]
        if required and default:
            required = False
        super(EnvDefault, self).__init__(default=default, required=required,
                                         **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values)

# Setup argument parsing
parser = argparse.ArgumentParser(
    description='Utility to retrieve the rpc_release version'
                ' based on the series given.',
    epilog='Licensed "Apache 2.0"')

parser.add_argument(
    '-f',
    '--release_file',
    action=EnvDefault,
    default='/opt/rpc-openstack/playbooks/vars/rpc-release.yml',
    envvar='RELEASE_FILE',
    help='Release file path, optionally set using the RELEASE_FILE'
         ' environment variable.',
    required=False
)

parser.add_argument(
    '-r',
    '--release_series',
    action=EnvDefault,
    default='pike',
    envvar='RPC_PRODUCT_RELEASE',
    help='Release series, optionally set using the RPC_PRODUCT_RELEASE'
         'environment variable.',
    required=False
)

# Parse arguments
args = parser.parse_args()

# Read the file contents
try:
    with open(args.release_file) as f:
        release_file_content = yaml.safe_load(f.read())
except IOError as e:
    print >> sys.stderr, "Unable to open file '%s'." % args.release_file
    sys.exit(1)

# Read the series-specific data
try:
    release_data = (
        release_file_content['rpc_product_releases'][args.release_series])
except KeyError as e:
    print >> sys.stderr, "Unable to find release '%s'." % args.release_series
    sys.exit(1)

# Get the current rpc_release version
rpc_release = release_data['rpc_release']

# Print out the rpc_release value
print(rpc_release)
