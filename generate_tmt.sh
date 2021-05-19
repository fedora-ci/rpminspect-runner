#!/bin/bash

inspections=$(rpminspect -l | grep -A400 "Available inspections:" | tail -n +2)

# First invocation runs all inspections so we need to be generous with the timeout;
# but subsequent invocations just return cached results
duration=600m
default_duration=2m

for inspection in $inspections; do
    echo "    - name: ${inspection}"
    echo "      framework: shell"
    echo "      test: /usr/local/bin/rpminspect_runner.sh \$TASK_ID \$PREVIOUS_TAG ${inspection}"
    echo "      duration: ${duration}"

    duration="${default_duration}"
done

# Add rpminspect diagnostics and pretend it is an inspection (so it shows up in places like CI dashboard)
echo "    - name: diagnostics"
echo "      framework: shell"
echo "      test: /usr/local/bin/rpminspect_runner.sh \$TASK_ID \$PREVIOUS_TAG diagnostics"
echo "      duration: ${default_duration}"
