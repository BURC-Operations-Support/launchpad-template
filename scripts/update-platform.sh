#!/usr/bin/env bash

# ============================================================
# MODIFY WITH CAUTION!
#
# TITLE: BURC Launchpad Platform Updater
# DESCRIPTION: Update the shared Launchpad development platform
# AUTHOR: Cole H. Shaigec
# DATE: November 2026
# MAINTAINERS: Boston University Robotics Club
#
# NOTES TO USERS:
# This script must be executed from the host machine.
# DO NOT execute it within the running Dev Container,
# as this WILL NOT work!
#
# It pulls the latest shared Launchpad image, rebuilds the
# project development image, recreates the development
# container, and verifies the updated environment.
#
# Project source files and persistent Docker volumes are
# preserved. Changes made directly to the container's
# writable filesystem are not preserved.
# ============================================================

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly PLATFORM_IMAGE="ghcr.io/burc-operations-support/launchpad:main"

# ---------------------------------------------------------
# Environment validation
# ---------------------------------------------------------

if [[ -n "${LAUNCHPAD_ENV:-}" || -f /.dockerenv ]]; then
    printf '[FAIL] Platform updates must be performed on the host.\n' >&2
    printf '       Open a native terminal and run make update-platform.\n' >&2
    exit 1
fi

printf '\nBURC Launchpad Platform Update\n'
printf '==============================\n'

# Verify host prerequisites before modifying the environment.
bash scripts/doctor.sh


# ---------------------------------------------------------
# Platform update
# ---------------------------------------------------------

printf '\n[1/4] Pulling latest Launchpad platform...\n'

docker pull "$PLATFORM_IMAGE"


printf '\n[2/4] Rebuilding development image...\n'

docker compose build --pull dev


printf '\n[3/4] Recreating development container...\n'

docker compose up \
    --detach \
    --no-deps \
    --force-recreate \
    dev


printf '\n[4/4] Verifying updated environment...\n'

docker compose exec -T dev \
    bash -c '
        source "/opt/ros/${ROS_DISTRO}/setup.bash"
        bash scripts/doctor.sh
    '


# ---------------------------------------------------------
# Completion
# ---------------------------------------------------------

printf '\n==============================\n'
printf '[SUCCESS] Launchpad platform updated.\n'
printf 'Reopen your VS Code Dev Container to resume development.\n'