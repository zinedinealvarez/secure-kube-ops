const express = require('express');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/version', (req, res) => {
  res.json({
    name: 'SecureKubeOps',
    version: '0.1.0',
    purpose: 'Reference application for the DevSecOps pipeline of the TFG'
  });
});

app.get('/items', (req, res) => {
  res.json({
    items: [
      { id: 1, name: 'static-analysis-check' },
      { id: 2, name: 'container-scan-check' },
      { id: 3, name: 'security-gate-check' }
    ]
  });
});

app.listen(port, () => {
  console.log(`SecureKubeOps listening on port ${port}`);
});
