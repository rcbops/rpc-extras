#!/usr/bin/env python
import os
import sys
import subprocess
import yaml

basedir = os.path.abspath(os.path.dirname(__file__))
vars_yaml = os.path.join(basedir, '../global_vars/all/config.yml')
rpc_repo_path = yaml.load(open(vars_yaml, 'r'))['rpc_repo_path']

rpc_inventory = os.path.join(rpc_repo_path,
                             'playbooks/inventory/dynamic_inventory.py')
subprocess.call([rpc_inventory] + sys.argv[1:])
