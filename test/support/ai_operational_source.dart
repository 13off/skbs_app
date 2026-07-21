import 'dart:io';

String aiOperationalSource() {
  return <String>[
    'supabase/functions/ai-operational-draft/index.ts',
    'supabase/functions/ai-operational-draft/shared.ts',
    'supabase/functions/ai-operational-draft/people_actions.ts',
    'supabase/functions/ai-operational-draft/report_actions.ts',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}
