const router = require('express').Router();
const { searchTarget, getMyTags } = require('../controllers/intelController');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.post('/search', searchTarget);
router.get('/tags', getMyTags);

module.exports = router;
