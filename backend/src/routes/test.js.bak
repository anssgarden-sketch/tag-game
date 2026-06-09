const router = require('express').Router();
const supabase = require('../services/supabase');
const { runApRegen, expireTags } = require('../jobs/apRegen');
const authMiddleware = require('../middleware/auth');

// Manually trigger AP regen -- for testing only
router.post('/trigger-ap-regen', async (req, res) => {
  await runApRegen();
  await expireTags();
  res.json({ message: 'AP regen triggered' });
});

// Drain AP for testing
router.post('/drain-ap', authMiddleware, async (req, res) => {
  try {
    const account_id = req.account.account_id;

    const { data: character } = await supabase
      .from('characters')
      .select('id')
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (!character) {
      return res.status(404).json({ error: 'No living character' });
    }

    const { data: ap } = await supabase
      .from('action_points')
      .select('id, current_ap, max_ap')
      .eq('character_id', character.id)
      .single();

    // Drain by 2
    const newAp = Math.max(0, ap.current_ap - 2);

    await supabase
      .from('action_points')
      .update({ current_ap: newAp })
      .eq('id', ap.id);

    res.json({ 
      message: `AP drained`,
      before: ap.current_ap,
      after: newAp,
      max: ap.max_ap
    });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;