const GROQ_API_KEY = process.env.GROQ_API_KEY;

module.exports = function(app) {
  app.post("/api/groq", async (req, res) => {
    const { messages, system } = req.body;
    if (!messages) return res.status(400).json({ error: "messages required" });
    try {
      const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${GROQ_API_KEY}`,
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: system ? [{ role: "system", content: system }, ...messages] : messages,
          temperature: 0.3,
          max_tokens: 1024,
        }),
      });
      const data = await response.json();
      res.json({ content: data.choices[0].message.content });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
};
