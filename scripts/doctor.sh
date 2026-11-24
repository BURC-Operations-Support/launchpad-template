#!/usr/bin/env bash

# ============================================================
# MODIFY WITH CAUTION!
#
# TITLE: BURC Launchpad Doctor
# DESCRIPTION: Host and container environment diagnostics
# AUTHOR: Cole H. Shaigec
# DATE: November 2026
# MAINTAINERS: Boston University Robotics Club
#
# NOTES TO USERS:
# This script performs non-destructive checks of the host or
# containerized development environment. It reports failures
# alongside actionable remediation instructions.
#
# Exit codes:
#   0 - All required checks passed.
#   1 - One or more required checks failed.
#
# Warnings identify potential issues that do not necessarily
# prevent development.
#
# This script deliberately does not install dependencies,
# modify configuration, or start/stop containers.
# ============================================================

set -u

# Resolve the repository root independently of the caller's
# current working directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

PASSED=0
FAILED=0
WARNINGS=0


# ---------------------------------------------------------
# Diagnostic reporting
# ---------------------------------------------------------

pass() {
    printf '[PASS] %s\n' "$1"
    PASSED=$((PASSED + 1))
}

fail() {
    printf '[FAIL] %s\n' "$1"
    printf '       Fix: %s\n' "$2"
    FAILED=$((FAILED + 1))
}

warn() {
    printf '[WARN] %s\n' "$1"
    printf '       Advice: %s\n' "$2"
    WARNINGS=$((WARNINGS + 1))
}

section() {
    printf '\n--- %s ---\n' "$1"
}


# ---------------------------------------------------------
# Generic diagnostic helpers
# ---------------------------------------------------------

check_command() {
    local executable="$1"
    local remediation="$2"

    if command -v "$executable" >/dev/null 2>&1; then
        pass "$executable is available"
    else
        fail "$executable is unavailable" "$remediation"
    fi
}

check() {
    local description="$1"
    local remediation="$2"

    shift 2

    if "$@" >/dev/null 2>&1; then
        pass "$description"
    else
        fail "$description" "$remediation"
    fi
}


# ---------------------------------------------------------
# Git diagnostics
# ---------------------------------------------------------

check_git() {
    section "Git configuration"

    check_command git "Install Git on your host machine."

    if ! command -v git >/dev/null 2>&1; then
        return
    fi

    check \
        "Git author name is configured" \
        "On your host, run: git config --global user.name \"Your Name\"" \
        git config --get user.name

    check \
        "Git author email is configured" \
        "On your host, run: git config --global user.email \"Your Email\"" \
        git config --get user.email
}


# ---------------------------------------------------------
# Host diagnostics
# ---------------------------------------------------------

check_host() {
    section "Host development environment"

    check_command docker \
        "Install Docker according to the BURC onboarding guide."

    if ! command -v docker >/dev/null 2>&1; then
        return
    fi

    check \
        "Docker daemon is reachable" \
        "Start Docker Desktop or the Docker Engine." \
        docker info

    check \
        "Docker Compose is available" \
        "Install or update Docker Compose V2." \
        docker compose version

    check \
        "Compose configuration is valid" \
        "Restore compose.yaml or contact your project lead." \
        docker compose config --quiet

    warn \
        "Container toolchain has not been inspected" \
        "Reopen the project in its Dev Container and run make doctor again."
}


# ---------------------------------------------------------
# Container diagnostics
# ---------------------------------------------------------

check_container() {
    # Shared toolchain dependencies are supplied by Launchpad.
    # Contributors should not install missing infrastructure
    # dependencies manually inside individual containers.
    local toolchain_fix="Rebuild the Launchpad Dev Container. If the problem persists, contact the Lead Software Architect."

    section "ROS 2 environment"

    if [[ "${ROS_DISTRO:-}" == "lyrical" ]]; then
        pass "ROS 2 Lyrical is active"
    else
        fail \
            "Expected ROS 2 Lyrical; found ${ROS_DISTRO:-unset}" \
            "$toolchain_fix"
    fi

    check_command ros2 "$toolchain_fix"

    check_command colcon "$toolchain_fix"

    check_command rosdep "$toolchain_fix"


    section "Python environment"

    if [[ -x /opt/venv/bin/python ]]; then
        pass "Launchpad virtual environment exists"

        check \
            "Python 3.14 is available in the virtual environment" \
            "Rebuild or reset the development environment." \
            /opt/venv/bin/python -c \
            'import sys; assert sys.version_info[:2] == (3, 14)'

        check \
            "Virtual environment can import rclpy" \
            "Rebuild the Dev Container and verify ROS environment sourcing." \
            /opt/venv/bin/python -c 'import rclpy'
    else
        fail \
            "Launchpad virtual environment is missing" \
            "Rebuild or reset the development environment."
    fi


    section "Python development tools"

    check_command uv "$toolchain_fix"

    check_command ruff "$toolchain_fix"

    check_command pyright "$toolchain_fix"

    check_command pytest "$toolchain_fix"


    section "C/C++ development tools"

    check_command gcc "$toolchain_fix"

    check_command g++ "$toolchain_fix"

    check_command cmake "$toolchain_fix"

    check_command clang-tidy "$toolchain_fix"

    check_command clang-format "$toolchain_fix"

    check_command gdb "$toolchain_fix"
}


# ---------------------------------------------------------
# Diagnostic execution
# ---------------------------------------------------------

printf '\nBURC Launchpad Doctor\n'
printf '=====================\n'

check_git

# LAUNCHPAD_ENV is the explicit environment identification
# contract established by the development Dockerfile.
#
# /.dockerenv provides a defensive fallback for detecting
# Docker containers that lack the expected Launchpad marker.
#
# An unrecognized container must not be treated as a host:
# doing so would incorrectly require Docker to be installed
# inside the development container.
if [[ "${LAUNCHPAD_ENV:-}" == "development" ]]; then
    printf '\nEnvironment: Launchpad development container\n'
    check_container

elif [[ -f /.dockerenv ]]; then
    printf '\nEnvironment: Unrecognized Docker container\n'

    fail \
        "Launchpad environment marker is missing or invalid" \
        "Verify LAUNCHPAD_ENV in the Dockerfile and rebuild the Dev Container."

else
    printf '\nEnvironment: Host\n'
    check_host
fi


# ---------------------------------------------------------
# Diagnostic summary
# ---------------------------------------------------------

printf '\n=====================\n'
printf 'Passed:   %d\n' "$PASSED"
printf 'Failed:   %d\n' "$FAILED"
printf 'Warnings: %d\n' "$WARNINGS"

if [[ "$FAILED" -gt 0 ]]; then
    printf '\nDevelopment environment requires attention.\n'
    exit 1
fi

printf '\nAll required diagnostic checks passed.\n'
exit 0