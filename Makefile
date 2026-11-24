# ============================================================
# BURC Launchpad — Project Makefile
# ============================================================
#
# TITLE: BURC Launchpad Template Makefile
# AUTHOR: Cole H. Shaigec
# DATE: November 2026
# MAINTAINERS: Boston University Robotics Club
# This Makefile provides a standardized command-line interface
# for developing, building, testing, and running BURC projects.
#
# Design principles:
#   - Contributors should not need detailed Docker knowledge.
#   - Commands should work both on the host and inside the
#     Launchpad Dev Container wherever practical.
#   - Complex implementation logic belongs in scripts/ rather
#     than directly in Makefile recipes.
#   - Shared infrastructure targets should remain consistent
#     across BURC projects.
#
# ============================================================


.DEFAULT_GOAL := doctor

.PHONY: doctor update-platform


# ============================================================
# Environment diagnostics
# ============================================================

# Inspect the development environment and report configuration
# problems alongside actionable remediation instructions.
#
# This operation is non-destructive and does not modify the
# development environment.
doctor:
	@bash scripts/doctor.sh


# ============================================================
# Platform maintenance
# ============================================================

# Pull the latest shared Launchpad platform, rebuild the
# development image, recreate the container, and verify
# the resulting environment.
#
# HOST ONLY: This operation replaces the development container.
# Project source files and persistent volumes are preserved.
update-platform:
	@bash scripts/update-platform.sh