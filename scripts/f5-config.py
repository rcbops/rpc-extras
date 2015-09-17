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
import argparse
import json
import os

import netaddr


PART = 'RPC'
PREFIX_NAME = 'RPC'

SNAT_POOL = (
    '### CREATE SNATPOOL ###\n'
    'create ltm snatpool /' + PART + '/' + PREFIX_NAME + '_SNATPOOL { members replace-all-with {'
    ' %(snat_pool_addresses)s } }'
)

#Persistance Profile:
PERSISTANCE = [
    r'create ltm persistence source-addr /' + PART + '/' + PREFIX_NAME + '_PROF_PERSIST_IP {'
    r' app-service none defaults-from /Common/source_addr'
    r' match-across-services enabled timeout 3600 }',
    r'create ltm persistence cookie /' + PART + '/' + PREFIX_NAME + '_PROF_PERSIST_COOKIE {'
    r' app-service none cookie-name RPC-COOKIE defaults-from /Common/cookie }''\n'
]

MONITORS = [
    r'create ltm monitor mysql /' + PART + '/' + PREFIX_NAME + '_MON_GALERA { count 1 database'
    r' information_schema debug no defaults-from mysql destination *:*'
    r' interval 3 recv big5_chinese_ci recv-column 2 recv-row 0 send "select'
    r' * from CHARACTER_SETS;" time-until-up 0 timeout 10 username monitoring }',
    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME + '_MON_HTTP_KEYSTONE_ADMIN { defaults-from'
    r' http destination *:35357 recv "200 OK" send "HEAD /v3 HTTP/1.1\r\nHost:'
    r' rpc\r\n\r\n" }',
    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME + '_MON_HTTP_NOVA_API_METADATA {'
    r' defaults-from http destination *:8775 recv "200 OK" send "HEAD /'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }',
    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME + '_MON_HTTP_HORIZON { defaults-from http'
    r' destination *:80 recv "302 Found" send "HEAD / HTTP/1.1\r\nHost:'
    r' rpc\r\n\r\n" }',
    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME + '_MON_HTTP_NOVA_SPICE_CONSOLE {'
    r' defaults-from http destination *:6082 recv "200 OK" send "HEAD /'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }',
    r'create ltm monitor https /' + PART + '/' + PREFIX_NAME + '_MON_HTTPS_HORIZON_SSL { defaults-from'
    r' https destination *:443 recv "302 FOUND" send "HEAD / HTTP/1.1\r\nHost:'
    r' rpc\r\n\r\n" }',
    r'create ltm monitor https /' + PART + '/' + PREFIX_NAME + '_MON_HTTPS_NOVA_SPICE_CONSOLE {'
    r' defaults-from https destination *:6082 recv "200 OK" send "HEAD /'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_NOVA_API_EC2 { defaults-from tcp'
    r' destination *:8773 }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_HEAT_API_CFN { defaults-from tcp'
    r' destination *:8000 }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_HEAT_API_CLOUDWATCH {'
    r' defaults-from tcp destination *:8003 }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_KIBANA { defaults-from tcp'
    r' destination *:80 }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_KIBANA_SSL { defaults-from tcp'
    r' destination *:8443 }',
    r'create ltm monitor tcp /' + PART + '/' + PREFIX_NAME + '_MON_TCP_ELASTICSEARCH { defaults-from'
    r' tcp destination *:9200 }',
    r'create ltm monitor http /' + PART + '/' + PREFIX_NAME + '_MON_HTTP_REPO {'
    r' defaults-from http destination *:8181 recv "200 OK" send "HEAD /'
    r' HTTP/1.1\r\nHost: rpc\r\n\r\n" }'
    '\n'
]

NODES = (
    'create ltm node /' + PART + '/%(node_name)s { address %(container_address)s }'
)

PRIORITY_ENTRY = '{ priority-group %(priority_int)s }'

POOL_NODE = {
    'beginning': 'create ltm pool /' + PART + '/%(pool_name)s {'
                 ' load-balancing-mode fastest-node members replace-all-with'
                 ' { %(nodes)s }',
    'priority': 'min-active-members 1',
    'end': 'monitor %(mon_type)s }'
}

VIRTUAL_ENTRIES_PARTS = {
    'command': 'create ltm virtual /' + PART + '/%(vs_name)s',
}

