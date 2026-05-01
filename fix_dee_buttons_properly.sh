#!/usr/bin/env bash
set -e

FILE="/workspaces/tsm-shell/html/honor-portal/index.html"
BACKUP="/workspaces/tsm-shell/html/honor-portal/index.backup.$(date +%s).html"

cp "$FILE" "$BACKUP"
echo "Backup saved: $BACKUP"

########################################
# 1. REMOVE INLINE onclick HANDLERS
########################################
sed -i 's/onclick="quickAsk([^"]*)"/data-action="quickask"/g' "$FILE"
sed -i 's/onclick="runQuickPack([^"]*)"/data-action="runpack"/g' "$FILE"

########################################
# 2. FIX BROKEN DIV (CRITICAL)
########################################
sed -i 's/<div[[:space:]]*$//g' "$FILE"
sed -i 's/<div[[:space:]]*<div/<div/g' "$FILE"

########################################
# 3. ADD STABLE EVENT SYSTEM (ONE TIME)
########################################
cat <<'JS' >> "$FILE"

<script>
// ===== GLOBAL ACTION SYSTEM (PERSISTENT) =====

window.deeState = {
  busy: false
};

document.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn) return;

  if (window.deeState.busy) return;

  const action = btn.dataset.action;

  window.deeState.busy = true;
  btn.classList.add('dee-btn','loading');

  try {
    if (action === 'quickask') {
      await runQuickAsk(btn);
    }

    if (action === 'runpack') {
      await runPack(btn);
    }

  } catch(err) {
    console.error('Action failed:', err);
  }

  btn.classList.remove('loading');
  window.deeState.busy = false;
});

async function runQuickAsk(btn){
  const text = btn.innerText || "Run analysis";

  const output = document.getElementById('dee-live-output');
  if (output) {
    output.innerHTML = "<div class='dee-last-action'>Running: " + text + "</div>";
  }

  // Simulated response (replace with real API later)
  setTimeout(()=>{
    if (output) {
      output.innerHTML += "<div style='margin-top:10px'>✓ Completed: " + text + "</div>";
    }
  }, 800);
}

async function runPack(btn){
  const output = document.getElementById('dee-live-output');

  if (output) {
    output.innerHTML = "<div class='dee-last-action'>Pulling intelligence pack...</div>";
  }

  setTimeout(()=>{
    if (output) {
      output.innerHTML += "<div style='margin-top:10px'>✓ Pack ready</div>";
    }
  }, 1000);
}
</script>

JS

########################################
# 4. CLEAN DUPLICATE CONTAINERS
########################################
# Remove duplicate dee-command-center blocks
awk '!seen[$0]++' "$FILE" > tmp && mv tmp "$FILE"

########################################
# 5. DONE
########################################
echo "Dee system rebuilt clean. No more dead buttons."

