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

import json
import optparse
import os
import re
import requests

from maas_common import metric, status_ok, status_err, print_output


def get_elasticsearch_bind_host():
    """Get the bindhost for elasticsearch if we can read the config."""
    config = '/etc/elasticsearch/elasticsearch.yml'
    if not os.path.exists(config):
        return 'localhost'

    with open(config) as fd:
        contents = fd.readlines()
    bind_host_re = re.compile('^network\.bind_host:\s+([0-9\.]+)\s+')
    hosts = filter(bind_host_re.match, contents)
    if not hosts:
        raise SystemExit(False)
    match = bind_host_re.match(hosts[-1])
    return match.groups()[0]

ES_PORT = '9200'
ELASTICSEARCH = None


def json_querystring(query_string, sort=None):
    """Generate the JSON data for a query_string query."""
    query_dict = {'query': {'query_string': query_string}}
    if sort:
        query_dict['sort'] = sort
    return json.dumps(query_dict)


def json_filter(filtered_query):
    """Generate the JSON data for a filtered query."""
    return json.dumps({'query': {'filtered': filtered_query}})


def find_indices():
    """Find indices created by logstash."""
    url = ELASTICSEARCH + '/_search'
    query = json_querystring({'query': '_index like logstash%'},
                             [{'_index': {'order': 'desc'}}])
    json = get_json(url, query)
    return sorted(res['_index'] for res in json['hits']['hits'])


def most_recent_index():
    """Get the most recent index if one indeed exists."""
    indices = find_indices()

    if not indices:
        status_err('There are no elasticsearch indices to search')

    return indices[-1]


def search_url_for(index):
    """Generate the search URL for an index."""
    return ELASTICSEARCH + '/' + index + '/_search'


def get_json(url, data):
    """Wrap calls to requests to handle exceptions."""
    exceptions = (requests.exceptions.HTTPError,
                  requests.exceptions.ConnectionError)
    try:
        r = requests.get(url, data=data)
    except exceptions as e:
        status_err(str(e))

    return r.json()


def get_number_of(loglevel, index):
    """Retrieve the number of logs with level ``loglevel``."""
    url = search_url_for(index)
    data = json_querystring({'query': loglevel,
                             'fields': ['os_level', 'message']})
    json = get_json(url, data)
    return json['hits']['total']


def parse_args():
    parser = optparse.OptionParser(usage='%prog [-h] [-H host] [-P port]')
    parser.add_option('-H', '--host', action='store', dest='host',
                      default=None,
                      help=('Hostname or IP address to use to connect to '
                            'Elasticsearch'))
    parser.add_option('-P', '--port', action='store', dest='port',
                      default=ES_PORT,
                      help='Port to use to connect to Elasticsearch')
    return parser.parse_args()


def configure(options):
    global ELASTICSEARCH
    host = options.host or get_elasticsearch_bind_host()
    port = options.port
    ELASTICSEARCH = 'http://{0}:{1}'.format(host, port)


def main():
    options, _ = parse_args()
    configure(options)

    latest = most_recent_index()
    num_errors = get_number_of('ERROR', latest)
    num_warnings = get_number_of('WARN*', latest)

    status_ok()
    metric('NUMBER_OF_LOG_ERRORS', 'uint32', num_errors)
    metric('NUMBER_OF_LOG_WARNINGS', 'uint32', num_warnings)


if __name__ == '__main__':
    with print_output():
        main()
