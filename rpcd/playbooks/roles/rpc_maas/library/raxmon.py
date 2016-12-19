#!/usr/bin/env python2

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

import ConfigParser

from ansible.module_utils.basic import AnsibleModule


DOCUMENTATION = """
---
module: raxmon
short_description:
  - A module for preparing a node for Rackspace Cloud Monitoring
description:
  - This module is written for rpc-openstack's rpc_maas role specifically to
    prepare a node for Rackspace Cloud Monitoring by a) assigning an agent
    to an entity and b) creating an agent token.
options:
  cmd:
    description: The command to run
    choices = [ 'assign_agent_to_entity', 'create_agent_token' ]
    required: true
  entity:
    description: The label of the entity to operate against
    required: true
  venv_bin:
    description: The path to the venv where rackspace-monitoring is installed
    required: false
  raxmon_cfg:
    description: The path to the raxmon configuration file
    required: false
    default: /root/.raxrc
"""

EXAMPLES = """
raxmon:
  cmd: assign_agent_to_entity
  entity: controller1
  venv_bin: /openstack/venvs/maas-r14.1.0rc1/bin/

raxmon:
  cmd: create_agent_token
  entity: controller1
  venv_bin: /openstack/venvs/maas-r14.1.0rc1/bin/
"""

RETURN = """
id:
  description:
    - The ID of the entity's agent token, returned when cmd=create_agent_token
  returned: success
  type: id
"""


def _get_agent_tokens(conn, entity):
    agent_tokens = []
    for a in conn.list_agent_tokens():
        if a.label == entity:
            agent_tokens.append(a)
    return agent_tokens


def _get_conn(get_driver, provider_cls, raxmon_cfg):
    cfg = ConfigParser.RawConfigParser()
    cfg.read(raxmon_cfg)
    driver = get_driver(provider_cls.RACKSPACE)
    try:
        user = cfg.get('credentials', 'username')
        api_key = cfg.get('credentials', 'api_key')
        conn = driver(user, api_key)
    except (ConfigParser.NoSectionError, ConfigParser.NoOptionError):
        url = cfg.get('api', 'url')
        token = cfg.get('api', 'token')
        conn = driver(None, None, ex_force_base_url=url,
                      ex_force_auth_token=token)
    return conn


def _get_entities(conn, entity):
    entities = []
    for e in conn.list_entities():
        if e.label == entity:
            entities.append(e)
    return entities


def assign_agent_to_entity(module, conn, entity):
    entities = _get_entities(conn, entity)
    entities_count = len(entities)
    if entities_count == 0:
        msg = "Zero entities with the label %s exist. Entities should be " \
              "created as part of the hardware provisioning process, if " \
              "missing, please consult the internal documentation for " \
              "associating one with the device." % entity
        module.fail_json(msg=msg)
    elif entities_count == 1:
        if entities[0].label == entities[0].agent_id:
            module.exit_json(change=False)
        else:
            conn.update_entity(entities[0], {'agent_id': entity})
            module.exit_json(changed=True)
    elif entities_count > 1:
        msg = "Entity count of %s != 1 for entity with the label %s. Reduce " \
              "the entity count to one by deleting or re-labelling the " \
              "duplicate entities." % (entities_count, entity)
        module.fail_json(msg=msg)


def create_agent_token(module, conn, entity):
    agent_tokens = _get_agent_tokens(conn, entity)
    agent_tokens_count = len(agent_tokens)
    if agent_tokens_count == 0:
        module.exit_json(
            changed=True,
            id=conn.create_agent_token(label=entity).id
        )
    elif agent_tokens_count == 1:
        module.exit_json(
            changed=False,
            id=agent_tokens[0].id
        )
    elif agent_tokens_count > 2:
        msg = "Agent token count of %s > 1 for entity with " \
              "the label %s" % (agent_tokens_count, entity)
        module.fail_json(msg=msg)


def main():
    module = AnsibleModule(
        argument_spec=dict(
            cmd=dict(
                choices=['assign_agent_to_entity', 'create_agent_token'],
                required=True
            ),
            entity=dict(required=True),
            venv_bin=dict(),
            raxmon_cfg=dict(default='/root/.raxrc')
        )
    )

    if module.params['venv_bin']:
        activate_this = '%s/activate_this.py' % (module.params['venv_bin'])
        execfile(activate_this, dict(__file__=activate_this))

    # We place these imports after we activate the virtualenv to ensure we're
    # importing the correct libraries
    from rackspace_monitoring.providers import get_driver
    from rackspace_monitoring.types import Provider

    conn = _get_conn(get_driver, Provider, module.params['raxmon_cfg'])

    if module.params['cmd'] == 'assign_agent_to_entity':
        assign_agent_to_entity(module, conn, module.params['entity'])
    elif module.params['cmd'] == 'create_agent_token':
        create_agent_token(module, conn, module.params['entity'])


if __name__ == '__main__':
    main()
