from pathlib import Path

path = Path('supabase/functions/invite-company-member-core/index.ts')
text = path.read_text(encoding='utf-8')
old = '(candidate) => cleanEmail(candidate.email) === email,'
new = '(candidate: User) => cleanEmail(candidate.email) === email,'
if text.count(old) != 1:
    raise RuntimeError(f'Expected one match, found {text.count(old)}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
