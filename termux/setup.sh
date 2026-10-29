#!/usr/bin/env bash
# ==============================================================================
#   ⚡ EDU SOLVER CLI — Environment Setup Script
#   Installs required runtime dependencies for Termux and Linux systems
# ==============================================================================
set -euo pipefail

# Color Palette
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_GREEN='\033[1;32m'
  C_CYAN='\033[1;36m'
  C_YELLOW='\033[1;33m'
  C_WHITE='\033[1;37m'
  C_GRAY='\033[0;90m'
else
  C_RESET='' C_BOLD='' C_GREEN='' C_CYAN='' C_YELLOW='' C_WHITE='' C_GRAY=''
fi

SYM_CHECK="${C_GREEN}✔${C_RESET}"
SYM_ARROW="${C_CYAN}➜${C_RESET}"
SYM_GEAR="${C_YELLOW}⚙${C_RESET}"

printf "\n"
printf "  ${C_CYAN}┌──────────────────────────────────────────────────────────────┐${C_RESET}\n"
printf "  ${C_CYAN}│${C_RESET}  ${C_BOLD}${C_WHITE}EDU SOLVER CLI  •  Environment Setup${C_RESET}                       ${C_CYAN}│${C_RESET}\n"
printf "  ${C_CYAN}│${C_RESET}  ${C_GRAY}Automated Dependency Installer & Initializer${C_RESET}                ${C_CYAN}│${C_RESET}\n"
printf "  ${C_CYAN}└──────────────────────────────────────────────────────────────┘${C_RESET}\n\n"

if command -v pkg >/dev/null 2>&1; then
  printf "  ${SYM_GEAR} ${C_BOLD}Detected Environment: Termux (pkg)${C_RESET}\n"
  printf "  ${SYM_ARROW} Updating package lists...\n"
  pkg update -y 2>/dev/null || true

  printf "  ${SYM_ARROW} Installing required packages: curl, jq, coreutils, bash...\n"
  pkg install -y curl jq coreutils bash
elif command -v apt-get >/dev/null 2>&1; then
  printf "  ${SYM_GEAR} ${C_BOLD}Detected Environment: Debian / Ubuntu (apt)${C_RESET}\n"
  printf "  ${SYM_ARROW} Updating package repositories...\n"
  sudo apt-get update -y 2>/dev/null || apt-get update -y 2>/dev/null || true

  printf "  ${SYM_ARROW} Installing required tools...\n"
  sudo apt-get install -y curl jq coreutils bash 2>/dev/null || apt-get install -y curl jq coreutils bash
fi

# Ensure executable bit on solve.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/solve.sh" ]]; then
  chmod +x "$SCRIPT_DIR/solve.sh"
  printf "  ${SYM_CHECK} Executable permissions granted to ${C_BOLD}solve.sh${C_RESET}\n"
fi

printf "\n  ${C_GREEN}╭─────────────────────────────────────────────────────────────╮${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}  ${SYM_CHECK}  ${C_BOLD}${C_GREEN}Environment setup successfully completed!${C_RESET}                ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}                                                             ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}  ${C_WHITE}Launch the interactive CLI by running:${C_RESET}                    ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}    ${C_BOLD}${C_CYAN}./solve.sh${C_RESET}                                               ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}                                                             ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}  ${C_GRAY}View all command-line options and examples:${C_RESET}                ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}│${C_RESET}    ${C_BOLD}${C_CYAN}./solve.sh --help${C_RESET}                                        ${C_GREEN}│${C_RESET}\n"
printf "  ${C_GREEN}╰─────────────────────────────────────────────────────────────╯${C_RESET}\n\n"
