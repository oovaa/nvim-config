#!/usr/bin/env bash
# Bootstrap this Neovim config on a fresh machine.
#
#   ./setup.sh           # full setup (may sudo for system packages)
#   ./setup.sh --check   # report what's missing, change nothing
#
# Env overrides: REPO_URL, NVIM_CONFIG_DIR, NO_SUDO=1
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/oovaa/nvim-config.git}"
NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

# --- colors ---------------------------------------------------------------
if [[ -t 1 ]] && command -v tput &>/dev/null; then
  BOLD="$(tput bold)"; DIM="$(tput dim 2>/dev/null || true)"
  GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"
  RED="$(tput setaf 1)"; CYAN="$(tput setaf 6)"; RESET="$(tput sgr0)"
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; RESET=""
fi

step() { echo -e "\n${BOLD}${CYAN}==>${RESET}${BOLD} $*${RESET}"; }
info() { echo -e "${DIM}-->${RESET} $*"; }
ok()   { echo -e "${GREEN}  [ok]${RESET} $*"; }
warn() { echo -e "${YELLOW}  [warn]${RESET} $*"; }
fail() { echo -e "${RED}  [missing]${RESET} $*"; }

have() { command -v "$1" &>/dev/null; }
MISSING=()

need() { # need <binary> <label> [install-hint]
  if have "$1"; then ok "$2 ($1 $(command -v "$1"))"; else fail "$2${3:+ — $3}"; MISSING+=("$1"); fi
}

# --- detect package manager -----------------------------------------------
PM=""; SUDO=""
[[ "${NO_SUDO:-}" != "1" ]] && { have sudo && SUDO="sudo" || SUDO=""; }
if have brew; then PM="brew"
elif have apt-get; then PM="apt"
elif have dnf; then PM="dnf"
elif have pacman; then PM="pacman"
fi

pm_install() { # pm_install <packages...>
  (( CHECK_ONLY )) && { info "would install: $* (check mode, skipping)"; return; }
  case "$PM" in
    brew)   brew install "$@" ;;
    apt)    $SUDO apt-get update -qq && $SUDO apt-get install -y "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
    *)      warn "no package manager found — install manually: $*"; return 1 ;;
  esac
}

echo -e "${BOLD}Neovim config bootstrap${RESET}  ${DIM}(--check to audit only)${RESET}"
info "target dir : $NVIM_CONFIG_DIR"
info "repo       : $REPO_URL"
info "pkg manager: ${PM:-none}"

# --- 1. system tools -------------------------------------------------------
step "1/7  System tools"
need git "git" "required to clone + update plugins"
need rg "ripgrep" "Telescope grep, grug-far"
need fd "fd" "Telescope file finder"
need make "make" "telescope-fzf-native build"
need cmake "cmake" "telescope-fzf-native build"
need gcc "C compiler" "telescope-fzf-native build"
need curl "curl" "downloads"
need unzip "unzip" "Mason packages"
need nvim "neovim >= 0.11" "see README install recipes"

if (( ! CHECK_ONLY )) && (( ${#MISSING[@]} > 0 )); then
  # Install ONLY what's missing (binary -> package name mapping).
  pkgs=()
  for b in "${MISSING[@]}"; do
    case "$b" in
      fd) if [[ "$PM" == apt || "$PM" == dnf ]]; then pkgs+=(fd-find); else pkgs+=(fd); fi ;;
      nvim) pkgs+=(neovim) ;;
      *) pkgs+=("$b") ;;
    esac
  done
  if [[ " ${pkgs[*]} " == *" python3 "* && "$PM" != brew ]]; then pkgs+=(python3-pip); fi
  case "$PM" in
    brew|apt|dnf|pacman) pm_install "${pkgs[@]}" || true ;;
    *) warn "install the missing tools by hand, then re-run" ;;
  esac
fi

# --- 2. runtimes -----------------------------------------------------------
step "2/7  Runtimes (bun, node, python)"
if have bun; then ok "bun $(bun --version)"; else
  fail "bun — markdown-preview build, JS/TS runs"
  if (( ! CHECK_ONLY )); then
    info "installing bun…"
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    have bun && ok "bun $(bun --version)" || warn "bun install needs new shell (PATH); re-run script after"
  fi
fi
need node "node" "markdown-preview server, LSPs"
need python3 "python3" "molten, neotest-python"

