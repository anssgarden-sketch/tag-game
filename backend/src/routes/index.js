const router = require('express').Router();

// Placeholder — routes will be added as we build each system
router.get('/status', (req, res) => {
  res.json({ message: 'TAG API is live' });
});

module.exports = router;
