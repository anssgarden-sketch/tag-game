const supabase = require('../services/supabase');

// Calculate pixel distance between two cities
function pixelDistance(city1, city2) {
  const dx = city2.map_x - city1.map_x;
  const dy = city2.map_y - city1.map_y;
  return Math.sqrt(dx * dx + dy * dy);
}

// Get range tier of a city pair
function getRangeTier(attackerCity, targetCity) {
  if (attackerCity.id === targetCity.id) return 'same_city';
  if (attackerCity.country === targetCity.country) return 'same_country';
  if (attackerCity.continent === targetCity.continent) return 'same_continent';
  return 'cross_continent';
}

// Check if skill range covers the target city
function skillCoversRange(skillRange, rangeTier) {
  const rangeLevels = {
    'city':      1,
    'country':   2,
    'continent': 3,
    'global':    4
  };
  const skillLevel = rangeLevels[skillRange] || 1;
  const requiredLevel = {
    'same_city':       1,
    'same_country':    2,
    'same_continent':  3,
    'cross_continent': 4
  }[rangeTier];
  return skillLevel >= requiredLevel;
}

// Get cost multipliers from game config
async function getCostMultipliers() {
  const { data: config } = await supabase
    .from('game_config')
    .select('key, value')
    .in('key', [
      'intel_range_mod_same_country',
      'intel_range_mod_same_continent',
      'intel_range_mod_cross_continent',
      'intel_sweep_mod'
    ]);

  const cfg = {};
  config.forEach(row => { cfg[row.key] = parseFloat(row.value); });

  return {
    same_city:       1.0,
    same_country:    cfg['intel_range_mod_same_country']    || 2.0,
    same_continent:  cfg['intel_range_mod_same_continent']  || 3.0,
    cross_continent: cfg['intel_range_mod_cross_continent'] || 4.0,
    sweep:           cfg['intel_sweep_mod']                 || 5.0
  };
}

