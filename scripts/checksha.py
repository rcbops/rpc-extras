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
# (c) 2015, Darren Birkett <darren.birkett@gmail.com>
from __future__ import print_function

import argparse
import os
import subprocess
import sys

from subprocess import CalledProcessError

import ansible.inventory
import ansible.runner


def get_args():
    """Get the arguments."""
    parser = argparse.ArgumentParser(
        prog='checksha',
        description='Given a commit sha and an Openstack project name, '
                    'find out if the wheel that is currently installed '
                    'for that Openstack project in this deployment '
                    'includes that commit.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument(
        'project', type=str, default=None,
        help='name of openstack project wheel to query')
    parser.add_argument(
        'commit', type=str, default=None,
        help='SHA of commit that you are interested in')
    parser.add_argument(
        '-s', '--sha', type=str, default=None,
        help='provide a parent sha rather than interrogating the wheels '
             'that are deployed in the solution to get the sha')
    parser.add_argument(
        '-c', '--clonedir', type=str, default='/tmp',
        help='where to clone the git repo for history interrogation')
    parser.add_argument(
        '-b', '--basedir', type=str,
        default='/opt/rpc-openstack/os-ansible-deployment',
        help='the base directory in which to recursively search for '
             'the dynamic inventory file')
    parser.add_argument(
        '-i', '--inventory', type=str, default='dynamic_inventory.py',
        help='the name of the dynamic inventory file to find'),
    parser.add_argument(
        '-u', '--cloneuri', type=str,
        default='https://git.openstack.org/openstack',
        help='base uri from which to clone the git repo. The project '
             'name will be appended to make the full clone uri'),
    parser.add_argument(
        '-p', '--pattern', type=str, default=None,
        help='host pattern to pass to the ansible command. By default '
             '<PROJECT>_all will be used')

    return parser.parse_args()


def find_inventory(inv, path):
    """Find the dynamic inventory file"""
    if os.path.isfile(inv):
        return inv
    for root, dirs, files in os.walk(path):
        if inv in files:
            return os.path.join(root, inv)


def clone_git_repo(project, clonedir, cloneuri):
    """clone a git repo"""
    if not os.path.exists('%s/%s' % (clonedir, project)):
        print('cloning %s project to interrogate the history...'
              'please be patient this may take a while' % project)
        os.chdir(clonedir)
        try:
            subprocess.check_call(
                'git clone %s/%s.git '
                '--quiet' % (cloneuri, project),
                shell=True, stderr=subprocess.STDOUT)
        except CalledProcessError as e:
            print('Something went wrong when trying to clone the repo')
            sys.exit(e)
    else:
        print('%s/%s already exists...'
              'fetching the latest commits' % (clonedir, project))
        os.chdir('%s/%s' % (clonedir, project))
        try:
            subprocess.check_call(
                'git fetch --all --quiet',
                shell=True, stderr=subprocess.STDOUT)
        except CalledProcessError as e:
            print('Something went wrong when trying to update the repo')
            sys.exit(e)


def parse_results(results, project):
    """parse results of the ansible run"""
    shas = set()
    output = dict()
    for status in results.keys():
        if status == 'contacted':
            for (hostname, result) in results['contacted'].items():
                if 'not installed' in result['stdout'] or not result['stdout']:
                    output[hostname] = '%s is not installed' % project
                else:
                    sh = result['stdout'].split()[3]
                    shas.add(sh)
                    output[hostname] = sh
        elif status == 'dark':
            for hostname in results['dark'].keys():
                output[hostname] = 'uncontactable'
    # bail if multiple or no shas found
    if len(shas) == 0:
        print('no hosts are running project %s...exiting' % project)
        sys.exit(1)
    elif len(shas) > 1:
        print('you seem to have multiple versions of the %s wheel '
              'deployed in your solution...exiting' % project)
        sys.exit(1)
    else:
        sha = list(shas)[0]
        return sha, output


def print_output(output):
    """print parsed output"""
    longest = (max(len(x) for x in output))
    longest = 45 if longest < 45 else longest
    print ('{:<%d} {:<10} ' % longest).format('Hostname', 'SHA')
    print ('{:<%d} {:<10} ' % longest).format('--------', '---')
    for host, sha in sorted(output.items()):
        print ('{:<%d} {:<10} ' % longest).format(host, sha)
    print('')


def is_ancestor(commit, sha, path):
    """check if commit is an ancestor of sha"""
    # (NOTE) git merge-base returns no output, just a return code:
    # 1: not an ancestor
    # 0: is an ancestor
    # 128: not a valid git object (for either sha or commit)
    # other: OS error
    os.chdir(path)
    try:
        subprocess.check_call(
            'git merge-base --is-ancestor %s %s' % (commit, sha), shell=True)
    except CalledProcessError as e:
        if e.returncode == 1:
            # not an ancestor
            return False
        else:
            # command went wrong
            sys.exit(e)
    else:
        return True


def run_ansible(inventory, basedir, project, pattern=None):
    """run ansible and interrogate wheels on target hosts"""
    if not pattern:
        pattern = '%s_all' % project
    dyn_inventory = find_inventory(inventory, basedir)
    if not dyn_inventory:
        print('Could not find the supplied '
              'dynamic inventory file: "%s"' % inventory)
        sys.exit(1)
    iv = ansible.inventory.Inventory(dyn_inventory)
    results = ansible.runner.Runner(
        pattern=pattern,
        inventory=iv,
        forks=10,
        module_name='shell',
        module_args='pbr info %s' % project).run()
    return results


def main(args):
    """main program"""
    project = args.project
    commit = args.commit
    inventory = args.inventory
    basedir = args.basedir
    clonedir = args.clonedir
    cloneuri = args.cloneuri
    clonepath = '%s/%s' % (clonedir, project)
    pattern = args.pattern

    if args.sha:
        sha = args.sha
        msg = 'The provided sha %s' % sha
    else:
        results = run_ansible(inventory, basedir, project, pattern=pattern)
        sha, output = parse_results(results, project)
        print_output(output)
        msg = 'The installed %s wheel (%s)' % (project, sha)

    clone_git_repo(project, clonedir, cloneuri)

    if is_ancestor(commit, sha, clonepath):
        print('\n %s ***DOES*** contain commit %s' % (msg, commit))
    else:
        print('\n %s ***DOES NOT*** contain commit %s\n' % (msg, commit))

if __name__ == '__main__':
    main(get_args())