PERSIST_OPTION = 'persist replace-all-with { /' + PART + '/' + PREFIX_NAME + '_PROF_PERSIST_IP }'


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
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME + '_SNATPOOL type snat }'
    ' }'
)

PUB_SSL_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/%(vs_name)s {'
    ' destination %(ssl_public_ip)s:%(port)s ip-protocol tcp'
    ' pool /' + PART + '/%(pool_name)s'
    r' profiles replace-all-with { /Common/tcp { } %(ssl_profiles)s }'
    ' %(persist)s'
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME + '_SNATPOOL type snat }'
    ' }'
)

PUB_NONSSL_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/%(vs_name)s {'
    ' destination %(ssl_public_ip)s:%(port)s ip-protocol tcp'
    ' pool /' + PART + '/%(pool_name)s'
    r' profiles replace-all-with { /Common/fastL4 { } }'
    ' %(persist)s'
    ' source-address-translation { pool /' + PART + '/' + PREFIX_NAME + '_SNATPOOL type snat }'
    ' }'
)

SEC_HOSTNET_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/' + PREFIX_NAME + '_LIMIT_ACCESS_TO_HOST_NET {'
    ' destination %(sec_host_net)s:0 ip-forward mask %(sec_host_netmask)s'
    r' profiles replace-all-with { /Common/fastL4 { } }'
    'rules { /' + PART + '/' + PREFIX_NAME + '_DISCARD_ALL }'
    ' translate-address disabled translate-port disabled vlans'
    ' replace-all-with { /Common/%(sec_public_vlan_name)s }'
    ' }'
)

SEC_CONTAINER_VIRTUAL_ENTRIES = (
    'create ltm virtual /' + PART + '/' + PREFIX_NAME + '_LIMIT_ACCESS_TO_CONTAINER_NET {'
    ' connection-limit 1 destination %(sec_container_net)s:0 ip-forward mask'
    ' %(sec_container_netmask)s profiles replace-all-with'
    ' { /Common/fastL4 { } } rules { /' + PART + '/' + PREFIX_NAME + '_DISCARD_ALL'
    ' } translate-address disabled translate-port disabled'
    ' }'
)

