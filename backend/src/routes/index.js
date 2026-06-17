const router = require('express').Router();

router.get('/status', (req, res) => {
  res.json({ message: 'TAG API is live' });
});

router.use('/auth', require('./auth'));
router.use('/character', require('./character'));
router.use('/assassination', require('./assassination'));
router.use('/intel', require('./intel'));
router.use('/test', require('./test'));

module.exports = router;
