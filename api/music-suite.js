
module.exports = function(app){

  global.MUSIC_SUITE_STATE = global.MUSIC_SUITE_STATE || {
    updatedAt: new Date().toISOString(),
    artistsOnline: 12,
    releasesDropping: 3,
    monthlyStreams: "84M",
    revenueMTD: 847400,
    pipelineValue: 2400000,
    aiStatus: "online",
    activeWorkspace: "draft",
    agents: {
      zay: { name:"ZAY", role:"Cadence · Bounce · Live Feel", status:"online" },
      riya:{ name:"RIYA", role:"Word Choice · Imagery · Emotion", status:"online" },
      dj:  { name:"DJ", role:"Structure · Hook Placement · Transitions", status:"online" }
    },
    alerts: [
      { level:"urgent", title:"Artist K Contract", detail:"Renewal expires in 14 days" },
      { level:"high", title:"TikTok Viral Spike", detail:"Midnight Run has 8.2M uses" },
      { level:"high", title:"Royalty Dispute", detail:"Q4 2025 publisher discrepancy $28.4K" },
      { level:"ok", title:"Tour Confirmed", detail:"12 dates · $340K projected" }
    ],
    songs: [],
    actions: []
  };

  function state(){
    return global.MUSIC_SUITE_STATE;
  }

  app.get("/api/music/state", (_req, res) => {
    return res.json({ ok:true, state: state() });
  });

  app.post("/api/music/agent-pass", (req, res) => {
    const body = req.body || {};
    const draft = body.draft || "";
    const agent = body.agent || "full";
    const request = body.request || "Improve the draft";
    const priority = body.priority || "Catalog";

    const result = {
      ok:true,
      agent,
      priority,
      request,
      original:draft,
      output:
`AGENT PASS: ${agent.toUpperCase()}

Priority: ${priority}

Recommended direction:
1. Strengthen the emotional center of the first two lines.
2. Keep the plain-language pain, but sharpen the internal rhyme.
3. Build from conflict into motion so the hook feels inevitable.

Polished option:
Life been heavy, but I still move right through the fight
Every day a battle, still I turn the dark to light

Why it works:
The idea stays intact, but the phrasing becomes more musical, repeatable, and hook-ready.`,
      createdAt:new Date().toISOString()
    };

    state().actions.unshift({
      type:"agent-pass",
      agent,
      request,
      createdAt:result.createdAt
    });

    return res.json(result);
  });

  app.post("/api/music/strategy", (req, res) => {
    const prompt = (req.body && req.body.prompt) || "Build a music strategy";

    return res.json({
      ok:true,
      title:"Music Strategy Brief",
      prompt,
      answer:
`Best next move:

1. Use the viral signal first.
Turn the current attention into saves, follows, and repeatable audience capture.

2. Route the song through the agent stack.
ZAY checks cadence, RIYA sharpens imagery, DJ validates structure and hook placement.

3. Convert activity into revenue.
Prioritize sync, playlisting, short-form content, and release timing.

4. Save the final output into Song Bank.
This keeps the improved version connected to Artist DNA for future generation.`,
      createdAt:new Date().toISOString()
    });
  });

  app.post("/api/music/dna", (req, res) => {
    const body = req.body || {};
    const artist = body.artist || "Current Artist";
    const notes = body.notes || "";

    state().artistDNA = {
      artist,
      notes,
      updatedAt:new Date().toISOString(),
      status:"active"
    };

    return res.json({ ok:true, dna:state().artistDNA });
  });

  app.post("/api/music/song", (req, res) => {
    const body = req.body || {};
    const song = {
      id:Date.now(),
      title:body.title || "Untitled Song",
      draft:body.draft || "",
      status:"saved",
      createdAt:new Date().toISOString()
    };
    state().songs.unshift(song);
    return res.json({ ok:true, song, songs:state().songs });
  });

  app.get("/api/music/songs", (_req, res) => {
    return res.json({ ok:true, songs:state().songs });
  });

};
