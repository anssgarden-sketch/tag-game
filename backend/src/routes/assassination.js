const router = require('express').Router();
const { execute, getAttempts } = require('../controllers/assassinationController');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.post('/execute', execute);
router.get('/attempts', getAttempts);

module.exports = router;