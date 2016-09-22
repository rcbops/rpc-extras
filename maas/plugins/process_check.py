#!/usr/bin/env python
#
# Copyright 2015, Rackspace US, Inc.
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

from maas_common import metric_bool
from maas_common import print_output
from maas_common import status_err
from maas_common import status_ok


def get_process_name(pid):
    process_exe_path = os.path.join('/proc', pid, 'exe')
    process_comm_path = os.path.join('/proc', pid, 'comm')

    try:
        process_exe = os.readlink(process_exe_path)
        with open(process_comm_path, mode='r') as f:
            comm = f.read().rstrip('\n')
    except OSError as ex:
        if ex.errno == os.errno.ENOENT:
            return set()
        status_err('Could not read process information.', exception=ex)
    except IOError as ex:
        # The path we are checking for a PID list does not exist.
        # This is probably caused by an invalid container name.
        status_err('No such process exists. {}', exception=ex)

    # Return the "exe" path and the baesname of the "exe" path, and
    # the value contained in comm to make matching easier
    return set([comm, process_exe, os.path.basename(process_exe)])


def get_processes(procs_path):
    process_names = set()
    try:
        with open(procs_path, mode='r') as f:
            for pid in f.read().splitlines():
                process_names.update(get_process_name(pid))
    except OSError as ex:
        # Could not read the PID list file, probably due to a permission
        # error. This is different from an IOError, so we handle the two
        # types differently.
        status_err('Could not read PID list file. {}', exception=ex)
    except IOError as ex:
        # The path we are checking for a PID list does not exist.
        # This is probably caused by an invalid container name.
        status_err('No such container exists. {}', exception=ex)

    # Return a set() of potential process names resolved from their PID
    return process_names


def check_process_running(process_names, container_name=None):
    """Check to see if processes are running.

       Check if each of the processes in process_names are in a list
       of running processes in the specified container name, or on
       this host.
    """

    if not process_names:
        # The caller has not provided a value for process_names, which gives us
        # nothing to do. Return an error for the check.
        status_err('No process names provided')

    procs = []
    if container_name is None:
        # Checking for processes on a host, not inside a container
        procs_path = '/sys/fs/cgroup/cpu/cgroup.procs'
        procs = get_processes(procs_path)
    else:
        # Checking for processes in a container, not the parent host
        procs_path = os.path.join('/sys/fs/cgroup/cpu/lxc', container_name,
                                  'cgroup.procs')
        procs = get_processes(procs_path)

    if not procs:
        # Unable to get a list of process names for the container or host.
        status_err('Could not get a list of running processes')

    # Since we've fetched a process list, report status_ok.
    status_ok()

    # Report the presence of each process from the command line in the
    # running process list for the host or specified container.
    for process_name in process_names:
        metric_bool('%s_process_status' % process_name,
                    process_name in procs)


def main(args):
    if not args.processes:
        # The command line does not have any process names specified
        status_err('No executable names supplied')

    check_process_running(container_name=args.container,
                          process_names=args.processes)


if __name__ == "__main__":
    with print_output():
        parser = argparse.ArgumentParser(
            description='Check a host or container for running processes')
        parser.add_argument('-c', '--container', action='store')
        parser.add_argument('processes', nargs=argparse.REMAINDER)
        args = parser.parse_args()
        main(args)
