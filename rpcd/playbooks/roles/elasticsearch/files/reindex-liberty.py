#!/usr/bin/env python

# Copyright 2016, Rackspace US, Inc.
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
from datetime import date
from datetime import timedelta
from elasticsearch import Elasticsearch
import requests
import sys
import time


def _calc_pct(es, parsed_args, stats, master, slave):
    """Calculate the percentage complete of a reindex."""
    master_count = _get_count(stats, master)
    slave_count = _get_count(stats, slave)
    reindex_pct = _percentage(slave_count, master_count)
    out = []
    out.append(master_count)
    out.append(slave_count)
    out.append(reindex_pct)
    return out


def _percentage(numerator, denominator):
    try:
        return (float(numerator) / float(denominator)) * 100
    except ZeroDivisionError:
        return float(0.00)


def _check_index(es, parsed_args, index, stats):
    """Check on the reindexing status of an index."""
    slave_index = _return_slave(index, parsed_args)
    if slave_index in stats['indices']:
        return True
    else:
        return False


def _get_count(stats, index):
    """Return the document count for a given index."""
    try:
        return stats['indices'][index]['primaries']['docs']['count']
    except KeyError:
        return -1


def _index_to_date(index):
    """Converts and index name to a date object."""
    (i_year, i_month, i_day) = index.split('-')[1].split('.')
    return date(int(i_year), int(i_month), int(i_day))


def _return_slave(index, parsed_args):
    """Gives the slave index name."""
    return index + parsed_args.suffix


def get_indices(es, parsed_args, slaves=False):
    """Fetch a list of all of the elasticsearch indices."""
    indices = []

    full_indices = es.indices.get_aliases(request_timeout=30).keys()
    for index in full_indices:
        if 'logstash' in index:
            if parsed_args.suffix in index and slaves:
                if index.replace(parsed_args.suffix, "") in full_indices:
                    indices.append(index)
            elif parsed_args.suffix not in index:
                indices.append(index)

    return indices


def get_stats(es):
    """Fetch the statistics for all of the elasticsearch indices."""
    return es.indices.stats(request_timeout=30)


def reindex(es, es_host, parsed_args):
    """Create -liberty indices and start the reindex process."""
    stats = get_stats(es)
    if not parsed_args.index:
        for index in get_indices(es, parsed_args):
            if not _check_index(es, parsed_args, index, stats):
                reindex_params = 'http://' + es_host + \
                    '/' + index + '/_reindex/' + index + parsed_args.suffix + \
                    '/'
                print("Reindexing: {0} into: {1}".format(index, index +
                                                         parsed_args.suffix))
                if not parsed_args.dry_run:
                    requests.post(reindex_params)
            else:
                print("Skipping: {} reindexing in progress".format(index))

    else:
        reindex_params = 'http://' + es_host + '/' + parsed_args.index + \
            '/_reindex/' + parsed_args.index + parsed_args.suffix
        print("Reindexing Single Index: {0} into: {1}".format(
            parsed_args.index,
            parsed_args.index + parsed_args.suffix))
        if not parsed_args.dry_run:
            requests.post(reindex_params)


def clean_legacy(es, parsed_args):
    """Drops the -liberty indices created by a previous reindex."""
    if parsed_args.dry_run:
        print("Dry run, no operations will be performed")
    for index in get_indices(es, parsed_args, True):
        if parsed_args.suffix in index:
            if not parsed_args.dry_run:
                es.indices.delete(index)
            print ("Deleted: {}".format(index))


def monitor_reindex(es, parsed_args):
    """Monitor the reindexing process."""
    total_count = 0
    done_count = 0
    stats = get_stats(es)
    indices = get_indices(es, parsed_args, True)
    counts = None
    counts = {}
    for index in indices:
        if parsed_args.suffix in index:
            master_name = index.replace(parsed_args.suffix, "")
            counts[master_name] = _calc_pct(es,
                                            parsed_args,
                                            stats,
                                            master_name,
                                            index)

    for master in counts.keys():
        slave_index = master + parsed_args.suffix
        master_count = counts[master][0]
        slave_count = counts[master][1]
        reindex_pct = counts[master][2]
        if parsed_args.verbose:
            print("Master Index: {0:15s} "
                  "Slave Index: {1:15s} "
                  "Master Count: {2:10d} "
                  "Slave Count: {3:10d} "
                  "Percentage Complete: {4:3.2f}%".format(master,
                                                          slave_index,
                                                          master_count,
                                                          slave_count,
                                                          reindex_pct))
        total_count += master_count
        done_count += slave_count
    try:
        pct_done = _percentage(done_count, total_count)
    except ZeroDivisionError:
        pct_done = float(0.00)
    if parsed_args.verbose:
        print("Total Docments: {0:20d} "
              "Reindexed Documents: {1:20d} "
              "Percentage complete: {2:3.2f}%".format(total_count,
                                                      done_count,
                                                      pct_done))
    else:
        print("Percent complete: {0:3.2f}%".format(pct_done))
    if pct_done == 100:
        sys.exit()
    else:
        return False


