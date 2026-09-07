const String defaultSupabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co';
const String defaultSupabasePublishableKey =
    'sb_publishable_QBdH-vIQv4F_tVVNc4Ps_w_ssxwSaEm';

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: defaultSupabaseUrl,
);

const String supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: defaultSupabasePublishableKey,
);
