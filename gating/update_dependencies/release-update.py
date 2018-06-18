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

import re
import os
import semver
import yaml

# Read the release file path from an environment variable
release_file = os.environ['RELEASE_FILE']

# Read the RPC release series name from an environment variable
release_series = os.environ['RPC_PRODUCT_RELEASE']

# Read the osa_release to set from an environment variable
osa_release = os.environ['OSA_SHA']

# Read the rpc_rc_release version from an environment variable
rpc_rc_release = os.environ['RC_BRANCH_VERSION']

# Read the file contents
with open(release_file) as f:
    release_file_content = yaml.safe_load(f.read())

# Read the series-specific data
release_data = release_file_content['rpc_product_releases'][release_series]

# Get the current rpc_release version
rpc_release = release_data['rpc_release']

# Validate that the version complies with the RPC-O
# version naming standards.
# ref: https://rpc-openstack.atlassian.net/browse/RE-1199
#
# This is important for all PR's to ensure that we're
# changing the version to something matching the right
# standard.

release_naming_standard = re.compile(
    "^r[0-9]+.[0-9]+.[0-9]+(-(alpha|beta).[0-9]+)?$")

assert release_naming_standard.match(rpc_release), (
    "The rpc_release value of %s does not comply with the release naming"
    " standard. Please correct it!" % rpc_release)

# Extract the SemVer-compliant portion of the version (no 'r' prefix)
rpc_release_semver = re.sub('^r', '', rpc_release)

# If the rpc_rc_release and rpc_release versions match,
# then we need to increment the value of rpc_release.
if rpc_rc_release == rpc_release:

    # If the current version is a prerelease version,
    # then increment the prerelease.
    rpc_release_parts = semver.parse(rpc_release_semver)
    if rpc_release_parts['prerelease'] is not None:
        rpc_release_semver_new = semver.bump_prerelease(rpc_release_semver)

    # Otherwise, this is a standard release and we
    # just need to do a patch version increment.
    else:
        rpc_release_semver_new = semver.bump_patch(rpc_release_semver)

    # Now add the 'r' prefix back on for the final version
    rpc_release = "r" + rpc_release_semver_new

# Adjust the OSA SHA
release_data['osa_release'] = osa_release

# Adjust the RPC release version
release_data['rpc_release'] = rpc_release

# Write the file
with open(release_file, 'w') as f:
    f.write(
        yaml.safe_dump(
            release_file_content, default_flow_style=False, width=1000))

# Output the details for debugging purposes
print('Product release set: [%s]' % release_data)
