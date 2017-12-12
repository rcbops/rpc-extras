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

import sys

import yaml

product_release_file = sys.argv[1]
product_release = sys.argv[2]
product_maas_version = sys.argv[3] if len(sys.argv) >= 4 else None
product_osa_version = sys.argv[4] if len(sys.argv) >= 5 else None
product_rpc_version = sys.argv[5] if len(sys.argv) >= 6 else None

release_file = product_release_file

with open(release_file) as f:
  x = yaml.safe_load(f.read())

release_data = x['rpc_product_releases'][product_release]

if product_rpc_version:
    release_data['rpc_release'] = product_rpc_version

if product_maas_version:
    release_data['maas_release'] = product_maas_version

if product_osa_version:
    release_data['osa_release'] = product_osa_version

with open(product_release_file, 'w') as f:
  f.write(yaml.safe_dump(x, default_flow_style=False, width=1000))


RELEASE = """osa_release="%(osa_release)s"
maas_release="%(maas_release)s"
rpc_release="%(rpc_release)s"
"""

print(RELEASE % release_data)
