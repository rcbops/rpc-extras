#!/usr/bin/env python
# Copyright 2014, Rackspace US, Inc.
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
# (c) 2014, Kevin Carter <kevin.carter@rackspace.com>
# Fork by David Pham <david.pham@rackspace.com>
# Butchered by Jonny Awesome
import argparse
import json
import os

PART = 'RPC'
PREFIX_NAME = 'RPC'

ADDEXTMON = (
    # Adds EXTERNAL MONITOR KILO to exisiting Pools
    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_CINDER_API { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_NOVA_API_OS_COMPUTE { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_NEUTRON_SERVER { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_KEYSTONE_SERVICE { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_GLANCE_API { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_GLANCE_REGISTRY { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_HEAT_API { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_SWIFT { monitor ' + PREFIX_NAME +
    '-MON-EXT-ENDPOINT-KILO }',

    r'modify ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_GALERA { monitor ' + PREFIX_NAME + '_MON_GALERA }''\n'
    )
CLEANUP = (
    # Fix Repo
    r'delete ltm virtual /' + PART + '/' + PREFIX_NAME + '_VS_REPO',

    r'delete ltm pool /' + PART + '/' + PREFIX_NAME + '_POOL_REPO',

    r'delete ltm monitor http /' + PART + '/' + PREFIX_NAME +
    '_MON_HTTP_REPO' + '\n',

    # Rename Spice to NovaConsole
    r'delete ltm virtual /' + PART + '/' + PREFIX_NAME +
    '_PUB_VS_NOVA_SPICE_CONSOLE',

    r'delete ltm virtual /' + PART + '/' + PREFIX_NAME +
    '_VS_NOVA_SPICE_CONSOLE',

    r'delete ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_NOVA_SPICE_CONSOLE',

    r'delete ltm monitor http /' + PART + '/' + PREFIX_NAME +
    '_MON_HTTP_NOVA_SPICE_CONSOLE''\n',

    # Delete EC2
    r'delete ltm virtual /' + PART + '/' + PREFIX_NAME +
    '_PUB_SSL_VS_NOVA_API_EC2',

    r'delete ltm virtual /' + PART + '/' + PREFIX_NAME +
    '_VS_NOVA_API_EC2',

    r'delete ltm pool /' + PART + '/' + PREFIX_NAME +
    '_POOL_NOVA_API_EC2',

    r'delete ltm monitor tcp /' + PART + '/' + PREFIX_NAME +
    '_MON_TCP_NOVA_API_EC2''\n'
)

MONITORS = [
    r'modify ltm monitor mysql /' + PART + '/' + PREFIX_NAME +
    '_MON_GALERA { username monitoring }',

    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME +
    '_MON_HTTP_NOVA_CONSOLE {'
    r' defaults-from http destination *:6082 recv "200 OK"' +
    ' send "HEAD /spice_auto.html'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }',

    r'modify ltm monitor https /' + PART + '/' + PREFIX_NAME +
    '_MON_HTTPS_HORIZON_SSL { send'
    r' "HEAD /auth/login/ HTTP/1.1\r\nHost: rpc\r\n\r\n" }',

    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME +
    '_MON_HTTP_REPO {'
    r' defaults-from http destination *:8181 recv "200 OK" send "HEAD /'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }'
    '\n'
]

NODES = (
    'create ltm node /' + PART +
    '/%(node_name)s { address %(container_address)s }'
)

PRIORITY_ENTRY = '{ priority-group %(priority_int)s }'

POOL_NODE = {
    'beginning': 'create ltm pool /' + PART + '/%(pool_name)s {'
    ' load-balancing-mode least-connections-node members replace-all-with'
    ' { %(nodes)s }',
    'priority': 'min-active-members 1',
    'end': 'monitor %(mon_type)s }'
}

VIRTUAL_ENTRIES_PARTS = {
    'command': 'create ltm virtual /' + PART + '/%(vs_name)s',
}

PERSIST_OPTION = 'persist replace-all-with { /' + PART + '/' + PREFIX_NAME + \
                 '_PROF_PERSIST_IP }'

END_COMMANDS = [
    'save sys config',
    'run cm config-sync to-group SYNC-FAILOVER'
]

VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/%(vs_name)s {'
    ' destination %(internal_lb_vip_address)s:%(port)s'
    ' ip-protocol tcp mask 255.255.255.255'
    ' pool /' + PART + '/%(pool_name)s'
    r' profiles replace-all-with { /Common/fastL4 { } }'
    '  %(persist)s'
    ' source 0.0.0.0/0'
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME +
    '_SNATPOOL type snat }'
    ' }'
)

PUB_SSL_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/%(vs_name)s {'
    ' destination %(ssl_public_ip)s:%(port)s ip-protocol tcp'
    ' pool /' + PART + '/%(pool_name)s'
    r' profiles replace-all-with { /Common/tcp { } %(ssl_profiles)s }'
    ' %(persist)s'
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME +
    '_SNATPOOL type snat }'
    ' }'
)

PUB_NONSSL_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/%(vs_name)s {'
    ' destination %(ssl_public_ip)s:%(port)s ip-protocol tcp'
    ' pool /' + PART + '/%(pool_name)s'
    r' profiles replace-all-with { /Common/fastL4 { } }'
    ' %(persist)s'
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME +
    '_SNATPOOL type snat }'
    ' }'
)

# This is a dict of all groups and their respected values / requirements
POOL_PARTS = {
    'nova_console': {
        'port': 6082,
        'backend_port': 6082,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_NOVA_CONSOLE',
        'group': 'nova_console',
        'hosts': [],
        'ssl_impossible': True,
        'make_public': True,
        'persist': True
    },
    'repo': {
        'port': 8181,
        'backend_port': 8181,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_REPO',
        'group': 'pkg_repo',
        'priority': True,
        'hosts': []
    }
}


def recursive_host_get(inventory, group_name, host_dict=None):
    if host_dict is None:
        host_dict = {}

    inventory_group = inventory.get(group_name)
    if not inventory_group:
        print('Inventory group "%s" not found, skipping.' % group_name)
        return host_dict

    if 'children' in inventory_group and inventory_group['children']:
        for child in inventory_group['children']:
            recursive_host_get(
                inventory=inventory, group_name=child, host_dict=host_dict
            )

    if inventory_group.get('hosts'):
        for host in inventory_group['hosts']:
            if host not in host_dict['hosts']:
                ca = inventory['_meta']['hostvars'][host]['container_address']
                node = {
                    'hostname': host,
                    'container_address': ca
                }
                host_dict['hosts'].append(node)

    return host_dict


def build_pool_parts(inventory):
    for key, value in POOL_PARTS.iteritems():
        recursive_host_get(
            inventory, group_name=value['group'], host_dict=value
        )

    return POOL_PARTS


def file_find(filename, user_file=None, pass_exception=False):
    """Return the path to a file.

    If no file is found the system will exit.
    The file lookup will be done in the following directories:
      /etc/openstack_deploy/
      $HOME/openstack_deploy/
      $(pwd)/openstack_deploy/

    :param filename: ``str``  Name of the file to find
    :param user_file: ``str`` Additional localtion to look in FIRST for a file
    """
    file_check = [
        os.path.join(
            '/etc', 'openstack_deploy', filename
        ),
        os.path.join(
            os.environ.get('HOME'), 'openstack_deploy', filename
        ),
        os.path.join(
            os.getcwd(), filename
        )
    ]

    if user_file is not None:
        file_check.insert(0, os.path.expanduser(user_file))

    for f in file_check:
        if os.path.isfile(f):
            return f
    else:
        if pass_exception is False:
            raise SystemExit('No file found at: %s' % file_check)
        else:
            return False


def args():
    """Setup argument Parsing."""
    parser = argparse.ArgumentParser(
        usage='%(prog)s',
        description='Rackspace Openstack, Inventory Generator',
        epilog='Inventory Generator Licensed "Apache 2.0"')

    parser.add_argument(
        '-f',
        '--file',
        help='Inventory file. Default: [ %(default)s ]',
        required=False,
        default='openstack_inventory.json'
    )

    parser.add_argument(
        '-s',
        '--snat-pool-address',
        help='LB Main SNAT pool address for [ RPC_SNATPOOL ], for'
             ' multiple snat pool addresses comma seperate the ip'
             ' addresses. By default this IP will be .15 from within your'
             ' containers_cidr as found within inventory.',
        required=False,
        default=None
    )

    parser.add_argument(
        '--ssl-public-ip',
        help='Public IP address for the F5 to use.',
        required=False,
        default=None
    )

    parser.add_argument(
        '--ssl-domain-name',
        help='Name of the domain that will have an ssl cert.',
        required=False,
        default=None
    )

    parser.add_argument(
        '--galera-monitor-user',
        help='Name of the user that will be available for the F5 to pull when'
             ' monitoring Galera.',
        required=False,
        default='openstack'
    )

    parser.add_argument(
        '--print',
        help='Print the script to screen, as well as write it out',
        required=False,
        default=False,
        action='store_true'
    )

    parser.add_argument(
        '-e',
        '--export',
        help='Export the generated F5 configuration script.'
             ' Default: [ %(default)s ]',
        required=False,
        default=os.path.join(
            os.path.expanduser('~/'), 'rpc_f5_config.sh'
        )
    )

    parser.add_argument(
        '-S',
        '--Superman',
        help='Yes, its Superman ... strange visitor from another planet,'
             'who came to Earth with powers and abilities far beyond those '
             'of mortal men! '
             'Superman ... who can change the course of mighty rivers, '
             'bend steel in his bare hands and who, disguised as Clark Kent, '
             'mild-mannered reporter for a great metropolitan newspaper,'
             'fights a never-ending battle for truth, justice, '
             'and the American way!',
        required=False,
        default=False,
        action='store_true'
    )

    return vars(parser.parse_args())


def main():
    """Run the main application."""
    # Parse user args
    user_args = args()

    # Get the contents of the system environment json
    environment_file = file_find(filename=user_args['file'])
    with open(environment_file, 'rb') as f:
        inventory_json = json.loads(f.read())

    commands = []
    nodes = []
    pools = []
    virts = []
    sslvirts = []
    pubvirts = []
    cleanup = []
    addextmon = []

    if user_args['Superman']:
        print "       **************************       "
        print "    .*##*:*####***:::**###*:######*.    "
        print "   *##: .###*            *######:,##*   "
        print " *##:  :####:             *####*.  :##: "
        print "  *##,:########**********:,       :##:  "
        print "   .#########################*,  *#*    "
        print "     *#########################*##:     "
        print "       *##,        ..,,::**#####:       "
        print "        ,##*,*****,        *##*         "
        print "          *#########*########:          "
        print "            *##*:*******###*            "
        print "             .##*.    ,##*              "
        print "               :##*  *##,               "
        print "                 *####:                 "
        print "                   :,                   "
#       Kal-El
#       SUPERMAN
#       JNA

    pool_parts = build_pool_parts(inventory=inventory_json)
    lb_vip_address = inventory_json['all']['vars']['internal_lb_vip_address']

    for key, value in pool_parts.iteritems():
        value['group_name'] = key.upper()
        value['vs_name'] = '%s_VS_%s' % (
            PREFIX_NAME, value['group_name']
        )
        value['pool_name'] = '%s_POOL_%s' % (
            PREFIX_NAME, value['group_name']
        )

        node_data = []
        priority = 100
        for node in value['hosts']:
            node['node_name'] = '%s_NODE_%s' % (PREFIX_NAME, node['hostname'])
            nodes.append(NODES % node)
            if value.get('persist'):
                persist = PERSIST_OPTION
            else:
                persist = str()

            virtual_dict = {
                'port': value['port'],
                'vs_name': value['vs_name'],
                'pool_name': value['pool_name'],
                'internal_lb_vip_address': lb_vip_address,
                'persist': persist,
                'ssl_domain_name': user_args['ssl_domain_name'],
                'ssl_public_ip': user_args['ssl_public_ip'],
            }

            virt = '%s' % VIRTUAL_ENTRIES % virtual_dict
            if virt not in virts:
                virts.append(virt)
            if user_args['ssl_public_ip']:
                if not value.get('backend_ssl'):
                    virtual_dict['ssl_profiles'] = (
                        '/' + PART + '/' + PREFIX_NAME +
                        '_PROF_SSL_%(ssl_domain_name)s { context clientside }'
                    ) % user_args
                else:
                    virtual_dict['ssl_profiles'] = (
                      '/' + PART + '/' + PREFIX_NAME +
                      '_PROF_SSL_SERVER { context serverside } /' + PART +
                      '/' + PREFIX_NAME +
                      '_PROF_SSL_%(ssl_domain_name)s ' +
                      '{ context clientside }') % user_args
                if value.get('make_public'):
                    if value.get('ssl_impossible'):
                        virtual_dict['vs_name'] = '%s_VS_%s' % (
                            'RPC_PUB', value['group_name']
                        )
                        pubvirt = (
                            '%s\n'
                        ) % PUB_NONSSL_VIRTUAL_ENTRIES % virtual_dict
                        if pubvirt not in pubvirts:
                            pubvirts.append(pubvirt)
                    else:
                        virtual_dict['vs_name'] = '%s_VS_%s' % (
                         'RPC_PUB_SSL', value['group_name']
                        )
                        sslvirt = '%s' % PUB_SSL_VIRTUAL_ENTRIES % virtual_dict
                        if sslvirt not in sslvirts:
                            sslvirts.append(sslvirt)
            if value.get('priority') is True:
                node_data.append(
                    '%s:%s %s' % (
                        node['node_name'],
                        value['backend_port'],
                        PRIORITY_ENTRY % {'priority_int': priority}
                    )
                )
                priority -= 5
            else:
                node_data.append(
                    '%s:%s' % (
                        node['node_name'],
                        value['backend_port']
                    )
                )

        value['nodes'] = ' '.join(node_data)
        pool_node = [POOL_NODE['beginning'] % value]
        if value.get('priority') is True:
            pool_node.append(POOL_NODE['priority'])

        pool_node.append(POOL_NODE['end'] % value)
        pools.append('%s' % ' '.join(pool_node))

    script = []
    script.extend(['### CLEAN UP ###'])
    script.extend(['%s' % i % user_args for i in CLEANUP])
    script.extend(['### UPDATE MONITORS ###'])
    script.extend(['%s' % i % user_args for i in MONITORS])
    script.extend(['%s' % i for i in commands])
    script.extend(['### UPDATE NODES ###'])
    script.extend(['%s' % i % user_args for i in nodes])
    script.extend(['\n### ADD PROPER MONITORS ###'])
    script.extend(['%s' % i % user_args for i in ADDEXTMON])
    script.extend(['### CREATE POOLS ###'])
    script.extend(pools)
    script.extend(['\n### UPDATE VIRTUAL SERVERS ###'])
    script.extend(virts)
    script.extend(['\n### UPDATE PUBLIC SSL OFFLOADED VIRTUAL SERVERS ###'])
    script.extend(sslvirts)
    script.extend(['\n### UPDATE PUBLIC SSL PASS-THROUGH VIRTUAL SERVERS ###'])
    script.extend(pubvirts)
    script.extend(['### END COMMANDS ###'])
    script.extend(['%s' % i for i in END_COMMANDS])
    script.extend(['\n### BEANS BEANS BEANS ###\n'])

    if user_args['print']:
        for i in script:
            print(i)

    with open(user_args['export'], 'w+') as f:
        f.writelines("\n".join(script))


if __name__ == "__main__":
    main()
