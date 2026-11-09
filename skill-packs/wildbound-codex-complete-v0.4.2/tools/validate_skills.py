from pathlib import Path
import re

base = Path(__file__).resolve().parents[1] / '.agents' / 'skills'
count=0
failed=False
for path in sorted(base.glob('*/SKILL.md')):
    content=path.read_text(encoding='utf-8')
    match=re.match(r'\A---\n(.*?)\n---\n',content,re.S)
    if not match:
        print('ERROR frontmatter:',path)
        failed=True
        continue
    header=match.group(1)
    n=re.search(r'^name:\s*(.+)$',header,re.M)
    d=re.search(r'^description:\s*(.+)$',header,re.M)
    if not n or not d or n.group(1).strip()!=path.parent.name or not d.group(1).strip():
        print('ERROR metadata:',path)
        failed=True
    else:
        print('OK:',path.parent.name)
        count += 1
print('Skills válidas:',count)
raise SystemExit(1 if failed or count==0 else 0)
