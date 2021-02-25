#!/bin/bash

inspections=$(rpminspect -l | grep -A200 "Available inspections:" | tail -n +2)

for inspection in $inspections; do
    echo "    - name: ${inspection}"
    echo "      framework: shell"
    echo "      test: /usr/local/bin/rpminspect_runner.sh \$TASK_ID \$PREVIOUS_TAG ${inspection}"
    echo "      duration: 20m"
done
