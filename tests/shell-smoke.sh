#!/usr/bin/env bash
set -euo pipefail

smoke_home=$(mktemp -d)
trap 'rm -rf "$smoke_home"' EXIT
export HOME="$smoke_home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

git --version
node --version
go version
python --version
uv --version
rustc --version
cargo --version
nixfmt --version
opencode --version

test "${GOTOOLCHAIN:-}" = local
test "${UV_PYTHON_DOWNLOADS:-}" = never

nvim --headless -n -i NONE \
  -c 'lua if vim.v.errmsg ~= "" then io.stderr:write(vim.v.errmsg .. "\n"); vim.cmd("cquit 1") end' \
  -c 'lua if vim.g.mapleader ~= " " then io.stderr:write("Tendril Neovim config was not loaded\n"); vim.cmd("cquit 1") end' \
  -c 'qa!'
