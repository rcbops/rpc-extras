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
# (c) 2017, Jean-Philippe Evrard <jean-philippe.evrard@rackspace.co.uk>

# Take a list of paths for a distro, returns which system packages
# (distro_packages, apt_packages, yum_packages) will be installed.
# Outputs a list.
# example:
# tasks:
#   - debug:
#       var: item
#     with_packages_to_install:
#       - from:
#           - /etc/ansible/roles
#           - ./
#         for: trusty
#         #pkg_blacklist: []
#         #var_blacklist: []
import os
import re
import yaml

# import ansible things
from ansible.plugins.lookup import LookupBase
from ansible.errors import AnsibleLookupError

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()

BUILT_IN_DISTRO_PACKAGE_VARS = [
    'distro_packages',
    'apt_packages',
    'yum_packages'
]


# Convenience mappings
distro_specific_paths = {}
distro_specific_paths['trusty'] = [
    '/vars/ubuntu-14.04.',
    '/vars/ubuntu.',
    '/vars/debian.',
    '/vars/main.',
]
distro_specific_paths['xenial'] = [
    '/vars/ubuntu-16.04.',
    '/vars/ubuntu.',
    '/vars/debian.',
    '/vars/main.',
]
distro_specific_paths['ubuntu-14.04'] = [
    '/vars/ubuntu-14.04.',
    '/vars/ubuntu.',
    '/vars/debian.',
    '/vars/main.',
]
distro_specific_paths['ubuntu-16.04'] = [
    '/vars/ubuntu-16.04.',
    '/vars/ubuntu.',
    '/vars/debian.',
    '/vars/main.',
]
distro_specific_paths['redhat-7'] = [
    '/vars/redhat-7.',
    '/vars/redhat.',
    '/vars/main.',
]
generic_paths = ['/defaults/', '/user_']


def filter_files(file_names, file_name_words):
    """Filter the files and return a sorted list.
    :type file_names:
    :type ext: ``str`` or ``tuple``
    :returns: ``list``
    """
    extensions = ('yaml', 'yml')
    _file_names = list()
    # Uncomment out this for debugging purposes
    # print("Filtering according to words {}".format(file_name_words))
    for file_name in file_names:
        if file_name.endswith(extensions):
            if any(i in file_name for i in file_name_words):
                # Uncomment out this for listing the matching files
                # print("Filename {} is a match".format(file_name))
                _file_names.append(file_name)
    else:
        return _file_names


def get_files(path):
    paths = os.walk(os.path.abspath(path))
    files = list()
    for fpath, _, afiles in paths:
        for afile in afiles:
            files.append(os.path.join(fpath, afile))
    else:
        return files


def get_package_list(distro, path, var_blacklist, pkg_blacklist):
    path_triggers = []
    path_triggers.extend(distro_specific_paths[distro])
    path_triggers.extend(generic_paths)
    pkg_blklst_re = ""
    if pkg_blacklist:
        pkg_blklst_re = "(" + ")|(".join(pkg_blacklist) + ")"

    packages_list = []
    # Uncomment out this for debugging purposes
    # print("Scanning path {} for files matching distro {}".format(path,distro))
    for folder in path:
        all_files = get_files(folder)
        for filename in filter_files(all_files, path_triggers):
            with open(filename, 'r') as f:
                try:
                    loaded_config = yaml.safe_load(f.read())
                except Exception as e:
                    # Ignore loading errors, the file may be empty
                    continue
            try:
                for key, values in loaded_config.items():
                    key = key.lower()
                    for type_of_package in BUILT_IN_DISTRO_PACKAGE_VARS:
                        if (key.endswith(type_of_package) and
                                key not in var_blacklist):
                            for value in values:
                                # If no blacklist or not in blacklist
                                # append value (package name)
                                if (not re.match(pkg_blklst_re, value) or
                                        not pkg_blacklist):
                                    # If package is formatted like packagename==version
                                    if value.find('=') != -1:
                                        packages_list.append(value.split('=')[0])
                                    else:
                                        packages_list.append(value)
            except AttributeError as e:
                continue

    return packages_list


class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        term_pkgs = []
        for term in terms:
            if isinstance(term, dict):
                paths = term.get('from', [])
                distro = term.get('for', "")
                pkg_blacklist = term.get('pkg_blacklist', [])
                var_blacklist = term.get('var_blacklist', [])
            else:
                raise AnsibleLookupError("Lookup item should be a dict")
            if not distro:
                raise AnsibleLookupError("Distro (for:) cannot be empty")
            if not paths:
                raise AnsibleLookupError("Locations (from:) cannot be empty")
            term_pkgs.extend(get_package_list(distro, paths, var_blacklist, pkg_blacklist))
        return term_pkgs


# For debug purposes
if __name__ == '__main__':
    import sys
    import json
    call_term = {}
    call_term['for'] = sys.argv[1]
    call_term['from'] = sys.argv[2:]
    call_terms = [call_term]
    print(json.dumps(LookupModule().run(terms=call_terms), indent=4, sort_keys=True))

