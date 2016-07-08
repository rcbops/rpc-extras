#!/usr/bin/env bash

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

## Shell Opts ----------------------------------------------------------------
set -euo pipefail

## Main ----------------------------------------------------------------------
if [[ -z "$VIRTUAL_ENV" ]] ; then
    echo "WARNING: Not running hacking inside a virtual environment."
fi

echo "Running scripts syntax check"

# Run bashate check for all bash scripts
# Ignores the following rules based on OSA:
#     E003: Indent not multiple of 4 (we prefer to use multiples of 2)
#     E006: Line longer than 79 columns (as many scripts use jinja
#           templating, this is very difficult)
#     E040: Syntax error determined using `bash -n` (as many scripts
#           use jinja templating, this will often fail and the syntax
#           error will be discovered in execution anyway)

bashate $(grep -rln '^.!.*\(ba\)\?sh$' *) \
    --verbose --ignore=E003,E006,E040
