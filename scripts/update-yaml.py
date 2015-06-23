#!/usr/bin/env python
import argparse
import errno
import yaml


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('base', help='The path to the yaml file with the base configuration.')
    parser.add_argument('overrides', help='The path to the yaml file with overrides.')
    return parser.parse_args()


def get_config(path):
    try:
        with open(path) as f:
            data = f.read()
    except IOError as e:
        if e.errno == errno.ENOENT:
            data = None
        else:
            raise e

    if data is None:
        return {}
    else:
        # assume config is a dict
        return yaml.safe_load(data)


if __name__ == '__main__':
    args = parse_args()
    base = get_config(args.base)
    overrides = get_config(args.overrides)
    config = dict(base.items() + overrides.items())
    if config:
        with open(args.base, 'w') as f:
            f.write(str(yaml.safe_dump(config, default_flow_style=False)))
