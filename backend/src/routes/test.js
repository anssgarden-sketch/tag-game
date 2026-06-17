const router = require('express').Router();
const supabase = require('../services/supabase');
const { runApRegen, expireTags } = require('../jobs/apRegen');
const authMiddleware = require('../middleware/auth');

// Trigger AP regen manually
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

    const newAp = Math.max(0, ap.current_ap - 2);
    await supabase
      .from('action_points')
      .update({ current_ap: newAp })
      .eq('id', ap.id);

    res.json({
      message: 'AP drained',
      before: ap.current_ap,
      after: newAp,
      max: ap.max_ap
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Top up credits for testing
router.post('/topup-credits', authMiddleware, async (req, res) => {
  try {
    const account_id = req.account.account_id;
    const { data: character } = await supabase
      .from('characters')
      .select('id, credits')
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (!character) {
      return res.status(404).json({ error: 'No living character' });
    }

    await supabase
      .from('characters')
      .update({ credits: character.credits + 2000 })
      .eq('id', character.id);

    res.json({
      message: 'Credits topped up',
      before: character.credits,
      after: character.credits + 2000
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});


// ── Add this route to /workspaces/tag-game/backend/src/routes/test.js ──
// Paste it just before `module.exports = router;`

// Resurrect a dead character for testing — restores full AP, keeps skills
router.post('/resurrect', authMiddleware, async (req, res) => {
  try {
    const account_id = req.account.account_id;

    // Find the account's most recently created character, dead or alive
    const { data: character, error: charError } = await supabase
      .from('characters')
      .select('id, name, is_alive, credits')
      .eq('account_id', account_id)
      .order('id', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (charError || !character) {
      return res.status(404).json({ error: 'No character found for this account at all' });
    }

    if (character.is_alive) {
      return res.status(400).json({ error: `${character.name} is already alive — nothing to resurrect` });
    }

    // Revive: clear death fields, restore is_alive
    const { error: reviveError } = await supabase
      .from('characters')
      .update({
        is_alive: true,
        killed_by_account_id: null,
        killed_with_skill_id: null
      })
      .eq('id', character.id);

    if (reviveError) {
      console.error('Resurrect error:', reviveError);
      return res.status(500).json({ error: 'Failed to resurrect character' });
    }

    // Restore AP to max
    const { data: apRow } = await supabase
      .from('action_points')
      .select('max_ap')
      .eq('character_id', character.id)
      .single();

    if (apRow) {
      await supabase
        .from('action_points')
        .update({
          current_ap: apRow.max_ap,
          updated_at: new Date().toISOString()
        })
        .eq('character_id', character.id);
    }

    // Deactivate any stale tags pointing at or from this character,
    // since tags reference a specific death/life cycle and shouldn't
    // carry over uncleared after a test resurrection
    await supabase
      .from('tags')
      .update({ is_active: false })
      .eq('target_character_id', character.id)
      .eq('is_active', true);

    await supabase
      .from('tags')
      .update({ is_active: false })
      .eq('attacker_character_id', character.id)
      .eq('is_active', true);

    res.json({
      message: `${character.name} has been resurrected for testing`,
      character_id: character.id,
      ap_restored_to: apRow ? apRow.max_ap : null,
      stale_tags_cleared: true
    });

  } catch (err) {
    console.error('Resurrect error:', err);
    res.status(500).json({ error: err.message });
  }
});


module.exports = router;