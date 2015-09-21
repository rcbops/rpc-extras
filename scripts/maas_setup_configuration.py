#!/usr/bin/python
##########################################
# Updated September 21, 2015 4:06 PM CST #
##########################################

import argh
import getpass
import os
import requests
import sys
import time
import urllib2
import uuid
import yaml
from string import whitespace
from termcolor import colored


def backup_file(original_location, backup_location):
    original_handle = open(original_location, 'r')
    backup_handle = open(backup_location, 'w')
    for x in original_handle.readlines():
        backup_handle.write(x)
    original_handle.close()
    backup_handle.close()
    print colored('{0} has been backed up to {1}'.format(
        original_location, backup_location), 'green')


def get_config_contents(location):
    handle = open(location, 'r')
    contents = handle.readlines()
    handle.close()
    return contents


def save_data(location, data):
    handle = open(location, 'w')
    for x in data:
        handle.write(x)
    handle.close()
    print 'Updated config file: {0}'.format(location)


def update_config_values(key, value, config_contents):
    found = False
    for x in config_contents:
        if '{0}:'.format(key) in x:
            i = config_contents.index(x)
            config_contents.pop(i)
            config_contents.insert(i, '{0}: {1}\n'.format(key, value))
            found = True
            break
    if not found:
        for x in config_contents:
            if x[0] != '-' and x[0] not in whitespace:
                if key < x:
                    config_contents.insert(config_contents.index(x),
                                           '{0}: {1}\n'.format(key, value))
                    break


def update_lb_name(key, value, config_contents):
    found = False
    for x in config_contents:
        if '{0}:'.format(key) in x:
            i = config_contents.index(x)
            config_contents.pop(i)
            config_contents.insert(i, '{0}: {1}\n'.format(key, value))
            found = True
            break
    if not found:
        i = config_contents.index('global_overrides:\n')
        config_contents.insert(i + 1, '  {0}: {1}\n'.format(key, value))
        config_contents.insert(i + 1, '  # Load Balancer name\n')
        config_contents.insert(i + 1, '\n')


def main():
    release_file = open('/etc/rpc-release', 'r')
    release_data = [x.rstrip().replace('"', '').split('=')
                    for x in release_file.readlines()]
    release_file.close()
    release_version = (x[1] for x in release_data
                       if x[0] == 'DISTRIB_RELEASE').next()
    major_version = release_version.split('.')[0].split('r')
    major_version = int(major_version.pop())
    minor_version = int(release_version.split('.')[1])
    revision = release_version.split('.')[2]

    if major_version == 10:
        uev_fname = '/etc/rpc_deploy/user_variables.yml'
        uev_bak_fname = '/etc/rpc_deploy/user_variables.yml.bak'
        uc_fname = '/etc/rpc_deploy/rpc_user_config.yml'
        uc_bak_fname = '/etc/rpc_deploy/rpc_user_config.yml.bak'

        # Gather user config
        user_config = get_config_contents(uc_fname)
        # Check if .bak file exists
        if os.path.isfile(uc_bak_fname):
            print colored(
                "{0} has already been modified...".format(
                    os.path.basename(uc_fname)), "yellow")
        # Backup file if it doesn't exist
        else:
            backup_file(uc_fname, uc_bak_fname)

    elif major_version == 11:
        uev_fname = '/etc/openstack_deploy/user_extras_variables.yml'
        uev_bak_fname = '/etc/openstack_deploy/user_extras_variables.yml.bak'

    else:
        print colored(
            "Unsupported version of Openstack ({0})".format(release_version),
            "red")
        print "Exiting..."
        sys.exit()

    # Gather user variables
    user_extras_vars = get_config_contents(uev_fname)
    # Check if .bak file exists
    if os.path.isfile(uev_bak_fname):
        print colored(
            "{0} has already been modified...".format(
                os.path.basename(uev_fname)), "yellow")
    # Backup file if it doesn't exist
    else:
        backup_file(uev_fname, uev_bak_fname)

    # Get input from user
    account = raw_input("Enter the account number: ")
    pitchfork_token = raw_input(
        "Enter the Pitchfork token for account %s: " % account)

    # Checks Pitchfork Token Length
    if len(pitchfork_token) != 163:
        print colored("Warning:", "yellow")
        print "  Pitchfork Token length is %d.".format(len(pitchfork_token))
        print "  Expected length is 163."

    # Gets more input from user
    fqdn = raw_input("Enter the portion of the FQDN after the hostname.\n" +
                     "ex. '123456-compute01.rackspace.com' should yield " +
                     "'.rackspace.com': ")
    lb_name = raw_input("Enter the full device ID for the load balancer: ")

    update_config_values('maas_auth_method', 'token', user_extras_vars)
    update_config_values('maas_auth_token', pitchfork_token, user_extras_vars)
    update_config_values('maas_fqdn_extension', fqdn, user_extras_vars)
    update_config_values('maas_target_alias', 'public0_v4', user_extras_vars)
    update_config_values('rackspace_cloud_tenant_id', 'hybrid:{0}'.format(
        account), user_extras_vars)

    remaining_steps = []
    if major_version == 10:
        update_lb_name('lb_name', lb_name, user_config)
        save_data(uc_fname, user_config)
        remaining_steps = [
            'BE SURE TO DELETE ALL THE CHECKS IN: monitoring.rackspace.net',
            'RUN THE FOLLOWING:',
            'cd /opt/openstack-ansible/rpc_deployment/',
            'ansible hosts -m shell -a "rm ~/.auth_ref.json"',
            'ansible hosts -m shell -a "rm -rf /usr/lib/rackspace-monitoring-agent/plugins"',
            'openstack-ansible playbooks/monitoring/raxmon-all.yml',
            'openstack-ansible playbooks/monitoring/maas_local.yml',
            'openstack-ansible playbooks/monitoring/maas_remote.yml',
            'openstack-ansible playbooks/monitoring/maas_cdm.yml',
            'openstack-ansible playbooks/monitoring/maas_(hp/dell,_hardware.yml',
            'openstack-ansible playbooks/monitoring/maas_ssl_check.yml',
            'openstack-ansible playbooks/monitoring/swift_maas.yml']
    else:
        update_config_values('lb_name', lb_name, user_extras_vars)
        remaining_steps = [
            'BE SURE TO DELETE ALL THE CHECKS IN: monitoring.rackspace.net',
            'RUN THE FOLLOWING:',
            'cd /opt/rpc-openstack/rpcd/playbooks/',
            'ansible hosts -m shell -a "rm ~/.auth_ref.json"',
            'ansible hosts -m shell -a "rm -rf /usr/lib/rackspace-monitoring-agent/plugins"',
            'openstack-ansible setup-maas.yml']
    for x in remaining_steps:
        print x
    save_data(uev_fname, user_extras_vars)


argh.dispatch_command(main)
