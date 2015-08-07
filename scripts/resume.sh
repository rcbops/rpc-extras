#!/usr/bin/env bash

# Script originally written by Evan Callicoat
#
# Execute each command from stdin. If the command fails
# output a sensible error message and include instructions
# to allow the user to resume execution at the next step.

# Set options
set -euo pipefail

# Initial step count
STEP=0

# Handle errors
handle_error() {
    # Store command that caused error
    cmd="$BASH_COMMAND"

    # If we didn't run any steps yet
    if [[ $STEP -eq 0 ]]; then
        echo "Error before running steps: $cmd"
    # Otherwise inform how to resume
    else
        echo "******************** FAILURE ********************"
        echo "Error executing step $STEP: $step"
        echo "Please resume with: $0 $STEP"
        echo "******************** FAILURE ********************"
    fi
}

# Hook errors to handler
trap handle_error ERR

# Load up command steps from stdin
readarray -t -O 1 STEPS

# If no step arg specified
if [[ $# -lt 1 ]]; then
    # Start at step 1
    start=1
else
    # Otherwise start at arg
    start=$1

    # Offset for counter ordering
    STEP=$(($1-1))
fi

# Dispatch steps in order, from starting step
for step in "${STEPS[@]:$start}"; do
    # Bump step-counter
    STEP=$((STEP+1))

    # Talk about it
    echo "Running step $STEP: $step"

    # Do the needful
    eval $step
done
