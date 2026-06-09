const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:5173',
  credentials: true
}));
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    game: 'TAG: The Assassination Game',
    timestamp: new Date().toISOString()
  });
});

// Routes
app.use('/api', require('./routes/index'));

// Start scheduled jobs
const { startApRegenJob } = require('./jobs/apRegen');
startApRegenJob();

// Start server
app.listen(PORT, () => {
  console.log(`TAG server running on port ${PORT}`);
});

module.exports = app;
