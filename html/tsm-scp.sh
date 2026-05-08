#!/bin/bash
# ══════════════════════════════════════════════════════════════
#  tsm-scp.sh — copy TSM files to the construction droplet NOW
#  Usage: bash tsm-scp.sh
# ══════════════════════════════════════════════════════════════
REMOTE="root@tsm-construction-s-1vcpu-2gb-nyc3-01"
OUTPUT="/mnt/user-data/outputs"
AUDIT="/root/onclick-audit"

echo "→ Testing connection to ${REMOTE}…"
ssh -o ConnectTimeout=8 -o BatchMode=yes "${REMOTE}" "echo '  SSH OK'" || {
  echo "✗  Cannot reach ${REMOTE} — check your SSH key is loaded (ssh-add) and host is up"
  exit 1
}

# Create remote dirs
echo "→ Creating remote directories…"
ssh "${REMOTE}" "mkdir -p ~/tsm-html ~/onclick-audit ~/tsm-deploy"

# Copy HTML output files
echo "→ Copying HTML files from ${OUTPUT}…"
scp "${OUTPUT}"/*.html "${REMOTE}:~/tsm-html/" 2>/dev/null \
  && echo "  ✓ HTML files copied" \
  || echo "  ⚠  No .html files found in ${OUTPUT}"

# Copy deploy script itself
echo "→ Copying deploy script…"
scp "${OUTPUT}/tsm-deploy.sh" "${REMOTE}:~/tsm-deploy.sh" 2>/dev/null \
  && echo "  ✓ tsm-deploy.sh copied" || true

# Copy onclick audit dir
if [[ -d "$AUDIT" ]]; then
  echo "→ Copying onclick audit dir…"
  scp -r "${AUDIT}/." "${REMOTE}:~/onclick-audit/" 2>/dev/null \
    && echo "  ✓ onclick-audit synced" || echo "  ⚠  onclick-audit copy had issues"
fi

echo ""
echo "✓  Done. Files are at ${REMOTE}:~/tsm-html/"
echo ""
echo "  To verify on the remote:"
echo "  ssh ${REMOTE} 'ls -lh ~/tsm-html/'"
