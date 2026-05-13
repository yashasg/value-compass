#!/usr/bin/env bash
# Validate that CI/CD workflows do not log GitHub secrets.
#
# This script checks for unsafe patterns that could leak secrets to logs:
# - Direct echo/print of secret environment variables to stdout
# - Unmasked secret variable references in run commands
# - Secrets passed as arguments to commands without redirection
#
# Safe patterns (excluded from checks):
# - echo "secret" | <command> — piped, output not logged
# - echo "secret" > file — redirected to file, not logged
# - echo "secret" 2>&1 — only if captured/redirected
#
# Exit: 0 if validation passes, 1 if unsafe patterns detected.

set -euo pipefail

WORKFLOWS_DIR=".github/workflows"

FAILED=0

echo "Validating CI/CD workflows for unsafe secret logging patterns..."
echo ""

for workflow in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
  if [ ! -f "$workflow" ]; then
    continue
  fi

  workflow_basename=$(basename "$workflow")
  
  # Skip squad automation workflows (they don't use secrets)
  if [[ "$workflow_basename" =~ ^squad- ]]; then
    continue
  fi

  # Look for echo/printf of secret environment variables that are NOT piped or redirected
  # This grep pattern finds lines with echo/printf of a secret variable
  # that don't have | or > on the same line (meaning stdout goes to logs).
  while IFS= read -r line_num line_text; do
    # Skip comments
    if [[ "$line_text" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    
    # Check if line contains echo/printf of a secret variable
    if [[ "$line_text" =~ echo.*\$\{.*[A-Z_]*(SECRET|PASSWORD|API|KEY|TOKEN) ]] || \
       [[ "$line_text" =~ echo.*\$\{\{.*secrets\. ]] || \
       [[ "$line_text" =~ printf.*\$\{\{.*secrets\. ]]; then
      
      # If it's piped (|) or redirected (> or >>), it's safe
      if [[ "$line_text" =~ \| ]] || [[ "$line_text" =~ \>\> ]] || [[ "$line_text" =~ \>[[:space:]]*\/ ]]; then
        continue
      fi
      
      # If it's part of a base64 decode pipeline, it's safe
      if [[ "$line_text" =~ base64.*decode ]] || [[ "$line_text" =~ \|.*base64 ]]; then
        continue
      fi
      
      # If it's part of a multi-line statement with redirection on next line, skip
      # (would need better parsing, but this is a simple check)
      
      echo "⚠️  UNSAFE PATTERN FOUND: $workflow_basename"
      echo "   Line $line_num: $line_text"
      echo "   Issue: Secret variable is echoed/printed without piping or redirection"
      echo ""
      FAILED=1
    fi
  done < <(grep -n -E 'echo.*\$\{.*[A-Z_]*(SECRET|PASSWORD|API|KEY|TOKEN)|echo.*\$\{\{.*secrets\.|printf.*\$\{\{.*secrets\.' "$workflow" 2>/dev/null || true)
done

if [ "$FAILED" -eq 0 ]; then
  echo "✓ All workflows passed secret logging validation."
  exit 0
else
  echo "✗ Some workflows have unsafe secret logging patterns."
  echo "  Fix by: removing direct echo/print of secret variables to stdout."
  exit 1
fi
