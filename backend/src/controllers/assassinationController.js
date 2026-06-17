const supabase = require('../services/supabase');

// Can this assassination skill reach the target given city relationship?
// Close/Short/Medium/Long = same city only (hard cap per design doc)
// Remote = any city
function skillCanExecute(skillRange, attackerCityId, targetCityId) {
  if (skillRange === 'remote') return true;
  return attackerCityId === targetCityId;
}

// POST /api/assassination/execute
async function execute(req, res) {
  try {
    const account_id = req.account.account_id;
    const { target_character_id, skill_id } = req.body;

    if (!target_character_id || !skill_id) {
      return res.status(400).json({ error: 'target_character_id and skill_id are required' });
    }

    // ── 1. Load attacker ──────────────────────────────────────────
    const { data: attacker, error: attackerError } = await supabase
      .from('characters')
      .select(`
        id, name, credits, current_city_id, account_id, kill_count,
        cities!current_city_id(id, name, country),
        action_points(current_ap, max_ap)
      `)
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (attackerError || !attacker) {
      return res.status(404).json({ error: 'No living character found' });
    }

    const apRow = Array.isArray(attacker.action_points)
      ? attacker.action_points[0]
      : attacker.action_points;

    if (!apRow) {
      return res.status(500).json({ error: 'Action points record missing' });
    }

    const attackerCity = Array.isArray(attacker.cities)
      ? attacker.cities[0]
      : attacker.cities;

    // ── 2. Cannot target yourself ─────────────────────────────────
    if (attacker.id === target_character_id) {
      return res.status(400).json({ error: 'You cannot target yourself' });
    }

    // ── 3. Verify assassination skill ─────────────────────────────
    const { data: hasSkill } = await supabase
      .from('character_skills')
      .select('id')
      .eq('character_id', attacker.id)
      .eq('skill_id', skill_id)
      .eq('pool', 'assassination')
      .single();

    if (!hasSkill) {
      return res.status(400).json({ error: 'You do not have this Assassination skill' });
    }

    const { data: skill } = await supabase
      .from('skills')
      .select('*')
      .eq('id', skill_id)
      .single();

    if (!skill || skill.category !== 'assassination') {
      return res.status(400).json({ error: 'Invalid assassination skill' });
    }

    // ── 4. Load target ────────────────────────────────────────────
    const { data: target, error: targetError } = await supabase
      .from('characters')
      .select(`
        id, name, credits, current_city_id, account_id, is_alive,
        cities!current_city_id(id, name, country),
        action_points(current_ap, max_ap),
        character_skills!inner(skill_id, pool)
      `)
      .eq('id', target_character_id)
      .eq('is_alive', true)
      .single();

    if (targetError || !target) {
      return res.status(404).json({ error: 'Target not found or already dead' });
    }

    const targetCity = Array.isArray(target.cities)
      ? target.cities[0]
      : target.cities;

    // ── 5. Check active tag exists ────────────────────────────────
    const { data: tag } = await supabase
      .from('tags')
      .select('id, expires_at')
      .eq('attacker_character_id', attacker.id)
      .eq('target_character_id', target.id)
      .eq('is_active', true)
      .maybeSingle();

    if (!tag) {
      return res.status(400).json({
        error: 'No active tag on this target — run Intel search first'
      });
    }

    // Check tag hasn't expired
    if (new Date(tag.expires_at) < new Date()) {
      await supabase
        .from('tags')
        .update({ is_active: false })
        .eq('id', tag.id);

      return res.status(400).json({
        error: 'Your tag on this target has expired — run Intel search again'
      });
    }

    // ── 6. Check skill range vs city positions ────────────────────
    if (!skillCanExecute(skill.range, attacker.current_city_id, target.current_city_id)) {
      return res.status(400).json({
        error: `${skill.name} requires you to be in the same city as your target. ` +
               `You are in ${attackerCity.name}, target is in ${targetCity.name}.`
      });
    }

    // ── 7. Check AP and credits ───────────────────────────────────
    const currentAp = apRow.current_ap;
    if (currentAp < skill.base_ap_cost) {
      return res.status(400).json({
        error: `Insufficient AP. Need ${skill.base_ap_cost}, have ${currentAp}`
      });
    }

    if (attacker.credits < skill.base_credit_cost) {
      return res.status(400).json({
        error: `Insufficient credits. Need $${skill.base_credit_cost}, have $${attacker.credits}`
      });
    }

    // ── 8. Resolve outcome — PURE COMPUTATION, NO WRITES YET ───────
    // Everything from here to the log insert is decided in memory first.
    // Nothing is written to the DB until we know exactly what happened,
    // so a crash before the log insert means NOTHING changed — safe to retry.
    const isRemote = skill.range === 'remote';
    const sameCityKill = attacker.current_city_id === target.current_city_id;

    const targetDefensiveSkills = (target.character_skills || [])
      .filter(s => s.pool === 'defensive')
      .map(s => s.skill_id);

    const isBlocked = targetDefensiveSkills.includes(skill_id);

    const targetApRow = Array.isArray(target.action_points)
      ? target.action_points[0]
      : target.action_points;

    let outcome;
    let counterWillSucceed = false;

    if (isBlocked && !isRemote && sameCityKill) {
      const targetHasAp = targetApRow && targetApRow.current_ap >= 1;
      const targetHasCredits = target.credits >= skill.base_credit_cost;

      if (targetHasAp && targetHasCredits) {
        outcome = 'counter_attacked';
        counterWillSucceed = true;
      } else {
        outcome = 'survived';
      }
    } else {
      // Remote kills cannot be countered even if defense matches.
      // No counter possible cross-city either.
      outcome = 'killed';
    }

    // ── 9. WRITE PHASE 1: deduct attacker AP/credits + log attempt ─
    // This is the durable record of "this action happened with this outcome."
    // If anything below this point fails, we at least know what should
    // have occurred and can reconcile manually or via a recovery job.
    const { error: apDeductError } = await supabase
      .from('action_points')
      .update({
        current_ap: currentAp - skill.base_ap_cost,
        updated_at: new Date().toISOString()
      })
      .eq('character_id', attacker.id);

    if (apDeductError) {
      console.error('AP deduct error:', apDeductError);
      return res.status(500).json({ error: 'Failed to deduct AP' });
    }

    const { error: creditDeductError } = await supabase
      .from('characters')
      .update({ credits: attacker.credits - skill.base_credit_cost })
      .eq('id', attacker.id);

    if (creditDeductError) {
      console.error('Credit deduct error:', creditDeductError);
      return res.status(500).json({ error: 'Failed to deduct credits' });
    }

    // Deactivate tag now — it's consumed regardless of outcome
    await supabase
      .from('tags')
      .update({ is_active: false })
      .eq('id', tag.id);

    // Log the attempt — this is the source of truth going forward
    const { data: loggedAttempt, error: logError } = await supabase
      .from('assassination_attempts')
      .insert({
        attacker_character_id: attacker.id,
        target_character_id: target.id,
        skill_id,
        city_id: attacker.current_city_id,
        tag_id: tag.id,
        outcome,
        ap_spent: skill.base_ap_cost,
        credits_spent: skill.base_credit_cost,
        was_queued: false
      })
      .select('id')
      .single();

    if (logError) {
      console.error('Attempt log error:', logError);
      // AP/credits already spent and tag consumed at this point.
      // Outcome is not yet applied to characters table. Surface clearly
      // rather than silently continuing into character mutation.
      return res.status(500).json({
        error: 'Attempt could not be logged. AP and credits were spent but the kill was not applied. Contact support with this attacker ID: ' + attacker.id
      });
    }

    // ── 10. WRITE PHASE 2: apply consequences to characters ────────
    // Outcome is fixed and logged. From here we just apply it.
    let counterAttackResult = null;

    if (outcome === 'killed') {
      await supabase
        .from('characters')
        .update({
          is_alive: false,
          killed_by_account_id: account_id,
          killed_with_skill_id: skill_id
        })
        .eq('id', target.id);

      await supabase
        .from('characters')
        .update({ kill_count: (attacker.kill_count || 0) + 1 })
        .eq('id', attacker.id);

    } else if (outcome === 'counter_attacked') {
      await supabase
        .from('action_points')
        .update({
          current_ap: targetApRow.current_ap - 1,
          updated_at: new Date().toISOString()
        })
        .eq('character_id', target.id);

      await supabase
        .from('characters')
        .update({ credits: target.credits - skill.base_credit_cost })
        .eq('id', target.id);

      await supabase
        .from('characters')
        .update({
          is_alive: false,
          killed_by_account_id: target.account_id,
          killed_with_skill_id: skill_id
        })
        .eq('id', attacker.id);

      counterAttackResult = {
        counter_attacker: target.name,
        attacker_killed: true
      };
    }
    // 'survived' outcome requires no further character mutation

    // ── 11. Ticker event (best-effort, non-critical) ────────────────
    if (outcome === 'killed' || outcome === 'counter_attacked') {
      const deadCity = outcome === 'killed' ? targetCity.name : attackerCity.name;
      const deadCityId = outcome === 'killed' ? target.current_city_id : attacker.current_city_id;

      try {
        await supabase
          .from('ticker_events')
          .insert({
            event_type: 'body_found',
            city_id: deadCityId,
            message: `An unidentified body was found in ${deadCity}.`
          });
      } catch (tickerErr) {
        console.error('Ticker event error (non-critical):', tickerErr);
      }
    }

    // ── 12. Build response ────────────────────────────────────────
    const response = {
      outcome,
      attempt_id: loggedAttempt.id,
      skill_used: skill.name,
      ap_spent: skill.base_ap_cost,
      credits_spent: skill.base_credit_cost,
      remaining_ap: currentAp - skill.base_ap_cost,
      remaining_credits: attacker.credits - skill.base_credit_cost,
      tag_consumed: true
    };

    if (outcome === 'killed') {
      response.message = isRemote
        ? `${target.name} has been eliminated. Your identity remains unknown.`
        : `${target.name} has been eliminated in ${targetCity.name}.`;
      response.target_alive = false;
    } else if (outcome === 'counter_attacked') {
      response.message = `${target.name} detected the attempt and counter-attacked. You are dead.`;
      response.target_alive = true;
      response.attacker_alive = false;
      response.counter_attack = counterAttackResult;
    } else if (outcome === 'survived') {
      response.message = `${target.name} survived — their defenses blocked your attempt.`;
      response.target_alive = true;
    }

    return res.json(response);

  } catch (err) {
    console.error('Assassination execute error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

// GET /api/assassination/attempts
// View your assassination attempt history
async function getAttempts(req, res) {
  try {
    const account_id = req.account.account_id;

    const { data: character } = await supabase
      .from('characters')
      .select('id')
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (!character) {
      return res.status(404).json({ error: 'No living character found' });
    }

    const { data: attempts, error } = await supabase
      .from('assassination_attempts')
      .select(`
        id, outcome, ap_spent, credits_spent, was_queued, attempted_at,
        skills!skill_id(name, range),
        cities!city_id(name, country),
        characters!target_character_id(name, is_alive)
      `)
      .eq('attacker_character_id', character.id)
      .order('attempted_at', { ascending: false })
      .limit(20);

    if (error) {
      console.error('Get attempts error:', error);
      return res.status(500).json({ error: 'Failed to retrieve attempts' });
    }

    return res.json({
      attempts: attempts || [],
      count: attempts?.length || 0
    });

  } catch (err) {
    console.error('Get attempts error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { execute, getAttempts };
