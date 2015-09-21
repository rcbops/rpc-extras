#!/usr/bin/env python
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
import json
import os
import re
import sys


def load_data(template, directory):
    path = os.path.join(directory, template)
    with open(path) as f:
        data = f.read()
    return json.loads(data)


def compare(reference, new, ignored_keys=None):
    """Compare two dictionaries and return annotated difference.

    Positional arguments:
    reference -- the reference dictionary
    new -- the new dictionary

    Keyword arguments:
    ignored_keys -- keys to ignore in reference and new
    """
    missing_from_new = {}
    different = {}
    modified = {}
    ret = {}
    if ignored_keys is None:
        ignored_keys = set()
    for key1, value1 in reference.viewitems():
        if key1 in ignored_keys:
            try:
                del new[key1]
            except KeyError:
                pass
            continue
        else:
            try:
                value2 = new[key1]
            except KeyError:
                missing_from_new[key1] = value1
            else:
                try:
                    rec_comp = compare(value1, value2,
                                       ignored_keys=ignored_keys)
                    if rec_comp:
                        modified[key1] = rec_comp
                except AttributeError:
                    if value1 != value2:
                        different[key1] = {'reference': value1, 'new': value2}
                del new[key1]
    missing_from_reference = new
    for k, v in {'different': different,
                 'missing_from_reference': missing_from_reference,
                 'missing_from_new': missing_from_new,
                 'modified': modified}.viewitems():
        if v:
            ret[k] = v
    return ret


def load_definitions(definitions, directory=None):
    """Return the reference MaaS definitions data."""
    checks_by_host_type = {}
    for definition in definitions:
        template = (definition.endswith('.yml') and definition[:-4]
                    or definition)
        data = load_data(template, directory)
        for entity_label, entity in data.viewitems():
            if entity_label in checks_by_host_type:
                # combine entities, first pass only update checks.
                checks = checks_by_host_type[entity_label]['checks']
                checks.update(entity['checks'])
            else:
                checks_by_host_type[entity_label] = entity

    return checks_by_host_type


def translate_reference_entities(ref_entities, mappings=None):
    """Transform MaaS reference data for comparison with test deployment.

    Positional arguments:
    ref_entities -- the reference entity data

    Keyword arguments:
    mappings -- describe the relationship between the reference and the test

    To compare the entities being tested with the reference data, the reference
    data must be manipulated so that the hostnames used match those of the
    entities being tested.
    """
    if mappings is None:
        return ref_entities
    checks_by_host_type = {}
    for mapping in mappings:
        test_label, reference_labels = mapping.split(':')
        reference_labels = reference_labels.split(',')
        for label in reference_labels:
            json_blob = json.dumps(ref_entities[label])
            json_blob = re.sub(label, test_label, json_blob)
            entity = json.loads(json_blob)
            if test_label in checks_by_host_type:
                checks = checks_by_host_type[test_label]['checks']
                checks.update(entity['checks'])
            else:
                checks_by_host_type[test_label] = entity
    return checks_by_host_type


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--definitions', nargs='+',
                        help='A list of the definitions to test.')
    parser.add_argument('--directory', default='.')
    parser.add_argument('--test_file')
    parser.add_argument('--mappings', nargs='+',
                        help='Example, "TestNode1:CONTROLLER,LOADBALANCER"')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    reference = load_definitions(args.definitions, directory=args.directory)
    trans_ref = translate_reference_entities(reference, args.mappings)
    new = load_data(args.test_file, args.directory)

    output = compare(trans_ref, new)
    if output:
        sys.exit(json.dumps(output, indent=4, separators=(',', ': '),
                            sort_keys=True))
