const express = require('express');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/version', (req, res) => {
  res.json({
    solution: 'SecureKubeOps',
    component: 'reference-api',
    version: '0.1.0',
    purpose: 'Reference API for validating the SecureKubeOps DevSecOps solution'
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
  console.log(`SecureKubeOps reference API listening on port ${port}`);
});
