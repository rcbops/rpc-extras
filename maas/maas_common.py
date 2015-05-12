#!/usr/bin/env python

# Copyright 2014, Rackspace US, Inc.
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

import contextlib
import datetime
import errno
import json
import logging
import os
import re
import sys
import traceback

AUTH_DETAILS = {'OS_USERNAME': None,
                'OS_PASSWORD': None,
                'OS_TENANT_NAME': None,
                'OS_AUTH_URL': None}

OPENRC = '/root/openrc-maas'
TOKEN_FILE = '/root/.auth_ref.json'


try:
    from cinderclient.client import Client as c_client
    from cinderclient import exceptions as c_exc

except ImportError:
    def get_cinder_client(*args, **kwargs):
        status_err('Cannot import cinderclient')
else:

    def get_cinder_client(previous_tries=0):
        if previous_tries > 3:
            return None
        # right now, cinderclient does not accept a previously derived token
        # or endpoint url. So we have to pass it creds and let it do it's own
        # auth each time it's called.
        # NOTE: (mancdaz) update when https://review.openstack.org/#/c/74602/
        # lands

        auth_details = get_auth_details()
        cinder = c_client('2',
                          auth_details['OS_USERNAME'],
                          auth_details['OS_PASSWORD'],
                          auth_details['OS_TENANT_NAME'],
                          auth_details['OS_AUTH_URL'])

        try:
            # Do something just to ensure we actually have auth'd ok
            volumes = cinder.volumes.list()
            # Exceptions are only thrown when we iterate over volumes
            [i.id for i in volumes]
        except (c_exc.Unauthorized, c_exc.AuthorizationFailure) as e:
            cinder = get_cinder_client(previous_tries + 1)
        except Exception as e:
            status_err(str(e))

        return cinder

try:
    from glanceclient import Client as g_client
    from glanceclient import exc as g_exc
except ImportError:
    def get_glance_client(*args, **kwargs):
        status_err('Cannot import glanceclient')
else:
    def get_glance_client(token=None, endpoint=None, previous_tries=0):
        if previous_tries > 3:
            return None

        # first try to use auth details from auth_ref so we
        # don't need to auth with keystone every time
        auth_ref = get_auth_ref()

        if not token:
            token = auth_ref['token']['id']
        if not endpoint:
            endpoint = get_endpoint_url_for_service(
                'image',
                auth_ref['serviceCatalog'])

        glance = g_client('1', endpoint=endpoint, token=token)

        try:
            # We don't want to be pulling massive lists of images every time we
            # run
            image = glance.images.list(limit=1)
            # Exceptions are only thrown when we iterate over image
            [i.id for i in image]
        except g_exc.HTTPUnauthorized:
            auth_ref = force_reauth()
            token = auth_ref['token']['id']

            glance = get_glance_client(token, endpoint, previous_tries + 1)
        # we only want to pass HTTPException back to the calling poller
        # since this encapsulates all of our actual API failures. Other
        # exceptions will be treated as script/environmental issues and
        # sent to status_err
        except g_exc.HTTPException:
            raise
        except Exception as e:
            status_err(str(e))

        return glance

try:
    from novaclient.client import Client as nova_client
    from novaclient.client import exceptions as nova_exc
except ImportError:
    def get_nova_client(*args, **kwargs):
        status_err('Cannot import novaclient')
else:
    def get_nova_client(auth_token=None, bypass_url=None, previous_tries=0):
        if previous_tries > 3:
            return None

        # first try to use auth details from auth_ref so we
        # don't need to auth with keystone every time
        auth_ref = get_auth_ref()

        if not auth_token:
            auth_token = auth_ref['token']['id']
        if not bypass_url:
            bypass_url = get_endpoint_url_for_service(
                'compute',
                auth_ref['serviceCatalog'])

        nova = nova_client('3', auth_token=auth_token, bypass_url=bypass_url)

        try:
            flavors = nova.flavors.list()
            # Exceptions are only thrown when we try and do something
            [flavor.id for flavor in flavors]

        # except (nova_exc.Unauthorized, nova_exc.AuthorizationFailure) as e:
        # NOTE(mancdaz)nova doesn't properly pass back unauth errors, but
        # in fact tries to re-auth, all by itself. But we didn't pass it
        # an auth_url, so it bombs out horribly with an
        # Attribute error. This is a bug, to be filed...

        except AttributeError:
            auth_ref = force_reauth()
            auth_token = auth_ref['token']['id']

            nova = get_nova_client(auth_token, bypass_url, previous_tries + 1)

        # we only want to pass ClientException back to the calling poller
        # since this encapsulates all of our actual API failures. Other
        # exceptions will be treated as script/environmental issues and
        # sent to status_err
        except nova_exc.ClientException:
            raise
        except Exception as e:
            status_err(str(e))

        return nova

