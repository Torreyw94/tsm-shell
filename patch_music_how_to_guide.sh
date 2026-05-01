#!/usr/bin/env bash
set -euo pipefail

FILE="html/music-command/how-to-guide.html"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p backups/how_to_guide
cp -f "$FILE" "backups/how_to_guide/how-to-guide.$STAMP.bak"

python3 <<'PY'
from pathlib import Path
import re

p = Path("html/music-command/how-to-guide.html")
html = p.read_text(encoding="utf-8", errors="ignore")

html = html.replace(
    '<span class="hero-pill pill-blue">📂 Song Bank</span>',
    '<span class="hero-pill pill-blue">📂 Song Bank</span>\n'
    '    <span class="hero-pill pill-teal">📈 Hit Trajectory</span>\n'
    '    <span class="hero-pill pill-purple">💳 Creator Tiers</span>'
)

if 'href="#decision"' not in html:
    html = html.replace(
        '<a class="sidenav-item" href="#bank" onclick="setActive(this)"><span class="num">09</span> Song Bank Strategy</a>',
        '<a class="sidenav-item" href="#bank" onclick="setActive(this)"><span class="num">09</span> Song Bank Strategy</a>\n'
        '    <a class="sidenav-item" href="#decision" onclick="setActive(this)"><span class="num">10</span> Decision Mode</a>\n'
        '    <a class="sidenav-item" href="#loop" onclick="setActive(this)"><span class="num">11</span> Pick → Rerun Loop</a>\n'
        '    <a class="sidenav-item" href="#evolution" onclick="setActive(this)"><span class="num">12</span> Hit Trajectory</a>\n'
        '    <a class="sidenav-item" href="#tiers" onclick="setActive(this)"><span class="num">13</span> Plans + Upgrades</a>'
    )

css = """
<style id="tsm-howto-decision-css">
.decision-grid,.tier-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin:24px 0}
.tier-grid{grid-template-columns:repeat(4,1fr)}
.decision-card,.tier-card{border:1px solid rgba(255,255,255,.1);background:rgba(255,255,255,.035);border-radius:14px;padding:18px}
.recommended,.featured{border-color:rgba(20,241,149,.55);box-shadow:0 0 28px rgba(20,241,149,.10)}
.decision-kicker{font-family:var(--mono);font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--purple);margin-bottom:8px}
.decision-title{font-family:var(--head);font-size:20px;color:var(--text);margin-bottom:8px}
.decision-score,.tier-price{font-family:var(--mono);color:var(--teal);font-size:12px;margin:10px 0}
.tier-price{font-size:18px}
.tier-copy{color:var(--text2);font-size:14px;line-height:1.6}
.timeline-demo{border:1px solid rgba(20,241,149,.25);background:rgba(6,13,24,.88);border-radius:14px;padding:18px;margin:22px 0}
.timeline-bars{display:flex;align-items:flex-end;gap:8px;height:120px;padding:12px;border:1px solid rgba(255,255,255,.08);border-radius:10px;background:rgba(255,255,255,.03)}
.timeline-bar{flex:1;border-radius:6px 6px 0 0;background:linear-gradient(180deg,var(--purple),var(--teal));min-height:12px;position:relative}
.timeline-bar span{position:absolute;bottom:-22px;left:50%;transform:translateX(-50%);font-family:var(--mono);font-size:10px;color:var(--text3)}
@media(max-width:900px){.decision-grid,.tier-grid{grid-template-columns:1fr}}
</style>
"""
if 'tsm-howto-decision-css' not in html:
    html = html.replace('</head>', css + '\n</head>')

