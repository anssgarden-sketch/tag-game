const router = require('express').Router();

router.get('/status', (req, res) => {
  res.json({ message: 'TAG API is live' });
});

router.use('/auth', require('./auth'));

module.exports = router;