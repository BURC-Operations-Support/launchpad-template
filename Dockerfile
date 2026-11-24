
# syntax=docker/dockerfile:1

# ============================================================
# TITLE: BURC Launchpad Template
# DESCRIPTION: Standardized ROS 2 project container architecture
# AUTHOR: Cole H. Shaigec
# DATE: November 2026
# MAINTAINERS: Boston University Robotics Club
#
# STAGES:
#   development - Interactive ROS 2 development environment
#   builder     - Reproducible ROS workspace build
#   runtime     - Lean deployable application image
#
# DEPENDENCY MANAGEMENT:
#   package.xml    -> ROS dependencies (rosdep)
#   pyproject.toml -> Python dependencies (uv)
#   uv.lock        -> Locked Python dependency versions
#   CMakeLists.txt -> ROS C++ build configuration
#
# The Makefile and Docker Compose configuration provide
# the developer-facing interface.
# ============================================================

# ------------------------------------------------------------
# Stage 1: Development
# ------------------------------------------------------------

FROM ghcr.io/burc-operations-support/launchpad:main AS development

SHELL ["/bin/bash", "-c"]

WORKDIR /workspace

# Identify the Launchpad development environment to shared
# infrastructure tooling, including the Makefile and doctor.
#
# This allows tooling to distinguish container-side execution
# from host-side execution without relying on Docker-specific
# filesystem heuristics.
ENV LAUNCHPAD_ENV=development

# Store project Python dependencies outside the bind-mounted
# source tree. The environment can be persisted by Compose.
#
# Use the system Python interpreter supplied by ROS.
# Do not download an independent Python interpreter.
ENV UV_PROJECT_ENVIRONMENT="/opt/venv" \
    UV_PYTHON_DOWNLOADS="never"

# Create the project environment using ROS-compatible Python.
#
# --system-site-packages permits access to system-installed
# ROS Python packages, including rclpy.
#
# Project dependencies remain managed by uv.
RUN uv venv \
    --python /usr/bin/python3 \
    --system-site-packages \
    "${UV_PROJECT_ENVIRONMENT}"

# Automatically source the ROS underlay and any previously
# built workspace overlay in interactive Bash sessions.
#
# The overlay is optional because a new project will not
# contain an install directory before its first build.
RUN printf '%s\n' \
    'source "/opt/ros/${ROS_DISTRO}/setup.bash"' \
    'if [ -f /workspace/install/local_setup.bash ]; then' \
    '    source /workspace/install/local_setup.bash' \
    'fi' \
    >> /etc/bash.bashrc

# Project source is bind-mounted by Docker Compose.
# Developers do not rebuild this image after source edits.
#
# The Makefile will invoke uv sync, colcon, and test tools.
CMD ["bash"]


# ------------------------------------------------------------
# Stage 2: Builder
# ------------------------------------------------------------

FROM development AS builder

# Copy dependency metadata separately from application code.
# This allows Docker to cache dependency installation when
# source files change but dependency declarations do not.
COPY ./pyproject.toml ./uv.lock /workspace/

# Install locked production Python dependencies.
#
# --no-dev excludes development-only dependency groups.
# --no-install-project avoids installing the root project
# as a separate Python distribution; ROS packages are built
# by colcon instead.
RUN uv sync \
    --locked \
    --no-dev \
    --no-install-project

# Copy ROS package source and manifests.
COPY ./src/ /workspace/src/



# Install ROS build and execution dependencies.
#
# rosdep reads package.xml files throughout src/.
# --ignore-src avoids installing packages built locally.
#
# Each dependency type is supplied with its own flag.
RUN rosdep update \
    && rosdep install \
        --from-paths /workspace/src \
        --ignore-src \
        --rosdistro "${ROS_DISTRO}" \
        --dependency-types build \
        --dependency-types buildtool \
        --dependency-types build_export \
        --dependency-types buildtool_export \
        --dependency-types exec \
        -y



# Compile and install the ROS workspace.
#
# --merge-install creates one consolidated install tree,
# simplifying transfer to the runtime image.
RUN source "/opt/ros/${ROS_DISTRO}/setup.bash" \
    && colcon build \
        --merge-install \
        --event-handlers console_direct+


# ------------------------------------------------------------
# Stage 3: Runtime
# ------------------------------------------------------------

# Do not inherit Launchpad in production.
# ros-core provides a smaller starting point than ros-base.
#
# Additional runtime dependencies are resolved from the
# project's ROS manifests.
FROM ros:lyrical-ros-core-resolute AS runtime

SHELL ["/bin/bash", "-c"]

WORKDIR /workspace

# The runtime must use the same system Python version and
# compatible ROS installation as the builder.
ENV VIRTUAL_ENV="/opt/venv" \
    PATH="/opt/venv/bin:${PATH}"

# Install rosdep so runtime ROS dependencies can be resolved
# independently of the development environment.
#
# This adds some image overhead but avoids copying build-only
# packages from Launchpad.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3-rosdep \
    && rm -rf /var/lib/apt/lists/*

# Copy ROS manifests for runtime dependency resolution.
# The complete source tree is not retained in the final image.
COPY ./src/ /tmp/ros-src/

# Install execution dependencies only.
#
# Runtime images must not inherit build-only dependencies.
# Read package manifests from the temporary source directory.
RUN rosdep init \
    && rosdep update \
    && rosdep install \
        --from-paths /tmp/ros-src \
        --ignore-src \
        --rosdistro "${ROS_DISTRO}" \
        --dependency-types exec \
        -y \
    && rm -rf /tmp/ros-src \
    && rm -rf /var/lib/apt/lists/*

# Copy the production Python environment from the builder.
# Development-only uv dependencies are excluded.
COPY --from=builder \
    /opt/venv/ \
    /opt/venv/

# Copy installed ROS application artifacts only.
# Do not copy compilers, build directories, or source code.
COPY --from=builder \
    /workspace/install/ \
    /workspace/install/

# Install the standardized container entrypoint.
COPY --chmod=755 \
    ./scripts/launchpad-entrypoint.sh \
    /usr/local/bin/launchpad-entrypoint

# ------------------------------------------------------------
# Container startup contract
# ------------------------------------------------------------
#
# ENTRYPOINT prepares the ROS environment and executes
# the application command supplied by CMD or Compose.
#
# Project developers should normally leave this unchanged.
#
# Example Compose commands:
#   ["ros2", "run", "my_package", "my_node"]
#   ["ros2", "launch", "my_package", "bringup.launch.py"]
#
# exec in the entrypoint script allows application processes
# to receive container shutdown signals directly.
ENTRYPOINT ["/usr/local/bin/launchpad-entrypoint"]

# Neutral template default.
# Individual projects should configure their application
# command through Compose or CMD.
CMD ["bash"]
