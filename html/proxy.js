const http = require('http');
const httpProxy = require('http-proxy');

const proxy = httpProxy.createProxyServer({});

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, PUT, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  console.log(`📡 Proxying ${req.method} request to TSM-Core...`);
  proxy.web(req, res, { target: 'http://127.0.0.1:3200' });
});

console.log("🚀 AI Logic Proxy Active on Port 3201");
server.listen(3201);
