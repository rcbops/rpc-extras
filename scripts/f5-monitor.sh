#!/usr/bin/env bash
# F5 External monitor script for Kilo deployments

# Copy stdout to fd 3 and discard stdout/stderr 
exec 3>&1 &> /dev/null
#/var/log/f5-monitor.log - replace null with this file to enable logging when executing the script

# Auth connection
auth_proto="http"
auth_ip="INSERT-IP-HERE"
    #Internal IP address of f5 VIP
auth_port="5000"
auth_url="$auth_proto://$auth_ip:$auth_port/v2.0/tokens"

# Auth args pulled from source file
tenant="admin"
user="admin"
pass="INSERTPWHERE"
tenant_id="INSERTIDHERE"

# Save token to file
save_token() {
    echo "$token" > /var/tmp/keystone-token
}

# Get new token
new_token() {
    # Curl new token from keystone from user/pass for tenant
    IFS=$'\n' read -rd '' -a resp < <(curl -sk $auth_url -X POST -H "Accept: application/json" -H "Content-Type: application/json" -H "User-Agent: f5-ltm" -d @- -w "\n%{http_code}" <<EOF
{
    "auth": {
        "tenantName": "$tenant",
        "passwordCredentials": {
            "username": "$user",
            "password": "$pass"
        }
    }
}
EOF
    )

    # Exit if status is 401 (invalid username/pass)
    if [[ "${resp[@]:(-1)}" == "401" ]]
    then
        echo "Exiting after failure to get a valid token: Check user/pass."
        printf "%s\n" "${resp[@]}"
        exit -1
    fi

    # Set token variable
    token=$(sed -nr '/\{"access": \{"token": \{"issued_at": "([-0-9TZ.:]*)", "expires": "([-0-9TZ.:]*)", "id": "([-0-9a-zA-Z_%]*)", .*?$/ s//\3/p' <<< "${resp[@]}")

    # Might need to parse tenant ID
    #tenant=...

    # Mark as new token
    token_new=1

    # Save to file
    save_token
}

# Read token from file or get new one
get_token() {
    # If file exists
    if [[ -f /var/tmp/keystone-token ]]
    then
        # Read into token variable
        read -r token < /var/tmp/keystone-token
    else
        # Get new one
        new_token
      fi
  }

  do_check() {
      # Check connection
      check_proto="$auth_proto"
      check_ip=$1
      check_port=$2
      expected_statuses="200"

      # Build check url by port
      case $check_port in
          5000)
              #Keystone
              check_url="$check_proto://$check_ip:$check_port/v2.0/"
              ;;
          8776)
              #Cinder
              check_url="$check_proto://$check_ip:$check_port/v2/"
              ;;
          9292)
              #Glance API
              check_url="$check_proto://$check_ip:$check_port/v1/"
              ;;
          9191)
              #Glance Registry
              check_url="$check_proto://$check_ip:$check_port/"
              ;;
          9696)
              #Neutron Server
              check_url="$check_proto://$check_ip:$check_port/v2.0/"
              ;;
          8774)
              #Nova API Compute
              check_url="$check_proto://$check_ip:$check_port/v3/"
              ;;
          8004)
              #Heat API
              check_url="$check_proto://$check_ip:$check_port/v1/$tenant_id/stacks?"
              ;;
          8080)
              #Swift
              check_url="$check_proto://$check_ip:$check_port/v1/AUTH_$tenant_id"
              expected_statuses="200 204"
              ;;
          *)
              # Guard
              echo "Invalid port specified; bailing out"
              exit -1
      esac

      # Check endpoint
      echo IFS=$'\n' read -rd '' -a resp < <(curl -s -I -X GET -H "User-Agent: f5-ltm" -H "X-Auth-Token: $token"  $check_url -w "\n%{http_code}")
      IFS=$'\n' read -rd '' -a resp < <(curl -s -I -X GET -H "User-Agent: f5-ltm" -H "X-Auth-Token: $token"  $check_url -w "\n%{http_code}")

      # Store status code
      status="${resp[@]:(-1)}"

      # Check if we've got an expected status code
      for status_code in $expected_statuses; do
          if [[ "$status" == "$status_code" ]]
          then
              echo "Success" >&3
              exit 0
          fi
      done

      # Check for 401 (token expiration or unauthorized)
      if [[ "$status" == "401" ]]
      then
          # Exit if token is new
          if [[ "$token_new" == "1" ]]
          then
              echo "Exiting after failure to authorize with valid token $token on $check_url"
              printf "%s\n" "${resp[@]}"
              exit -1
          # Else we tried cached token
          else
              # Get a new token and try again
              new_token
              do_check
          fi
      # Something else happened, so bail
      else
          echo "Exiting on status: $status"
          printf "%s\n" "${resp[@]}"
          exit -1
      fi
  }

  # Get token
  get_token
  # Do endpoint check
  do_check $1 $2
