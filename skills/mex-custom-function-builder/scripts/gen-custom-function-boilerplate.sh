#!/bin/bash

# 1. Define all known paths, including Yarn, NPM, NVM, and Homebrew
SKED_BIN=""
for path in \
  "$(yarn global bin 2>/dev/null)/sked" \
  "$HOME/.yarn/bin/sked" \
  "$(npm prefix -g 2>/dev/null)/bin/sked" \
  $(ls $HOME/.nvm/versions/node/*/bin/sked 2>/dev/null) \
  "/opt/homebrew/bin/sked" \
  "/usr/local/bin/sked" \
  "$HOME/.npm-global/bin/sked"; do

  # 2. If the file exists and is executable, grab it and stop searching
  if [ -x "$path" ]; then
    SKED_BIN="$path"
    break
  fi
done

# 3. Execute the commands if found
if [ -n "$SKED_BIN" ]; then
  echo "✅ Found sked at: $SKED_BIN"
  "$SKED_BIN" plugins install @skedulo/plugin-mex
  "$SKED_BIN" mex template sync-custom-function --non-interactive
else
  echo "❌ Error: Could not find 'sked' installed via Yarn, NPM, NVM, or Homebrew."
  exit 1
fi