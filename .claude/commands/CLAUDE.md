# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This directory contains custom slash commands for Claude Code. Each `.md` file defines a command that can be invoked with `/<filename>` (without the `.md` extension).

## Available Commands

- `/commit` - Run git clang-format on C++ changes and commit
- `/profile <executable|script>` - Profile CPU usage using gperftools
- `/simplify <target>` - Iteratively simplify code while maintaining functionality
- `/tidy-commits <range>` - Reorganize and clean up git commit history

## Command File Format

Commands use `${ARGUMENTS}` as a placeholder for user-provided arguments. The markdown content becomes the prompt instructions when the command is invoked.