sections = """
  <section class="guide-section" id="decision">
    <div class="section-eyebrow"><span class="section-num">10</span><span class="section-tag" style="color:var(--teal);">🧠 Decision Engine</span></div>
    <h2 class="section-title">Decision Mode — Choosing the Best Option</h2>
    <p class="section-desc">Music Command now helps you decide which creative direction is strongest. Revision Mode generates three strategic options, scores them, recommends the best one, and gives you a clear next move.</p>
    <div class="decision-grid">
      <div class="decision-card recommended"><div class="decision-kicker">Recommended</div><div class="decision-title">Option A · Flow First</div><p>Best when the draft needs bounce, pocket, rhythm, and cleaner phrasing.</p><div class="decision-score">Cadence + hook potential</div></div>
      <div class="decision-card"><div class="decision-kicker">Emotion Path</div><div class="decision-title">Option B · Emotion First</div><p>Best when the song needs more vulnerability, imagery, and emotional center.</p><div class="decision-score">Emotion + imagery</div></div>
      <div class="decision-card"><div class="decision-kicker">Structure Path</div><div class="decision-title">Option C · Hook First</div><p>Best when the idea needs better hook position, transitions, or repeatability.</p><div class="decision-score">Structure + release readiness</div></div>
    </div>
    <div class="tip-box teal"><div class="tip-label">New mental model</div>The three options are strategic directions: flow, emotion, and structure. You are choosing the strongest direction before the system reruns and improves it.</div>
  </section>

  <section class="guide-section" id="loop">
    <div class="section-eyebrow"><span class="section-num">11</span><span class="section-tag" style="color:var(--purple);">🔁 Iteration Loop</span></div>
    <h2 class="section-title">The Real Workflow — Pick → Rerun → Improve</h2>
    <p class="section-desc">Generate options, choose the strongest one, then run it back through ZAY, RIYA, and DJ. The selected version becomes the new working draft and the system tracks improvement.</p>
    <div class="workflow-list">
      <div class="workflow-step"><div class="wf-title">Step 1 — Generate 3 revision options</div><div class="wf-desc">The system creates Flow First, Emotion First, and Hook First paths.</div></div>
      <div class="workflow-step"><div class="wf-title">Step 2 — Review scores</div><div class="wf-desc">Check cadence, emotion, structure, imagery, and overall score.</div></div>
      <div class="workflow-step"><div class="wf-title">Step 3 — Pick + Run Again</div><div class="wf-desc">Your selected option reruns through the multi-agent chain and stores learning into Artist DNA.</div></div>
      <div class="workflow-step"><div class="wf-title">Step 4 — Track evolution</div><div class="wf-desc">Use the timeline to see whether the song improves, stalls, or needs a new hook direction.</div></div>
    </div>
  </section>

  <section class="guide-section" id="evolution">
    <div class="section-eyebrow"><span class="section-num">12</span><span class="section-tag" style="color:var(--gold);">📈 Hit Trajectory</span></div>
    <h2 class="section-title">Evolution Timeline & Release Decision</h2>
    <p class="section-desc">The Evolution Timeline shows score movement across runs, tracks Artist DNA learning, and gives a release decision.</p>
    <div class="timeline-demo"><div class="decision-kicker">Example Hit Trajectory</div><div class="timeline-bars"><div class="timeline-bar" style="height:62%;"><span>62</span></div><div class="timeline-bar" style="height:70%;"><span>70</span></div><div class="timeline-bar" style="height:79%;"><span>79</span></div><div class="timeline-bar" style="height:86%;"><span>86</span></div></div></div>
    <div class="decision-grid">
      <div class="decision-card"><div class="decision-kicker">Below 74%</div><div class="decision-title">Scrap / Rework Hook</div><p>The idea may still be useful, but the hook or structure needs a reset.</p></div>
      <div class="decision-card recommended"><div class="decision-kicker">74%–85%</div><div class="decision-title">Iterate Again</div><p>The song is promising. Run another selected pass and watch the score.</p></div>
      <div class="decision-card"><div class="decision-kicker">86%+</div><div class="decision-title">Release Ready</div><p>Move toward recording, arrangement, campaign assets, or release planning.</p></div>
    </div>
  </section>

  <section class="guide-section" id="tiers">
    <div class="section-eyebrow"><span class="section-num">13</span><span class="section-tag" style="color:var(--purple);">💳 Plans + Upgrades</span></div>
    <h2 class="section-title">How the System Grows With You</h2>
    <p class="section-desc">The tiers are built around creative volume and decision power: more iterations, more saved sessions, exports, and deeper Artist DNA memory.</p>
    <div class="tier-grid">
      <div class="tier-card"><div class="decision-kicker">Preview</div><div class="decision-title">Free Trial</div><div class="tier-price">$0/mo</div><div class="tier-copy">5 AI iterations, 1 project, no exports. Best for testing how the system thinks.</div></div>
      <div class="tier-card featured"><div class="decision-kicker">Creator</div><div class="decision-title">Creator Mode</div><div class="tier-price">$99/mo</div><div class="tier-copy">25 iterations, 5 projects, DAW-ready TXT export, Revision Mode, and basic Artist DNA.</div></div>
      <div class="tier-card featured"><div class="decision-kicker">Studio</div><div class="decision-title">Studio Mode</div><div class="tier-price">$249/mo</div><div class="tier-copy">100 iterations, 25 projects, evolution timeline, hit trajectory, and decision advantage.</div></div>
      <div class="tier-card"><div class="decision-kicker">Label</div><div class="decision-title">Label Mode</div><div class="tier-price">$499/mo</div><div class="tier-copy">500 iterations, 100 projects, deep catalog memory, release decision engine, and team scale.</div></div>
    </div>
    <div class="decision-grid">
      <div class="decision-card"><div class="decision-title">Generate 10 Hooks · $25</div><p>Use when the concept is strong but the hook is not landing yet.</p></div>
      <div class="decision-card"><div class="decision-title">Commercial Rewrite · $30</div><p>Use when a draft needs a more accessible, record-ready angle.</p></div>
      <div class="decision-card"><div class="decision-title">Radio Polish · $25</div><p>Use when the song needs final clarity, structure, and hook tightening.</p></div>
    </div>
  </section>
"""

html = re.sub(r'\s*<section class="guide-section" id="decision">.*?<section class="guide-section" id="tips">', '\n  <section class="guide-section" id="tips">', html, flags=re.S)

marker = '<section class="guide-section" id="tips">'
if marker not in html:
    raise SystemExit("Could not find tips marker")

html = html.replace(marker, sections + "\n\n  " + marker)
html = html.replace('Start with Artist DNA → then build your first skeleton → then draft your hook.',
                    'Start with Artist DNA → generate options → pick the best path → rerun → track your hit trajectory.')

p.write_text(html, encoding="utf-8")
print("patched how-to guide")
PY

git add "$FILE"
git commit -m "Update Music How-To guide for decision engine and tiers" || true
git push origin main
fly deploy --local-only