# This is a dict of all groups and their respected values / requirements
POOL_PARTS = {
    'galera': {
        'port': 3306,
        'backend_port': 3306,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_GALERA',
        'priority': True,
        'group': 'galera',
        'hosts': []
    },
    'glance_api': {
        'port': 9292,
        'backend_port': 9292,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'glance_api',
        'make_public': True,
        'hosts': []
    },
    'glance_registry': {
        'port': 9191,
        'backend_port': 9191,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'glance_registry',
        'hosts': []
    },
    'heat_api_cfn': {
        'port': 8000,
        'backend_port': 8000,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_HEAT_API_CFN',
        'group': 'heat_api_cfn',
        'make_public': True,
        'hosts': []
    },
    'heat_api_cloudwatch': {
        'port': 8003,
        'backend_port': 8003,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_HEAT_API_CLOUDWATCH',
        'group': 'heat_api_cloudwatch',
        'make_public': True,
        'hosts': []
    },
    'heat_api': {
        'port': 8004,
        'backend_port': 8004,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'heat_api',
        'make_public': True,
        'hosts': []
    },
    'keystone_admin': {
        'port': 35357,
        'backend_port': 35357,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_KEYSTONE_ADMIN',
        'group': 'keystone',
        'hosts': []
    },
    'keystone_service': {
        'port': 5000,
        'backend_port': 5000,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'keystone',
        'make_public': True,
        'hosts': []
    },
    'neutron_server': {
        'port': 9696,
        'backend_port': 9696,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'neutron_server',
        'make_public': True,
        'hosts': []
    },
    'nova_api_ec2': {
        'port': 8773,
        'backend_port': 8773,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_NOVA_API_EC2',
        'group': 'nova_api_os_compute',
        'make_public': True,
        'hosts': []
    },
    'nova_api_metadata': {
        'port': 8775,
        'backend_port': 8775,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_NOVA_API_METADATA',
        'group': 'nova_api_metadata',
        'hosts': []
    },
    'nova_api_os_compute': {
        'port': 8774,
        'backend_port': 8774,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'nova_api_os_compute',
        'make_public': True,
        'hosts': []
    },
    'nova_spice_console': {
        'port': 6082,
        'backend_port': 6082,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_NOVA_SPICE_CONSOLE',
        'group': 'nova_console',
        'hosts': [],
        'ssl_impossible': True,
        'make_public': True,
        'persist': True
    },
    'cinder_api': {
        'port': 8776,
        'backend_port': 8776,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'cinder_api',
        'make_public': True,
        'hosts': []
    },
    'horizon': {
        'port': 80,
        'backend_port': 80,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTP_HORIZON',
        'group': 'horizon',
        'hosts': [],
    },
    'horizon_ssl': {
        'port': 443,
        'backend_port': 443,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_HTTPS_HORIZON_SSL',
        'group': 'horizon',
        'hosts': [],
        'make_public': True,
        'persist': True,
        'backend_ssl': True
    },
    'elasticsearch': {
        'port': 9200,
        'backend_port': 9200,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_ELASTICSEARCH',
        'group': 'elasticsearch',
        'hosts': []
    },
    'kibana': {
        'port': 8888,
        'backend_port': 80,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_KIBANA',
        'group': 'kibana',
        'priority': True,
        'hosts': []
    },
    'kibana_ssl': {
        'port': 8443,
        'backend_port': 8443,
        'mon_type': '/' + PART + '/' + PREFIX_NAME + '_MON_TCP_KIBANA_SSL',
        'group': 'kibana',
        'priority': True,
        'hosts': [],
        'make_public': True,
        'persist': True,
        'backend_ssl': True
    },
    'swift': {
        'port': 8080,
        'backend_port': 8080,
        'mon_type': '/' + PART + '/RPC-MON-EXT-ENDPOINT',
        'group': 'swift_proxy',
        'make_public': True,
        'hosts': []
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
        '--limit-source',
        help='Limit available connections to the source IP for all source'
             ' limited entries.',
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
        '--sec-host-network',
        help='Security host network address and netmask.'
             ' EXAMPLE: "192.168.1.1:255.255.255.0"',
        required=False,
        default=None
    )

    parser.add_argument(
        '--sec-container-network',
        help='Security container network address and netmask.'
             ' EXAMPLE: "192.168.1.1:255.255.255.0"',
        required=False,
        default=None
    )

    parser.add_argument(
        '--sec-public-vlan-name',
        help='Security container network address and netmask.'
             ' EXAMPLE: "192.168.1.1:255.255.255.0"',
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
             'who came to Earth with powers and abilities far beyond those of mortal men!  '
             'Superman ... who can change the course of mighty rivers, bend steel in his bare hands,'
             'and who, disguised as Clark Kent, mild-mannered reporter for a great metropolitan newspaper,'
             'fights a never-ending battle for truth, justice, and the American way!',
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

    commands.extend([
        '### CREATE SECURITY iRULE ###',
        'create ltm rule /' + PART + '/' + PREFIX_NAME + '_DISCARD_ALL',
        '   --> Copy and Paste the following between pre-included curly brackets <--',
        'when CLIENT_ACCEPTED { discard }\n',
        '### CREATE EXTERNAL MONITOR ###',
        '   --> Upload External monitor file to disk <--',
        '       run util bash',
        '       cd /config/monitors/',
        '       vi RPC-MON-EXT-ENDPOINT.monitor',
        '   --> Copy and Paste the External monitor into vi <--',
        '       create sys file external-monitor /' + PART + '/RPC-MON-EXT-ENDPOINT { source-path file:///config/monitors/RPC-MON-EXT-ENDPOINT.monitor }',
        '       save sys config',
        '       create ltm monitor external /' + PART + '/RPC-MON-EXT-ENDPOINT { interval 20 timeout 61 run /' + PART + '/RPC-MON-EXT-ENDPOINT }\n'
    ])
    if user_args['ssl_domain_name']:
        commands.extend([
            '### UPLOAD SSL CERT KEY PAIR  ###',
            'cd /RPC',
            'install sys crypto cert /' + PART + '/%(ssl_domain_name)s.crt from-editor'
            % user_args,
            '   --> Copy and Paste provided domain cert for public api endpoint <--',
            'install sys crypto key /' + PART + '/%(ssl_domain_name)s.key from-editor'
            % user_args,
            '   --> Copy and Paste provided domain key for public api endpoint <--',
            'cd /Common\n',
            '### CREATE SSL PROFILES ###',
            ('create ltm profile client-ssl'
            ' /' + PART + '/' + PREFIX_NAME + '_PROF_SSL_%(ssl_domain_name)s'
            ' { cert /' + PART + '/%(ssl_domain_name)s.crt key'
            ' /' + PART + '/%(ssl_domain_name)s.key defaults-from clientssl }')
            % user_args,
            'create ltm profile server-ssl /' + PART + '/' + PREFIX_NAME + '_PROF_SSL_SERVER { defaults-from /Common/serverssl }\n'
            % user_args,
        ])
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
##########################################
            virt = '%s' % VIRTUAL_ENTRIES % virtual_dict
            if virt not in virts:
                virts.append(virt)
            if user_args['ssl_public_ip']:
                if not value.get('backend_ssl'):
                    virtual_dict['ssl_profiles'] = (
                        '/' + PART + '/' + PREFIX_NAME + '_PROF_SSL_%(ssl_domain_name)s { context clientside }'
                    ) % user_args
                else:
                    virtual_dict['ssl_profiles'] = '/' + PART + '/' + PREFIX_NAME + '_PROF_SSL_SERVER { context serverside } /' + PART + '/' + PREFIX_NAME + '_PROF_SSL_%(ssl_domain_name)s { context clientside }'% user_args
                if value.get('make_public'):
                    if value.get ('ssl_impossible'):
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
##########################################

        value['nodes'] = ' '.join(node_data)
        pool_node = [POOL_NODE['beginning'] % value]
        if value.get('priority') is True:
            pool_node.append(POOL_NODE['priority'])

        pool_node.append(POOL_NODE['end'] % value)
        pools.append('%s' % ' '.join(pool_node))

    # define the SNAT pool address
    snat_pool_adds = user_args.get('snat_pool_address')
    if snat_pool_adds is None:
        container_cidr = inventory_json['all']['vars']['container_cidr']
        network = netaddr.IPNetwork(container_cidr)
        snat_pool_adds = str(network[15])

    snat_pool_addresses = ' '.join(snat_pool_adds.split(','))
    snat_pool = '%s\n' % SNAT_POOL % {
        'snat_pool_addresses': snat_pool_addresses
    }

    script = [
        '#!/usr/bin/bash\n',
        r'### CREATE RPC PARTITION ###',
        'create auth partition %s\n' % PART,
        r'### SET DISPLAY PORT NUMBERS ###',
        'modify cli global-settings service number\n',
        snat_pool
    ]

    script.extend(['### CREATE MONITORS ###'])
    script.extend(['%s' % i % user_args for i in MONITORS])
    script.extend(['%s' % i for i in commands])
    script.extend(['### CREATE PERSISTENCE PROFILES ###'])
    script.extend(['%s' % i % user_args for i in PERSISTANCE])
    script.extend(['### CREATE NODES ###'])
    script.extend(['%s' % i % user_args for i in nodes])
    script.extend(['\n### CREATE POOLS ###'])
    script.extend(pools)
    script.extend(['\n### CREATE VIRTUAL SERVERS ###'])
    script.extend(virts)
    script.extend(['\n### CREATE PUBLIC SSL OFFLOADED VIRTUAL SERVERS ###'])
    script.extend(sslvirts)
    script.extend(['\n### CREATE PUBLIC SSL PASS-THROUGH VIRTUAL SERVERS ###'])
    script.extend(pubvirts)

    if user_args['sec_host_network']:
        hostnet, netmask = user_args['sec_host_network'].split(':')
        if not user_args['sec_public_vlan_name']:
            raise SystemExit('Please set the [ --sec-public-vlan-name ] value')
        script.append(
            SEC_HOSTNET_VIRTUAL_ENTRIES % {
                'sec_host_net': hostnet,
                'sec_host_netmask': netmask,
                'sec_public_vlan_name': user_args['sec_public_vlan_name']
            }
        )

    if user_args['sec_container_network']:
        hostnet, netmask = user_args['sec_container_network'].split(':')
        script.append(
            SEC_CONTAINER_VIRTUAL_ENTRIES % {
                'sec_container_net': hostnet,
                'sec_container_netmask': netmask
            }
        )

    script.extend(['%s\n' % i for i in END_COMMANDS])

    if user_args['print']:
        for i in script:
            print(i)

    with open(user_args['export'], 'w+') as f:
        f.writelines("\n".join(script))


if __name__ == "__main__":
    main()
