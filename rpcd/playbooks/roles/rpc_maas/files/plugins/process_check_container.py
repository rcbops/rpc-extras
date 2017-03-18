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

import lxc
import psutil


def venv_wrapper_check():
    """Check if we are running inside the virtualenv wrapper script."""
    # Are we running inside the virtualenv wrapper script?
    parent_process = psutil.Process(os.getpid()).parent
    if 'run_plugin_in_venv.sh' in ' '.join(parent_process.cmdline):
        return parent_process.pid
    else:
        return False


def get_processes(parent_pid=None):
    """Get processes from the system.

    Retrieves all processes from the system. Provide a PID via parent_pid if
    you want to get child processes of that specific PID (example: in a
    container).
    """
    # Don't examine the process of this script.
    excluded_pids = [os.getpid()]

    # Don't examine the process of the venv wrapper script, either.
    if venv_wrapper_check():
        excluded_pids.append(venv_wrapper_check())

    if parent_pid is None:
        procs = [x for x in psutil.process_iter()
                 if x.pid not in excluded_pids]
    else:
        procs = [x for x in psutil.Process(parent_pid).get_children()]
    return procs


def check_process_running(process_names, container_name=None):
    """Check to see if processes are running.

    Check if each of the processes in process_names are in a list
    of running processes in the specified container name, or on
    this host.
    """
    procs = get_processes()

    if container_name is not None:
        # Get the container's init PID.
        init_pid = lxc.Container(container_name).init_pid

        # If the container wasn't found, exit now.
        if init_pid == -1:
            status_err('Could not find PID for container {}'.format(
                container_name)
            )

        # Get the processes within the container.
        procs = get_processes(parent_pid=init_pid)

    if not procs:
        # Unable to get a list of process names for the container or host.
        status_err('Could not get a list of running processes')

    # Since we've fetched a process list, report status_ok.
    status_ok()

    # Make a list of command lines from each PID. There's a chance that one or
    # more PIDs may have exited already and this causes a NoSuchProcess
    # exception.
    cmdlines = []
    for proc in procs:
        try:
            cmdlines.append(map(os.path.basename, proc.cmdline))
        except psutil._error.NoSuchProcess:
            pass

    # Loop through the process names provided on the command line to see if
    # they exist on the system or in a container.
    for process_name in process_names:
        matches = [x for x in cmdlines if process_name in x]
        metric_bool('%s_process_status' % process_name, len(matches) > 0)


def main(args):
    """Main function."""
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
