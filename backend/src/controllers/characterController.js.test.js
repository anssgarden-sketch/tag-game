require('dotenv').config();
const supabase = require('./src/services/supabase');

async function test() {
  console.log('Testing cities...');
  const cities = await supabase.from('cities').select('id, name').limit(3);
  console.log('Cities:', JSON.stringify(cities, null, 2));

  console.log('Testing professions...');
  const profs = await supabase.from('professions').select('id, name').limit(3);
  console.log('Professions:', JSON.stringify(profs, null, 2));

  console.log('Testing skills...');
  const skills = await supabase.from('skills').select('id, name, category').limit(3);
  console.log('Skills:', JSON.stringify(skills, null, 2));
}

test().then(() => process.exit(0));
