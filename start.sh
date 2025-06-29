#!/bin/bash

# Change directory to the script's location
cd "$(dirname "$0")" || exit
killall conky
# Wait for a short period to ensure conky processes are terminated

./weather.sh
sleep 2

# Start conky with the specified configuration file
( set -x; setsid conky -c conky.conf )

exit