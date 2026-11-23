#!/usr/bin/env bash

# ============================================================
# MODIFY WITH CAUTION!
#
# TITLE: BURC Launchpad Entrypoint
# DESCRIPTION: Standardized ROS 2 container startup
# AUTHOR: Cole H. Shaigec
# DATE: November 2026
# MAINTAINERS: Boston University Robotics Club
#
# ============================================================

set -e

# Activate the project Python environment when available.
# Runtime images include this environment; the same convention
# is used by the development container.
if [ -f /opt/venv/bin/activate ]; then
    source /opt/venv/bin/activate
fi

# Load the system ROS 2 environment.
source "/opt/ros/${ROS_DISTRO}/setup.bash"

# Load the compiled project workspace.
source /workspace/install/local_setup.bash

# Replace this script with the requested application process.
# This preserves Docker's process and signal handling.
exec "$@"
