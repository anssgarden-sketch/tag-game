const cron = require('node-cron');
const supabase = require('../services/supabase');

async function runApRegen() {
  try {
    console.log(`[AP Regen] Running at ${new Date().toISOString()}`);

    // Get all living characters whose AP is below max
    const { data: apRecords, error } = await supabase
      .from('action_points')
      .select(`
        id,
        character_id,
        current_ap,
        max_ap,
        characters!inner(is_alive, ap_committed)
      `)
      .eq('characters.is_alive', true)
      .lt('current_ap', supabase.rpc('get_max_ap'));

    // Simpler approach -- fetch all and filter in code
    const { data: allAp, error: fetchError } = await supabase
      .from('action_points')
      .select(`
        id,
        character_id,
        current_ap,
        max_ap,
        last_regen_at,
        characters!inner(is_alive)
      `)
      .eq('characters.is_alive', true);

    if (fetchError) {
      console.error('[AP Regen] Fetch error:', fetchError);
      return;
    }

    if (!allAp || allAp.length === 0) {
      console.log('[AP Regen] No living characters found');
      return;
    }

    // Filter to characters who are below max AP
    const needsRegen = allAp.filter(ap => ap.current_ap < ap.max_ap);

    if (needsRegen.length === 0) {
      console.log('[AP Regen] All characters at max AP');
      return;
    }

    console.log(`[AP Regen] Regenerating AP for ${needsRegen.length} character(s)`);

    // Update each character's AP by 1
    const updates = needsRegen.map(ap =>
      supabase
        .from('action_points')
        .update({
          current_ap: ap.current_ap + 1,
          last_regen_at: new Date().toISOString()
        })
        .eq('id', ap.id)
    );

    const results = await Promise.all(updates);

    // Check for errors
    const errors = results.filter(r => r.error);
    if (errors.length > 0) {
      console.error('[AP Regen] Some updates failed:', errors.map(e => e.error));
    }

    console.log(`[AP Regen] Successfully updated ${needsRegen.length - errors.length} character(s)`);

    // Also check for queued travel and assassinations that can now proceed
    await processQueuedActions();

  } catch (err) {
    console.error('[AP Regen] Unexpected error:', err);
  }
}

async function processQueuedActions() {
  try {
    // Check for characters in transit who have now recovered enough AP to arrive
    const now = new Date().toISOString();

    const { data: arrivals, error } = await supabase
      .from('characters')
      .select('id, name, destination_city_id, arrives_at')
      .eq('travel_status', 'in_transit')
      .eq('is_alive', true)
      .lte('arrives_at', now);

    if (error) {
      console.error('[AP Regen] Transit check error:', error);
      return;
    }

    if (!arrivals || arrivals.length === 0) return;

    console.log(`[AP Regen] Processing ${arrivals.length} arrival(s)`);

    for (const character of arrivals) {
      // Move character to destination
      const { error: arrivalError } = await supabase
        .from('characters')
        .update({
          current_city_id: character.destination_city_id,
          travel_status: 'arrived',
          destination_city_id: null,
          transport_mode: null,
          journey_started_at: null,
          arrives_at: null,
          ap_committed: 0
        })
        .eq('id', character.id);

      if (arrivalError) {
        console.error(`[AP Regen] Arrival error for ${character.name}:`, arrivalError);
      } else {
        console.log(`[AP Regen] ${character.name} has arrived at destination`);

        // Expire any tags on this character since they moved
        await supabase
          .from('tags')
          .update({ is_active: false })
          .eq('target_character_id', character.id)
          .eq('is_active', true);
      }
    }

  } catch (err) {
    console.error('[AP Regen] Queue processing error:', err);
  }
}

async function expireTags() {
  try {
    const now = new Date().toISOString();

    const { data: expiredTags, error } = await supabase
      .from('tags')
      .update({ is_active: false })
      .eq('is_active', true)
      .lte('expires_at', now)
      .select('id');

    if (error) {
      console.error('[AP Regen] Tag expiry error:', error);
      return;
    }

    if (expiredTags && expiredTags.length > 0) {
      console.log(`[AP Regen] Expired ${expiredTags.length} tag(s)`);
    }

  } catch (err) {
    console.error('[AP Regen] Tag expiry error:', err);
  }
}

function startApRegenJob() {
  // Run every hour at the top of the hour
  cron.schedule('0 * * * *', async () => {
    await runApRegen();
    await expireTags();
  });

  console.log('[AP Regen] Job scheduled — runs every hour');
}

// Export for testing
module.exports = { startApRegenJob, runApRegen, expireTags };