from pathlib import Path

path = Path('supabase/functions/ai-operational-insights/index.ts')
text = path.read_text(encoding='utf-8')
replacements = {
    'import "jsr:@supabase/functions-js/edge-runtime.d.ts";': 'import "jsr:@supabase/functions-js@2.110.8/edge-runtime.d.ts";',
    'import { createClient } from "jsr:@supabase/supabase-js@2";': 'import { createClient } from "jsr:@supabase/supabase-js@2.110.8";',
    '''      const attendanceByEmployee = new Map(
        attendance.map((row: any) => [String(row.employee_id), row]),
      );''': '''      const attendanceByEmployee = new Map<string, any>(
        attendance.map((row: any): [string, any] => [
          String(row.employee_id),
          row,
        ]),
      );''',
}
for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'expected fragment not found: {old}')
    text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
