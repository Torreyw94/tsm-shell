/**
 * tsm-ai-client.js
 * Drop this into any TSM app's static folder.
 *
 * Usage — 3 lines of HTML:
 *
 *   <script src="/tsm-ai-client.js"></script>
 *   <div id="tsm-ai"></div>           ← mounts the widget here
 *   <script>TSM_AI.mount('#tsm-ai')</script>
 *
 * Or headless (no built-in UI — use your own):
 *   const { ask } = TSM_AI.client();
 *   const reply = await ask("What plans do you offer?");
 *
 * The widget auto-detects window.location.hostname so each app gets
 * the right system prompt on the server — zero config per app.
 */

(function () {
  "use strict";

  const AI_ENDPOINT = "https://tsm-core.fly.dev/ai";

  // ── Core client ──────────────────────────────────────────────────────────────

  function createClient() {
    let history = []; // [{role:"user"|"assistant", content:string}]

    async function ask(userMessage) {
      history.push({ role: "user", content: userMessage });

      const res = await fetch(AI_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: history,
          origin: window.location.origin,
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(err.error || "AI request failed");
      }

      const data = await res.json();
      history.push({ role: "assistant", content: data.reply });
      return data.reply;
    }

    function reset() {
      history = [];
    }

    return { ask, reset, getHistory: () => [...history] };
  }

  // ── Widget renderer ──────────────────────────────────────────────────────────

  function mount(selector, options = {}) {
    const target = typeof selector === "string" ? document.querySelector(selector) : selector;
    if (!target) {
      console.error("[TSM-AI] mount: element not found:", selector);
      return;
    }

    const {
      placeholder = "Ask a question…",
      welcomeMessage = "Hi! How can I help you today?",
      accentColor = "#0057FF",
      fontFamily = "inherit",
    } = options;

    const client = createClient();

    // Styles
    const style = document.createElement("style");
    style.textContent = `
      .tsm-ai-widget {
        font-family: ${fontFamily};
        display: flex;
        flex-direction: column;
        gap: 0;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
        overflow: hidden;
        background: #fff;
        box-shadow: 0 4px 24px rgba(0,0,0,0.07);
        max-width: 640px;
      }
      .tsm-ai-messages {
        padding: 20px;
        min-height: 180px;
        max-height: 420px;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        gap: 12px;
        background: #f8fafc;
      }
      .tsm-ai-bubble {
        max-width: 86%;
        padding: 10px 14px;
        border-radius: 10px;
        font-size: 14px;
        line-height: 1.55;
        white-space: pre-wrap;
      }
      .tsm-ai-bubble.user {
        align-self: flex-end;
        background: ${accentColor};
        color: #fff;
        border-bottom-right-radius: 3px;
      }
      .tsm-ai-bubble.assistant {
        align-self: flex-start;
        background: #fff;
        color: #1a202c;
        border: 1px solid #e2e8f0;
        border-bottom-left-radius: 3px;
      }
      .tsm-ai-bubble.error {
        align-self: flex-start;
        background: #fff5f5;
        color: #c53030;
        border: 1px solid #fed7d7;
        font-size: 13px;
      }
      .tsm-ai-typing {
        align-self: flex-start;
        background: #fff;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        border-bottom-left-radius: 3px;
        padding: 10px 14px;
        display: flex;
        gap: 4px;
        align-items: center;
      }
      .tsm-ai-typing span {
        width: 6px; height: 6px;
        border-radius: 50%;
        background: #a0aec0;
        animation: tsm-bounce 1.2s infinite;
      }
      .tsm-ai-typing span:nth-child(2) { animation-delay: .2s; }
      .tsm-ai-typing span:nth-child(3) { animation-delay: .4s; }
      @keyframes tsm-bounce {
        0%, 80%, 100% { transform: translateY(0); }
        40% { transform: translateY(-5px); }
      }
      .tsm-ai-input-row {
        display: flex;
        border-top: 1px solid #e2e8f0;
        background: #fff;
      }
      .tsm-ai-input {
        flex: 1;
        border: none;
        outline: none;
        padding: 14px 16px;
        font-size: 14px;
        font-family: inherit;
        resize: none;
        background: transparent;
        color: #1a202c;
      }
      .tsm-ai-input::placeholder { color: #a0aec0; }
      .tsm-ai-send {
        border: none;
        background: ${accentColor};
        color: #fff;
        padding: 0 20px;
        cursor: pointer;
        font-size: 14px;
        font-weight: 600;
        transition: opacity .15s;
        white-space: nowrap;
      }
      .tsm-ai-send:hover { opacity: .88; }
      .tsm-ai-send:disabled { opacity: .4; cursor: default; }
      .tsm-ai-reset {
        border: none;
        background: none;
        color: #a0aec0;
        font-size: 11px;
        padding: 4px 12px;
        cursor: pointer;
        text-align: right;
        display: block;
        width: 100%;
        text-decoration: underline;
      }
      .tsm-ai-reset:hover { color: #718096; }
    `;
    document.head.appendChild(style);

    // Markup
    target.innerHTML = `
      <div class="tsm-ai-widget">
        <div class="tsm-ai-messages" id="tsm-ai-messages"></div>
        <div class="tsm-ai-input-row">
          <textarea class="tsm-ai-input" id="tsm-ai-input" rows="1"
            placeholder="${placeholder}"></textarea>
          <button class="tsm-ai-send" id="tsm-ai-send">Send</button>
        </div>
        <button class="tsm-ai-reset" id="tsm-ai-reset">Clear conversation</button>
      </div>
    `;

    const messagesEl = target.querySelector("#tsm-ai-messages");
    const inputEl = target.querySelector("#tsm-ai-input");
    const sendBtn = target.querySelector("#tsm-ai-send");
    const resetBtn = target.querySelector("#tsm-ai-reset");

    function addBubble(role, text) {
      const div = document.createElement("div");
      div.className = `tsm-ai-bubble ${role}`;
      div.textContent = text;
      messagesEl.appendChild(div);
      messagesEl.scrollTop = messagesEl.scrollHeight;
      return div;
    }

    function addTyping() {
      const div = document.createElement("div");
      div.className = "tsm-ai-typing";
      div.innerHTML = "<span></span><span></span><span></span>";
      messagesEl.appendChild(div);
      messagesEl.scrollTop = messagesEl.scrollHeight;
      return div;
    }

    async function submit() {
      const text = inputEl.value.trim();
      if (!text) return;
      inputEl.value = "";
      inputEl.style.height = "auto";
      sendBtn.disabled = true;

      addBubble("user", text);
      const typing = addTyping();

      try {
        const reply = await client.ask(text);
        typing.remove();
        addBubble("assistant", reply);
      } catch (err) {
        typing.remove();
        addBubble("error", "⚠ " + (err.message || "Something went wrong. Please try again."));
      } finally {
        sendBtn.disabled = false;
        inputEl.focus();
      }
    }

    sendBtn.addEventListener("click", submit);
    inputEl.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        submit();
      }
    });
    inputEl.addEventListener("input", () => {
      inputEl.style.height = "auto";
      inputEl.style.height = Math.min(inputEl.scrollHeight, 120) + "px";
    });
    resetBtn.addEventListener("click", () => {
      client.reset();
      messagesEl.innerHTML = "";
      if (welcomeMessage) addBubble("assistant", welcomeMessage);
    });

    // Welcome
    if (welcomeMessage) addBubble("assistant", welcomeMessage);

    return client;
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  window.TSM_AI = { mount, client: createClient };
})();
