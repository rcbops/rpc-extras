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
import argparse
import errno
import yaml


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('base',
                        help='The path to the yaml file with the base '
                             'configuration.')
    parser.add_argument('overrides',
                        help='The path to the yaml file with overrides.')
    return parser.parse_args()


def get_config(path):
    try:
        with open(path) as f:
            data = f.read()
    except IOError as e:
        if e.errno == errno.ENOENT:
            data = None
        else:
            raise e

    if data is None:
        return {}
    else:
        # assume config is a dict
        return yaml.safe_load(data)


if __name__ == '__main__':
    args = parse_args()
    base = get_config(args.base)
    overrides = get_config(args.overrides)
    config = dict(base.items() + overrides.items())
    if config:
        with open(args.base, 'w') as f:
            f.write(str(yaml.safe_dump(config, default_flow_style=False)))
