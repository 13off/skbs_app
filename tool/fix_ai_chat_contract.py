from pathlib import Path

path = Path('test/ai_assistant_contract_test.dart')
text = path.read_text(encoding='utf-8')
start = text.index('    expect(repository, contains("functions.invoke(')
end = text.index('    expect(repository, contains("\'company_id\'"));', start)
replacement = """    expect(repository, contains('functions.invoke('));
    expect(repository, contains("'ai-assistant'"));
"""
path.write_text(text[:start] + replacement + text[end:], encoding='utf-8')
