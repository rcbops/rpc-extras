#!/usr/bin/env bash
export ANSIBLE_ACTION_PLUGINS="/etc/ansible/roles/plugins/action"
export ANSIBLE_CALLBACK_PLUGINS="/etc/ansible/roles/plugins/callback"
export ANSIBLE_CALLBACK_WHITELIST="profile_tasks"
export ANSIBLE_FILTER_PLUGINS="/etc/ansible/roles/plugins/filter"
export ANSIBLE_HOST_KEY_CHECKING="False"
export ANSIBLE_INVENTORY="localhost,"
export ANSIBLE_LIBRARY="/etc/ansible/roles/plugins/library"
export ANSIBLE_LOOKUP_PLUGINS="/etc/ansible/roles/plugins/lookup"
export ANSIBLE_TEST_PLUGINS="/etc/ansible/roles/plugins/test"
export ANSIBLE_VARS_PLUGINS="/etc/ansible/roles/plugins/vars_plugins"
(/opt/rpc-ansible/bin/ansible-playbook $@) && exit 0
