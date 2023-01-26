#!/bin/bash
set -e

echo "Generating Pingdom IP address allow-list"

if [[ $# -eq 0 ]] ; then
  echo "ERROR: expected a path with a filename as the first and only argument"
  exit 1
fi

PINGDOM_IPS_URL="https://my.pingdom.com/probes/ipv4"

# Redirect output of commands to file.
{
  echo "# Correct as of: $(date)"
  echo "# Current list : $PINGDOM_IPS_URL"
  echo "# Pingdom IP Addresses"

  for IP in $(curl -sf $PINGDOM_IPS_URL); do
    echo "allow $IP;"
  done
} > "$1"

echo "SUCCESS: allow-list generated and saved to $1"
