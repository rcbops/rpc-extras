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

import os
import sys
import yaml

# Read the release file path from a CLI parameter or environment variable.
if len(sys.argv) > 1:
    release_file = sys.argv[1]
else:
    release_file = os.environ['RELEASE_FILE']

# Read the RPC release series name from a CLI parameter or environment
# variable.
if len(sys.argv) > 2:
    release_series = sys.argv[2]
else:
    release_series = os.environ['RPC_PRODUCT_RELEASE']

# Read the file contents
with open(release_file) as f:
    release_file_content = yaml.safe_load(f.read())

# Read the series-specific data
release_data = release_file_content['rpc_product_releases'][release_series]

# Get the current rpc_release version
rpc_release = release_data['rpc_release']

# Print out the rpc_release value
print(rpc_release)
