const express = require('express');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/version', (req, res) => {
  res.json({
    name: 'secure-cicd-kubernetes-lab',
    version: '0.1.0',
    purpose: 'DevSecOps pipeline laboratory'
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
  console.log(`secure-cicd-kubernetes-lab listening on port ${port}`);
});
