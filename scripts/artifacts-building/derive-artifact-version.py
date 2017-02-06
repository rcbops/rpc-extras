#!/usr/bin/env python
#
# Copyright 2017, Rackspace US, Inc.
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
#
# (c) 2017, Jesse Pretorius <jesse.pretorius@rackspace.co.uk>

"""Determine the version string to use for artifact publishing."""

from __future__ import print_function

import re
import subprocess

GIT_FOLDER = (
    '/opt/rpc-openstack'
)
CMD_GET_TAG = (
    "git describe --tags --abbrev=0"
)
CMD_GET_BRANCH = (
    "git branch --contains $(git rev-parse HEAD) | grep ^\* | sed 's/^\* //'"
)


def main():
    """Run the main application."""

    current_tag = subprocess.check_output(
        CMD_GET_TAG, cwd=GIT_FOLDER, shell=True).strip()

    current_branch = subprocess.check_output(
        CMD_GET_BRANCH, cwd=GIT_FOLDER, shell=True).strip()

    if current_branch == "master":

        # All artifacts for the master branch must be published
        # using the tag 'master'.
        archive_version = current_branch

    else:

        (version_major, version_minor, version_patch) = current_tag.split('.')
        (branch_major, branch_minor) = current_branch.split('.')

        branch_major = re.sub(r"^.*-", "", branch_major)
        version_major = re.sub(r"^r", "", version_major)

        branch_version = "%s.%s" % (branch_major, branch_minor)
        tag_version = "%s.%s" % (version_major, version_minor)

        # If the branch version and tag version do not match
        # then this must be preparation for the first release
        # candidate.
        if branch_version != tag_version:

            archive_version = "r%s.%s.0rc1" % (
                branch_major,
                branch_minor
            )

        # If a release candidate has been tagged, increment
        # the version for the release candidate.
        elif "rc" in version_patch:

            (version_rc_patch, version_rc_rc) = version_patch.split('rc')
            archive_patch_version = int(version_rc_rc) + 1

            archive_version = "r%s.%s.%src%s" % (
                version_major,
                version_minor,
                version_rc_patch,
                archive_patch_version
            )

        # If none of the above conditions are met, simply increment
        # the patch version.
        else:

            archive_patch_version = int(version_patch) + 1

            archive_version = "r%s.%s.%s" % (
                version_major,
                version_minor,
                archive_patch_version
            )

    print(archive_version)

if __name__ == "__main__":
    main()
