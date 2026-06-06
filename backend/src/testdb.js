require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

async function testConnection() {
  try {
    const { error } = await supabase
      .from('_prisma_migrations')
      .select('*')
      .limit(1);
    
    if (error && error.code === 'PGRST116') {
      console.log('✅ Database connection successful!');
      console.log('   Database is empty and ready for schema.');
    } else if (error && error.message.includes('schema cache')) {
      console.log('✅ Database connection successful!');
      console.log('   Database is empty and ready for schema.');
    } else if (error) {
      console.log('❌ Unexpected error:', error.message);
      console.log('   Code:', error.code);
    } else {
      console.log('✅ Database connection successful!');
    }
  } catch (err) {
    console.log('❌ Failed to reach database:', err.message);
  }
  process.exit(0);
}

testConnection();
