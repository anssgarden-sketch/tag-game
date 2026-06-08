const router = require('express').Router();
const { 
  getCreationData, 
  createCharacter, 
  getMyCharacter 
} = require('../controllers/characterController');
const authMiddleware = require('../middleware/auth');

// All character routes require authentication
router.use(authMiddleware);

router.get('/creation-data', getCreationData);
router.post('/create', createCharacter);
router.get('/me', getMyCharacter);

module.exports = router;
