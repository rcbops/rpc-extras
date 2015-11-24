#!/usr/bin/env bash

# This script is for exceuting rackspace monitoring agent plugins without
# needing a connection to MAAS.

# Usage: $0 [ -v ] FILTER_STRING
# -v: print full plugin output even on success
# FILTER_STRING: only config files including this string will be run.

# Example:

#  ./run-maas-plugins.sh rabbit
#  rabbitmq_status--rpc_rabbit_mq_container-5079f706.yaml status okay
#  rabbitmq_status--rpc_rabbit_mq_container-56acfe95.yaml status okay
#  rabbitmq_status--rpc_rabbit_mq_container-58d015b1.yaml status okay

NO_COLOUR="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"

run_plugin(){
  config_file="$1"

  # skip config files that don't define plugin checks
  grep agent.plugin $config_file &>/dev/null ||\
    { echo "Skipping as it doesn't define an agent.plugin check"; continue; }

  # extract plugin filename from config file
  plugin_file="$(awk '/^\s*file\s*:/{print $3}' <$config_file)"

  # skip if no plugin is defined
  [ -z $plugin_file ] &&\
    { echo "Skipping as the 'file' field is empty"; continue; }

  full_plugin_path="/usr/lib/rackspace-monitoring-agent/plugins/$plugin_file"

  # skip if plugin not found
  [ -f $full_plugin_path ] ||\
    { echo "Skipping as plugin $full_plugin_path not found"; continue; }

  # extract plugin args from config file
  plugin_args="$(awk '/args/{gsub(/\s*args\s*:\s*/, ""); print}' <$config_file |tr -d "\",'][")"

  $full_plugin_path $plugin_args

}

if [[ $1 == -v ]]
then
  VERBOSE=true
  shift
else
  VERBOSE=false
fi

for path in /etc/rackspace-monitoring-agent.conf.d/*${1:-}*.yaml
do
  file=$(basename $path)
  # run each plugin, prepending the file name to each line of output, store output in temp file
  run_plugin "$path" 2>&1 |sed "s/^/$file /" >/tmp/maastesting

  if [[ $VERBOSE == true ]]
  then
    cat /tmp/maastesting
  else
    #output status line if pass, otherwise log full output.
    echo -en $GREEN; grep 'status okay' /tmp/maastesting || \
      { echo -en $RED; cat /tmp/maastesting; }
    echo -en $NO_COLOUR
  fi
done