def drop_legacy(es, parsed_args):
    """Drop the legacy logstash-* indices."""
    stats = get_stats(es)
    for index in get_indices(es, parsed_args):
        if _check_index(es, parsed_args, index, stats):
            print("Dropping Legacy Index: {}".format(index))
            if not parsed_args.dry_run:
                es.indices.delete(index)


def list_indices(es):
    """List all indices."""
    print(es.cat.indices(v=True))


def batch(es, es_host, parsed_args):
    """Batch Processing.

    Batch processing, useful for performing re-indexing of old indices
    prior to the actual upgrade.
    """

    today = date.today()
    one_day = timedelta(days=1)
    yesterday = today - one_day
    indices = get_indices(es, parsed_args)
    stats = get_stats(es)

    if not parsed_args.start:
        d_start = None  # Date object for start date
        p_start = yesterday  # Previous first day for sort
        for index in indices:
            if 'logstash' in index:
                s_date = _index_to_date(index)
                if s_date < p_start:
                    p_start = s_date
        d_start = p_start
    else:
        (s_year, s_month, s_day) = parsed_args.start.split('.')
        d_start = date(int(s_year), int(s_month), int(s_day))
    if not parsed_args.end:
        d_end = yesterday
    else:
        (e_year, e_month, e_day) = parsed_args.end.split('.')
        d_end = date(int(e_year), int(e_month), int(e_day))

    numdays = d_end - d_start + one_day
    date_range = [d_end - timedelta(days=x) for x in range(0, numdays.days)]
    print("Start: {0}\tEnd: {1}\n".format(d_start, d_end))

    for index in indices:
        parsed_args.index = index
        i_date = _index_to_date(index)
        if i_date in date_range:
            if not _check_index(es, parsed_args, index, stats):
                print("Batch Index: {}".format(index))
                reindex(es, es_host, parsed_args)
            else:
                print("Skipping: {} reindexing in progress".format(index))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="localhost", help="Elasticsearch \
                        host to connect to (default: localhost)")
    parser.add_argument("--port", default="9200", help="Elasticsearch \
                        port to connect to (default: 9200)")
    parser.add_argument("--suffix", default="liberty", help="Suffix for \
                        reindexed indices. (default: liberty)")
    parser.add_argument("--clean", action="store_true", help="Clean previous \
                        reindexed indices")
    parser.add_argument("--list", action="store_true", dest="list_indices",
                        help="List all elasticsearch indices")
    parser.add_argument("--reindex", action="store_true", help="Reindex all \
                        legacy indexes")
    parser.add_argument("--index", default=None, help="Used with --reindex \
                        to reindex a specific index.")
    parser.add_argument("--batch", action="store_true", help="Batch \
                        processing of old indices.  Defaults to oldest index \
                        through previous days index.")
    parser.add_argument("--start", help="Start index for batch processing \
                        (YYYY.MM.DD) (default: beginning of indices)")
    parser.add_argument("--end", help="End index for batch processing \
                        (YYYY.MM.DD) (default: the Nth-1 index)")
    parser.add_argument("--monitor", action="store_true", help="Progress of \
                        reindexing")
    parser.add_argument("--continuous", action="store_true", help="Continuous \
                        monitoring")
    parser.add_argument("--delay", default=10, type=int, help="Refresh delay \
                        for continuous monitoring. (default: 10)")
    parser.add_argument("--verbose", action="store_true", help="Verbose \
                        output from monitoring functions")
    parser.add_argument("--drop", action="store_true", help="Drop legacy \
                        indices")
    parser.add_argument("--dry-run", action="store_true", dest="dry_run",
                        help="Prints what will happen for drop, clean and \
                        batch operations")
    args = parser.parse_args()

    # Make sure we have hyphens in the correct places
    if '-' not in list(args.suffix)[0]:
        args.suffix = '-' + args.suffix

    if args.dry_run:
        print("Dry run, no operations will be performed.")

    es_host = args.host + ":" + args.port
    if args.verbose:
        print("Connecting to elasticsearch at {}".format(es_host))
    es = Elasticsearch(es_host)

    if args.clean:
        clean_legacy(es, args)
    if args.batch:
        batch(es, es_host, args)
    if args.list_indices:
        list_indices(es)
    if args.reindex:
        reindex(es, es_host, args)
    if args.monitor:
        monitor_reindex(es, args)
    if args.drop:
        drop_legacy(es, args)
    if args.continuous:
        # TODO(d34dh0r53) I hate this, need to figure out a better way.
        while not monitor_reindex(es, args):
            time.sleep(args.delay)
        return 0

if __name__ == "__main__":
    main()