try:
    from keystoneclient.v2_0 import client as k_client
    from keystoneclient.openstack.common.apiclient import exceptions as k_exc
except ImportError:
    def keystone_auth(*args, **kwargs):
        status_err('Cannot import keystoneclient')

    def get_keystone_client(*args, **kwargs):
        status_err('Cannot import keystoneclient')
else:
    def keystone_auth(auth_details):
        try:
            tenant_name = auth_details['OS_TENANT_NAME']
            keystone = k_client.Client(username=auth_details['OS_USERNAME'],
                                       password=auth_details['OS_PASSWORD'],
                                       tenant_name=tenant_name,
                                       auth_url=auth_details['OS_AUTH_URL'])
        except Exception as e:
            status_err(str(e))

        try:
            with open(TOKEN_FILE, 'w') as token_file:
                json.dump(keystone.auth_ref, token_file)
        except IOError:
            # if we can't write the file we go on
            pass

        return keystone.auth_ref

    def get_keystone_client(auth_ref=None, endpoint=None, previous_tries=0):
        if previous_tries > 3:
            return None

        # first try to use auth details from auth_ref so we
        # don't need to auth with keystone every time
        if not auth_ref:
            auth_ref = get_auth_ref()
        if not endpoint:
            endpoint = get_endpoint_url_for_service('identity',
                                                    auth_ref['serviceCatalog'],
                                                    'adminURL')

        keystone = k_client.Client(auth_ref=auth_ref, endpoint=endpoint)

        try:
            # This should be a rather light-weight call that validates we're
            # actually connected/authenticated.
            keystone.services.list()
        except (k_exc.AuthorizationFailure, k_exc.Unauthorized):
            # Force an update of auth_ref
            auth_ref = force_reauth()
            keystone = get_keystone_client(auth_ref,
                                           endpoint,
                                           previous_tries + 1)
        except (k_exc.HttpServerError, k_exc.ClientException):
            raise
        except Exception as e:
            status_err(str(e))

        return keystone


try:
    from neutronclient.neutron import client as n_client
    from neutronclient.common import exceptions as n_exc
except ImportError:
    def get_neutron_client(*args, **kwargs):
        status_err('Cannot import neutronclient')
else:
    def get_neutron_client(token=None, endpoint_url=None, previous_tries=0):
        if previous_tries > 3:
            return None

        # first try to use auth details from auth_ref so we
        # don't need to auth with keystone every time
        auth_ref = get_auth_ref()

        if not token:
            token = auth_ref['token']['id']
        if not endpoint_url:
            endpoint_url = get_endpoint_url_for_service(
                'network',
                auth_ref['serviceCatalog'])

        neutron = n_client.Client('2.0',
                                  token=token,
                                  endpoint_url=endpoint_url)

        try:
            # some arbitrary command that should always have at least 1 result
            agents = neutron.list_agents()
            # iterate the list to ensure we actually have something
            [i['id'] for i in agents['agents']]

        # if we have provided a bum token, neutron wants to try and reauth
        # itself but it can't as we didn't provide it an auth_url and all that
        # jazz. Since we want to auth again ourselves (so we can update our
        # local token) we'll just catch the exception it throws and move on
        except n_exc.NoAuthURLProvided:
            auth_ref = force_reauth()
            token = auth_ref['token']['id']

            neutron = get_neutron_client(token, endpoint_url,
                                         previous_tries + 1)

        # we only want to pass NeutronClientException back to the caller
        # since this encapsulates all of our actual API failures. Other
        # exceptions will be treated as script/environmental issues and
        # sent to status_err
        except n_exc.NeutronClientException as e:
            raise
        except Exception as e:
            status_err(str(e))

        return neutron


try:
    from heatclient import client as heat_client
    from heatclient import exc as h_exc
except ImportError:
    def get_heat_client(*args, **kwargs):
        status_err('Cannot import heatclient')
