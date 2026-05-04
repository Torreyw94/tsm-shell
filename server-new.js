const express = require('express');
const path = require('path');
const app = express();

app.use(express.json({ limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'html')));
app.use(express.static(path.join(__dirname, 'public')));

// Suite routers
app.use('/api/hc', require('./servers/healthcare'));

// Static suite routes
app.get('/suite/healthcare', (req,res) => res.sendFile(path.join(__dirname,'html/healthcare/index.html')));
app.get('/suite/finops', (req,res) => res.sendFile(path.join(__dirname,'html/finops-suite/copilot.html')));
app.get('/suite/insurance', (req,res) => res.sendFile(path.join(__dirname,'html/tsm-insurance/az-ins.html')));

// Fallback
app.use((req, res) => res.status(404).send('Not found: ' + req.path));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log('TSM server on port ' + PORT));
