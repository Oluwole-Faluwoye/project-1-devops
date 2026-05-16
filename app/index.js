const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send("DevOps Project 1 running 🚀");
});

app.listen(3000);