else:
    def get_heat_client(token=None, endpoint=None, previous_tries=0):
        if previous_tries > 3:
            return None

        # first try to use auth details from auth_ref so we
        # don't need to auth with keystone every time
        auth_ref = get_auth_ref()

        if not token:
            token = auth_ref['token']['id']
        if not endpoint:
            endpoint = get_endpoint_url_for_service(
                'orchestration',
                auth_ref['serviceCatalog'])

        heat = heat_client.Client('1', endpoint=endpoint, token=token)
        try:
            heat.build_info.build_info()
        except h_exc.HTTPUnauthorized:
            auth_ref = force_reauth()
            token = auth_ref['token']['id']
            heat = get_heat_client(token, endpoint, previous_tries + 1)
        except h_exc.HTTPException:
            raise
        except Exception as e:
            status_err(str(e))

        return heat


class MaaSException(Exception):
    """Base MaaS plugin exception."""


def is_token_expired(token):
    expires = datetime.datetime.strptime(token['expires'],
                                         '%Y-%m-%dT%H:%M:%SZ')
    return datetime.datetime.now() >= expires


def get_auth_ref():
    auth_details = get_auth_details()
    auth_ref = get_auth_from_file()
    if auth_ref is None:
        auth_ref = keystone_auth(auth_details)

    if is_token_expired(auth_ref['token']):
        auth_ref = keystone_auth(auth_details)

    return auth_ref


def get_auth_from_file():
    try:
        with open(TOKEN_FILE) as token_file:
            auth_ref = json.load(token_file)

        return auth_ref
    except IOError as e:
        if e.errno == errno.ENOENT:
            return None
        status_err(e)


def get_auth_details(openrc_file=OPENRC):
    auth_details = AUTH_DETAILS
    pattern = re.compile(
        '^(?:export\s)?(?P<key>\w+)(?:\s+)?=(?:\s+)?(?P<value>.*)$'
    )

    try:
        with open(openrc_file) as openrc:
            for line in openrc:
                match = pattern.match(line)
                if match is None:
                    continue
                k = match.group('key')
                v = match.group('value')
                if k in auth_details and auth_details[k] is None:
                    auth_details[k] = v
    except IOError as e:
        if e.errno != errno.ENOENT:
            status_err(e)
        # no openrc file, so we try the environment
        for key in auth_details.keys():
            auth_details[key] = os.environ.get(key)

    for key in auth_details.keys():
        if auth_details[key] is None:
            status_err('%s not set' % key)

    return auth_details


def get_endpoint_url_for_service(service_type, service_catalog,
                                 url_type='publicURL'):
    for i in service_catalog:
        if i['type'] == service_type:
            return i['endpoints'][0][url_type]


def force_reauth():
    auth_details = get_auth_details()
    return keystone_auth(auth_details)


STATUS = ''


def status(status, message, force_print=False):
    global STATUS
    if status in ('ok', 'warn', 'err'):
        raise ValueError('The status "%s" is not allowed because it creates a '
                         'metric called legacy_state' % status)
    status_line = 'status %s' % status
    if message is not None:
        status_line = ' '.join((status_line, str(message)))
    status_line = status_line.replace('\n', '\\n')
    STATUS = status_line
    if force_print:
        print STATUS


def status_err(message=None, force_print=False, exception=None):
    if exception:
        # a status message cannot exceed 256 characters
        # 'error ' plus up to 250 from the end of the exception
        message = message[-250:]
    status('error', message, force_print=force_print)
    if exception:
        raise exception
    sys.exit(1)


def status_ok(message=None, force_print=False):
    status('okay', message, force_print=force_print)


METRICS = []


def metric(name, metric_type, value, unit=None):
    global METRICS
    if len(METRICS) > 29:
        status_err('Maximum of 30 metrics per check')
    metric_line = 'metric %s %s %s' % (name, metric_type, value)
    if unit is not None:
        metric_line = ' '.join((metric_line, unit))
    metric_line = metric_line.replace('\n', '\\n')
    METRICS.append(metric_line)


def metric_bool(name, success):
    value = success and 1 or 0
    metric(name, 'uint32', value)


logging.basicConfig(filename='/var/log/maas_plugins.log',
                    format='%(asctime)s %(levelname)s: %(message)s')


@contextlib.contextmanager
def print_output():
    try:
        yield
    except SystemExit as e:
        if STATUS:
            print STATUS
        raise
    except Exception as e:
        logging.exception('The plugin %s has failed with an unhandled '
                          'exception', sys.argv[0])
        status_err(traceback.format_exc(), force_print=True, exception=e)
    else:
        if STATUS:
            print STATUS
        for metric in METRICS:
            print metric
