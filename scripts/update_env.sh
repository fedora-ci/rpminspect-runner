#!/bin/bash

set -x

# Update the virus dababase
freshclam

# Update rpminspect and annocheck
dnf update -y "${RPMINSPECT_PACKAGE_NAME}" "${RPMINSPECT_DATA_PACKAGE_NAME}" annobin-annocheck

# Always success: failed dnf-update should not block testing (?)
exit 0