// POST /api/intel/search
// Single target search
async function searchTarget(req, res) {
  try {
    const account_id = req.account.account_id;
    const { target_name, target_city_id, skill_id, is_sweep } = req.body;

    if (!target_city_id || !skill_id) {
      return res.status(400).json({
        error: 'Target city and skill are required'
      });
    }

    if (!is_sweep && !target_name) {
      return res.status(400).json({
        error: 'Target name is required for single target search'
      });
    }

    // Get attacker's living character
    const { data: attacker, error: attackerError } = await supabase
      .from('characters')
      .select(`
        id, name, credits,
        current_city_id,
        cities!current_city_id(id, name, country, continent, map_x, map_y),
        action_points(current_ap, max_ap)
      `)
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (attackerError || !attacker) {
      return res.status(404).json({ error: 'No living character found' });
    }

    // Verify attacker has this intel skill
    const { data: hasSkill } = await supabase
      .from('character_skills')
      .select('id')
      .eq('character_id', attacker.id)
      .eq('skill_id', skill_id)
      .eq('pool', 'intel')
      .single();

    if (!hasSkill) {
      return res.status(400).json({
        error: 'You do not have this Intel skill'
      });
    }

    // Get the skill details
    const { data: skill } = await supabase
      .from('skills')
      .select('*')
      .eq('id', skill_id)
      .single();

    if (!skill) {
      return res.status(400).json({ error: 'Skill not found' });
    }

    // Get target city details
    const { data: targetCity } = await supabase
      .from('cities')
      .select('id, name, country, continent, map_x, map_y')
      .eq('id', target_city_id)
      .single();

    if (!targetCity) {
      return res.status(400).json({ error: 'Target city not found' });
    }

    const attackerCity = attacker.cities;

    // Check skill range covers target city
    const rangeTier = getRangeTier(attackerCity, targetCity);
    if (!skillCoversRange(skill.range, rangeTier)) {
      return res.status(400).json({
        error: `Your ${skill.name} skill cannot reach ${targetCity.name} — skill range is ${skill.range}`
      });
    }

    // Calculate cost
    const multipliers = await getCostMultipliers();
    const rangeMod = multipliers[rangeTier];
    const sweepMod = is_sweep ? multipliers.sweep : 1.0;

    const apCost = Math.ceil(skill.base_ap_cost * rangeMod * sweepMod);
    const creditCost = Math.ceil(skill.base_credit_cost * rangeMod * sweepMod);

    // Check attacker has enough AP
    const currentAp = attacker.action_points.current_ap;
    if (currentAp < apCost) {
      return res.status(400).json({
        error: `Insufficient AP. Need ${apCost}, have ${currentAp}`
      });
    }

    // Check attacker has enough credits
    if (attacker.credits < creditCost) {
      return res.status(400).json({
        error: `Insufficient credits. Need $${creditCost}, have $${attacker.credits}`
      });
    }

    // Deduct AP and credits
    await supabase
      .from('action_points')
      .update({ current_ap: currentAp - apCost })
      .eq('character_id', attacker.id);

    await supabase
      .from('characters')
      .update({ credits: attacker.credits - creditCost })
      .eq('id', attacker.id);

    // Find targets in the city
    let targetQuery = supabase
      .from('characters')
      .select(`
        id, name,
        current_city_id,
        travel_status,
        destination_city_id,
        arrives_at,
        cities!current_city_id(id, name, country, continent),
        character_skills(pool, skill_id)
      `)
      .eq('is_alive', true)
      .neq('account_id', account_id);

    if (is_sweep) {
      // Sweep -- find all characters in target city
      // Include in-transit characters whose departure city is target city
      targetQuery = targetQuery.or(
        `current_city_id.eq.${target_city_id},and(travel_status.eq.in_transit,current_city_id.eq.${target_city_id})`
      );
    } else {
      // Single target -- find by name
      targetQuery = targetQuery
        .ilike('name', target_name.trim())
        .or(
          `current_city_id.eq.${target_city_id},and(travel_status.eq.in_transit,current_city_id.eq.${target_city_id})`
        );
    }

    const { data: potentialTargets, error: targetError } = await targetQuery;

    if (targetError) {
      console.error('Target search error:', targetError);
      return res.status(500).json({ error: 'Search failed' });
    }

    // Run counter-intel check for each potential target
    const tagDurationHours = 48;
    const expiresAt = new Date(Date.now() + tagDurationHours * 60 * 60 * 1000).toISOString();
    const taggedTargets = [];
    const blockedCount = { count: 0 };

    for (const target of potentialTargets || []) {
      // Get target's counter-intel skills
      const { data: counterIntelSkills } = await supabase
        .from('character_skills')
        .select('skill_id')
        .eq('character_id', target.id)
        .eq('pool', 'counter_intel');

      const counterSkillIds = (counterIntelSkills || []).map(s => s.skill_id);

      // Check if target has exact counter to this intel skill
      const isBlocked = counterSkillIds.includes(skill_id);

      if (isBlocked) {
        blockedCount.count++;
        continue;
      }

      // Target is not protected -- tag them
      // Check if already tagged by this attacker
      const { data: existingTag } = await supabase
        .from('tags')
        .select('id')
        .eq('attacker_character_id', attacker.id)
        .eq('target_character_id', target.id)
        .eq('is_active', true)
        .single();

      if (existingTag) {
        // Refresh the tag
        await supabase
          .from('tags')
          .update({
            expires_at: expiresAt,
            tagged_in_city_id: target_city_id,
            intel_skill_used_id: skill_id
          })
          .eq('id', existingTag.id);
      } else {
        // Create new tag
        await supabase
          .from('tags')
          .insert({
            attacker_character_id: attacker.id,
            target_character_id: target.id,
            tagged_in_city_id: target_city_id,
            intel_skill_used_id: skill_id,
            expires_at: expiresAt,
            is_active: true
          });
      }

      taggedTargets.push({
        name: target.name,
        city: target.cities?.name,
        is_in_transit: target.travel_status === 'in_transit'
      });
    }

    // Build response
    const response = {
      message: is_sweep ? 'City sweep complete' : 'Search complete',
      skill_used: skill.name,
      target_city: targetCity.name,
      ap_spent: apCost,
      credits_spent: creditCost,
      remaining_ap: currentAp - apCost,
      remaining_credits: attacker.credits - creditCost
    };

    if (taggedTargets.length > 0) {
      response.tagged = taggedTargets;
      response.tagged_count = taggedTargets.length;
    } else {
      response.result = blockedCount.count > 0
        ? 'Search complete — no targets located'
        : 'No targets found in that city';
    }

    return res.json(response);

  } catch (err) {
    console.error('Intel search error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

// GET /api/intel/tags
// Get all active tags for the attacker
async function getMyTags(req, res) {
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

    const { data: tags, error } = await supabase
      .from('tags')
      .select(`
        id,
        tagged_at,
        expires_at,
        tagged_in_city_id,
        cities!tagged_in_city_id(name, country),
        characters!target_character_id(
          id, name, travel_status,
          cities!current_city_id(name, country)
        ),
        skills!intel_skill_used_id(name)
      `)
      .eq('attacker_character_id', character.id)
      .eq('is_active', true)
      .order('tagged_at', { ascending: false });

    if (error) {
      console.error('Get tags error:', error);
      return res.status(500).json({ error: 'Failed to retrieve tags' });
    }

    return res.json({
      active_tags: tags || [],
      count: tags?.length || 0
    });

  } catch (err) {
    console.error('Get tags error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { searchTarget, getMyTags };