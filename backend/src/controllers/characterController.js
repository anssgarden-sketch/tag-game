const supabase = require('../services/supabase');

async function getCreationData(req, res) {
  try {
    const [citiesRes, professionsRes, skillsRes] = await Promise.all([
      supabase.from('cities').select('id, name, country, continent').order('name'),
      supabase.from('professions').select('id, name, description, credits_per_week, ap_modifier, schedule_type').order('name'),
      supabase.from('skills').select('id, name, description, category, range, base_ap_cost, base_credit_cost').order('name')
    ]);

    if (citiesRes.error) throw citiesRes.error;
    if (professionsRes.error) throw professionsRes.error;
    if (skillsRes.error) throw skillsRes.error;

    const assassinationDefensive = skillsRes.data.filter(s => s.category === 'assassination');
    const intelCounterIntel = skillsRes.data.filter(s => s.category === 'intel');

    return res.json({
      cities: citiesRes.data,
      professions: professionsRes.data,
      skill_pools: {
        assassination_defensive: assassinationDefensive,
        intel_counter_intel: intelCounterIntel
      },
      rules: {
        assassination_slots: 3,
        defensive_slots: 10,
        intel_slots: 3,
        counter_intel_slots: 10
      }
    });
  } catch (err) {
    console.error('Creation data error:', err);
    return res.status(500).json({ error: 'Failed to load creation data' });
  }
}

async function createCharacter(req, res) {
  try {
    const account_id = req.account.account_id;
    const { name, city_id, profession_id, assassination_skills, defensive_skills, intel_skills, counter_intel_skills } = req.body;

    if (!name || !city_id || !profession_id) {
      return res.status(400).json({ error: 'Name, city and profession are required' });
    }

    if (!name.match(/^[a-zA-Z0-9 ]{2,30}$/)) {
      return res.status(400).json({ error: 'Name must be 2-30 characters, letters and numbers only' });
    }

    if (!assassination_skills || assassination_skills.length !== 3) {
      return res.status(400).json({ error: 'You must select exactly 3 Assassination skills' });
    }
    if (!defensive_skills || defensive_skills.length !== 10) {
      return res.status(400).json({ error: 'You must select exactly 10 Defensive skills' });
    }
    if (!intel_skills || intel_skills.length !== 3) {
      return res.status(400).json({ error: 'You must select exactly 3 Intel skills' });
    }
    if (!counter_intel_skills || counter_intel_skills.length !== 10) {
      return res.status(400).json({ error: 'You must select exactly 10 Counter-Intel skills' });
    }

    // No duplicates WITHIN each pool only
    if (new Set(assassination_skills).size !== assassination_skills.length) {
      return res.status(400).json({ error: 'Duplicate skills within Assassination pool' });
    }
    if (new Set(defensive_skills).size !== defensive_skills.length) {
      return res.status(400).json({ error: 'Duplicate skills within Defensive pool' });
    }
    if (new Set(intel_skills).size !== intel_skills.length) {
      return res.status(400).json({ error: 'Duplicate skills within Intel pool' });
    }
    if (new Set(counter_intel_skills).size !== counter_intel_skills.length) {
      return res.status(400).json({ error: 'Duplicate skills within Counter-Intel pool' });
    }

    // Check no existing living character
    const { data: existingChar } = await supabase
      .from('characters')
      .select('id')
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (existingChar) {
      return res.status(400).json({ error: 'You already have a living character' });
    }

    // Validate profession
    const { data: profession, error: profError } = await supabase
      .from('professions')
      .select('id, ap_modifier, credits_per_week, name')
      .eq('id', profession_id)
      .single();

    if (profError || !profession) {
      return res.status(400).json({ error: 'Invalid profession' });
    }

    // Validate city
    const { data: city, error: cityError } = await supabase
      .from('cities')
      .select('id, name')
      .eq('id', city_id)
      .single();

    if (cityError || !city) {
      return res.status(400).json({ error: 'Invalid city' });
    }

    // Get config values
    const { data: configRow } = await supabase.from('game_config').select('value').eq('key', 'starting_credits').single();
    const starting_credits = parseInt(configRow?.value || '500');

    const { data: baseApRow } = await supabase.from('game_config').select('value').eq('key', 'base_ap').single();
    const base_ap = parseInt(baseApRow?.value || '4');
    const max_ap = base_ap + profession.ap_modifier;

    // Create character
    const { data: character, error: charError } = await supabase
      .from('characters')
      .insert({
        account_id,
        name,
        is_alive: true,
        credits: starting_credits,
        current_city_id: city_id,
        profession_id,
        travel_status: 'arrived',
        kill_count: 0,
        intel_sold_count: 0,
        items_sold_count: 0,
        survival_days: 0
      })
      .select('*')
      .single();

    if (charError) {
      console.error('Character creation error:', charError);
      return res.status(500).json({ error: 'Failed to create character' });
    }

    // Create action points
    const { error: apError } = await supabase
      .from('action_points')
      .insert({
        character_id: character.id,
        current_ap: max_ap,
        max_ap,
        last_regen_at: new Date().toISOString()
      });

    if (apError) {
      console.error('AP creation error:', apError);
      return res.status(500).json({ error: 'Failed to create action points' });
    }

    // Save skill selections
    const skillInserts = [
      ...assassination_skills.map(skill_id => ({ character_id: character.id, skill_id, pool: 'assassination' })),
      ...defensive_skills.map(skill_id => ({ character_id: character.id, skill_id, pool: 'defensive' })),
      ...intel_skills.map(skill_id => ({ character_id: character.id, skill_id, pool: 'intel' })),
      ...counter_intel_skills.map(skill_id => ({ character_id: character.id, skill_id, pool: 'counter_intel' }))
    ];

    const { error: skillsError } = await supabase.from('character_skills').insert(skillInserts);

    if (skillsError) {
      console.error('Skills save error:', skillsError);
      return res.status(500).json({ error: 'Failed to save skill selections' });
    }

    return res.status(201).json({
      message: 'Character created successfully',
      character: {
        id: character.id,
        name: character.name,
        is_alive: character.is_alive,
        credits: character.credits,
        current_city: city.name,
        profession: {
          name: profession.name,
          credits_per_week: profession.credits_per_week,
          ap_modifier: profession.ap_modifier
        },
        action_points: {
          current: max_ap,
          max: max_ap
        },
        skills: {
          assassination: assassination_skills,
          defensive: defensive_skills,
          intel: intel_skills,
          counter_intel: counter_intel_skills
        }
      }
    });

  } catch (err) {
    console.error('Create character error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

async function getMyCharacter(req, res) {
  try {
    const account_id = req.account.account_id;

    const { data: character, error } = await supabase
      .from('characters')
      .select(`
        *,
        cities!current_city_id(name, country, continent),
        professions(name, credits_per_week, ap_modifier),
        action_points(current_ap, max_ap, last_regen_at),
        character_skills(pool, skills(id, name, description, category, range, base_ap_cost, base_credit_cost))
      `)
      .eq('account_id', account_id)
      .eq('is_alive', true)
      .single();

    if (error || !character) {
      return res.status(404).json({
        error: 'No living character found',
        needs_character_creation: true
      });
    }

    return res.json({ character });

  } catch (err) {
    console.error('Get character error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
}

module.exports = { getCreationData, createCharacter, getMyCharacter };