if have python3 && ! python3 -c "import pynvim" &>/dev/null; then
  fail "pynvim python module"
  (( CHECK_ONLY )) || { info "pip install pynvim jupyter ipykernel…"; python3 -m pip install --user pynvim jupyter ipykernel; }
else
  have python3 && ok "pynvim python module"
fi

# --- 3. language servers outside Mason -------------------------------------
step "3/7  Manual LSPs (vtsls, pyrefly)"
if have vtsls; then ok "vtsls $(vtsls --version 2>/dev/null || true)"
else
  fail "vtsls — TypeScript LSP (Mason does not manage it)"
  if (( ! CHECK_ONLY )) && have bun; then bun add -g @vtsls/language-server && ok "vtsls installed"; fi
fi
if have pyrefly; then ok "pyrefly $(pyrefly --version 2>/dev/null || true)"
else
  fail "pyrefly — Python LSP (Mason does not manage it)"
  if (( ! CHECK_ONLY )); then
    if [[ "$PM" == "brew" ]]; then brew install pyrefly && ok "pyrefly installed" || true
    else warn "install via Homebrew: brew install pyrefly"; fi
  fi
fi

# --- 4. config repo --------------------------------------------------------
step "4/7  Config repo"
if [[ -f "$NVIM_CONFIG_DIR/init.lua" && "$NVIM_CONFIG_DIR" -ef "$(pwd)" ]]; then
  ok "running from the config dir itself — nothing to clone"
elif [[ -d "$NVIM_CONFIG_DIR/.git" ]]; then
  info "updating existing checkout…"
  (( CHECK_ONLY )) || git -C "$NVIM_CONFIG_DIR" pull --ff-only
  ok "config up to date"
elif [[ -e "$NVIM_CONFIG_DIR" ]]; then
  warn "$NVIM_CONFIG_DIR exists but is not this repo — backing up to ${NVIM_CONFIG_DIR}.bak"
  (( CHECK_ONLY )) || mv "$NVIM_CONFIG_DIR" "${NVIM_CONFIG_DIR}.bak"
  (( CHECK_ONLY )) || git clone "$REPO_URL" "$NVIM_CONFIG_DIR"
else
  (( CHECK_ONLY )) || git clone "$REPO_URL" "$NVIM_CONFIG_DIR"
  ok "cloned to $NVIM_CONFIG_DIR"
fi

# --- 5. plugins ------------------------------------------------------------
step "5/7  Plugins (lazy.nvim sync)"
if have nvim; then
  if (( CHECK_ONLY )); then info "would run: nvim --headless '+Lazy! sync' +qa"
  else
    info "installing/updating plugins (watch progress below)…"
    nvim --headless "+Lazy! sync" +qa
    ok "plugins synced"
  fi
else
  warn "skipping — nvim not installed"
fi

# --- 6. verify -------------------------------------------------------------
step "6/7  Verify"
if have nvim && (( ! CHECK_ONLY )); then
  info "health check:"
  nvim --headless -c 'checkhealth config.health' -c 'qa!' 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^(OK|WARNING|ERROR)|- (OK|WARNING|ERROR)' | head -12 || true
  info "test suites:"
  for t in test_critical_fixes test_performance test_qol test_polish; do
    res=$(nvim --headless -c "lua require(\"plenary.busted\").run(\"tests/$t.lua\")" -c 'qa!' 2>&1 \
      | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^(Success|Failed)' | tr '\n' ' ')
    # shellcheck disable=SC2086
    echo "  $t: $res"
  done
else
  info "skipped (check mode or no nvim)"
fi

# --- 7. fonts --------------------------------------------------------------
step "7/7  Manual reminders"
warn "Nerd Font required (vim.g.have_nerd_font = true) — https://www.nerdfonts.com"
warn "kitty terminal for image rendering (image.nvim kitty backend)"

echo
if (( ${#MISSING[@]} > 0 )) && (( CHECK_ONLY )); then
  echo -e "${YELLOW}Missing tools: ${MISSING[*]}${RESET} — run without --check to install."
elif (( CHECK_ONLY )); then
  echo -e "${GREEN}All checks passed.${RESET}"
else
  echo -e "${GREEN}Setup complete.${RESET} Open ${DIM}nvim${RESET}, run ${DIM}:checkhealth config.health${RESET} and ${DIM}:Lazy${RESET}."
fi
