#!/usr/bin/env python

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

from maas_common import (status_ok, status_err, metric, metric_bool,
                         get_neutron_client, get_auth_ref, get_endpoint_url_for_service, print_output)
from requests import Session
from requests import exceptions as exc

def check(auth_ref):
    auth_token = auth_ref['token']['id']
    
    # Use internalURL as this is a local plugin
    endpoint = get_endpoint_url_for_service('network', auth_ref['serviceCatalog'], url_type='internalURL')
    
    # TODO set this from args.version to future-proof // version = args.version
    version = 'v2.0'
    
    api_endpoint = '{endpoint}/{version}'.format(endpoint=endpoint,version=version)
    
    # Use get_neutron_client as it can check for stale token and get new one if necessary
    neutron = get_neutron_client(endpoint_url=endpoint)

    s = Session()

    s.headers.update(
        {'Content-type': 'application/json',
         'X-Auth-Token': auth_token})

    try:
        # Check for successful response from API endpoint
        r = s.get('%s/' % api_endpoint, verify=False,
                  timeout=10)
        is_active = r.ok
    except (exc.ConnectionError, exc.HTTPError, exc.Timeout):
        is_active = False
    except Exception as e:
        status_err(str(e))
    else:
        # Gather some metrics to report
        try:
            r = s.get('%s/routers' % (api_endpoint), verify=False, timeout=10)
        except Exception as e:
            status_err(str(e))
        else:
            routers = r.json()['routers']


    status_ok()
    metric_bool('neutron_api_status', is_active)

    for router in routers:
        if(router['external_gateway_info'] == None):
            continue

        router_status = router['status']
        router_name = (router['name']).replace(" ","").lower()
        failed = []

    # If router_status is ACTIVE, perform ping check
        if(router_status == 'ACTIVE'):
            import os, sys, time
        
            # IP address is the WAN interface of the router
            ip_address = router['external_gateway_info']['external_fixed_ips'][0]['ip_address']
        
            rc = os.system('ping -c1 -W3 ' + ip_address + ' > /dev/null')
            if(rc == 0):
		pass
            else:
                failed.append(router_name)

        failed_routers = ', '.join(failed)
        
        if failed:
            return metric('neutron_router_ping', 'string', 'PING FAILURE: ' + failed_routers)
        
        return metric('neutron_router_ping', 'string', 'SUCCESS')


def main():
    auth_ref = get_auth_ref()
    check(auth_ref)


if __name__ == "__main__":
    with print_output():
        main()
