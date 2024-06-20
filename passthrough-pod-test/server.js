const https = require('https');
const fs = require('fs');
const express = require('express');
const app = express();

// Load the wildcard certificate and private key
const privateKey = fs.readFileSync('/path/to/private-key.pem', 'utf8');
const certificate = fs.readFileSync('/path/to/wildcard-cert.pem', 'utf8');
const credentials = { key: privateKey, cert: certificate };

// Create HTTPS server
const httpsServer = https.createServer(credentials, app);

// Define routes
app.get('/', (req, res) => {
  res.send('Hello World\n');
});

// Listen on port 443
httpsServer.listen(443, () => {
  console.log('HTTPS server running on port 443');
});