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

import sys

args = sys.argv[1:]

if args == ['-s', 'show server']:
    print('Status Ok')
elif args == ['-s', 'show dimm']:
    print('Status Ok')
elif args == ['ctrl', 'all', 'show', 'config']:
    print('logicaldrive OK)')
elif args == ['ctrl', 'all', 'show', 'status']:
    print('Controller Status OK\nCache Status OK\nBattery/Capacitor Status OK')
else:
    sys.exit('fake_hp_monitoring.py has received the following '
             'unexpected arguments - "%s".' % str(args))
