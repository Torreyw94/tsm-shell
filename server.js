const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());
app.get('/api/status', (req, res) => {
    res.json({ 
        status: "SOVEREIGN ONLINE",
        valuation: "$600,000",
        bridge: "CONNECTED"
    });
});

app.use(express.static(__dirname));
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});
app.listen(PORT);
