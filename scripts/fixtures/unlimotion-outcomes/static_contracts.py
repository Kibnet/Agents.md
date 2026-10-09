"""Source/fixture guards only. This does not evaluate agent behavior or real CLI."""
import argparse
import copy
import json
import re
from pathlib import Path

GUARDS = {
 'instructions/contexts/unlimotion-task-context.md': [
  'установленного бинарника', 'resolved абсолютный tasksPath', 'Task identity = source identity + task ID',
  'Ошибка источника не разрешает молчаливый source switch', 'каждое ребро ParentTasks',
  'Path-local visited', 'общий cache', 'Missing parent/cycle', 'только адресные knowledge sources',
  'quick context', 'Чтение не требует claim'],
 'instructions/governance/unlimotion-result-tracking.md': [
  'не создавать duplicate', 'Новый task только если создание входит', 'ResultRecord',
  'Claim только если Prepared', 'чужой lease не перехватывать', 'agentId + leaseId',
  'failed/unfinished result не complete', 'apply --dry-run', 'отказ preview запрещает write',
  'без повторного human gate', 'все changedTaskIds/createdTaskIds', 'защищённые',
  'проверить завершение процесса', 'Не повторять вслепую', 'прямым JSON редактированием',
  'Stale ETag/lease', 'Не исправлять посторонние graph/availability'],
 'instructions/governance/goal-context-enrichment.md': [
  'ближайшего смыслового родителя', 'parent IDs', 'источник/дата', 'Hypothesis',
  'Child authority не распространяется на parent', 'zero tracker writes', 'Не архивировать/завершать родителя'],
 'instructions/governance/routing-matrix.md': [
  '(../contexts/unlimotion-task-context.md)', '(./unlimotion-result-tracking.md)',
  '(./goal-context-enrichment.md)', 'короткая консультация без deliverable',
  'Конфликтная модель остаётся в этом документе'],
 'instructions/onboarding/local-environment.md': ['<absolute-authorized-task-space>', '<current-user-provided-profile-pointer>', 'Не переносить заполненные private paths/profile'],
 'AGENTS.md': ['#unlimotion-контекст-и-результаты'],
 'README.md': ['instructions/contexts/unlimotion-task-context.md', 'настоящие CLI receipts'],
}

def visible(text):
 lines=[]; fence=None
 for line in text.splitlines():
  m=re.match(r'^\s*(`{3,}|~{3,})',line)
  if m:
   ch=m[1][0]
   if fence is None: fence=(ch,len(m[1]))
   elif ch==fence[0] and len(m[1])>=fence[1]:fence=None
  elif fence is None:lines.append(line)
 return '\n'.join(lines)

def source_issues(texts):
 issues=[]
 for path,terms in GUARDS.items():
  text=visible(texts.get(path,''))
  for term in terms:
   if term not in text:issues.append(path+': '+term)
 return issues

def fixture_issues(root,manifest):
 issues=[]
 try:
  assert manifest['schemaVersion']==1
  expected={'S1':['base'],'S2':['base'],'S3':['done','unfinished'],'S4':['base'],'S5':['consultation','source-failure']}
  assert len(manifest['scenarios'])==5
  seen=set()
  for scenario in manifest['scenarios']:
   key=scenario['id'];assert key in expected and key not in seen;seen.add(key)
   assert [v['id'] for v in scenario['variants']]==expected[key]
   for variant in scenario['variants']:
    values={}
    for field in ('input','oracle'):
     p=(root/variant[field]).resolve();assert p.is_relative_to(root.resolve())
     values[field]=json.loads(p.read_text(encoding='utf-8-sig'))
    c,o=values['input'],values['oracle']
    assert c['turns'] and c['files'] is not None and isinstance(c['operations'],dict)
    assert o['expected'] and o['forbidden'] and isinstance(o['allowedWrites'],list)
    assert 'expected' not in c and 'oracle' not in c
    assert not re.search(r'C:[\\/](Users|Obsidian|Projects)',json.dumps(c))
  assert seen==set(expected)
 except (AssertionError,KeyError,OSError,ValueError,TypeError) as e:issues.append('fixture schema/path/privacy: '+str(e))
 return issues

def run(root,validate_only):
 texts={p:(root/p).read_text(encoding='utf-8-sig') if (root/p).exists() else '' for p in GUARDS}
 pack=root/'scripts/fixtures/unlimotion-outcomes'
 manifest=json.loads((pack/'manifest.json').read_text(encoding='utf-8-sig'))
 issues=source_issues(texts)+fixture_issues(pack,manifest)
 assert not issues,'\n'.join(issues)
 negatives=0
 if not validate_only:
  for path,terms in GUARDS.items():
   for term in terms:
    altered=dict(texts);altered[path]=altered[path].replace(term,'REMOVED')
    assert source_issues(altered),(path,term);negatives+=1
    altered=dict(texts);altered[path]='```text\n'+texts[path]+'\n```'
    assert source_issues(altered);negatives+=1
  for mode in ('duplicate','missing','escape','oracle'):
   m=copy.deepcopy(manifest)
   if mode=='duplicate':m['scenarios'][1]['id']='S1'
   elif mode=='missing':m['scenarios'].pop()
   elif mode=='escape':m['scenarios'][0]['variants'][0]['input']='../../../../AGENTS.md'
   else:m['scenarios'][0]['variants'][0]['oracle']='cases/S1-base.json'
   assert fixture_issues(pack,m);negatives+=1
 print(json.dumps({'status':'PASS','layer':'static-only','guards':sum(map(len,GUARDS.values())), 'scenarios':5,'variants':7,'negativeMutations':negatives}))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--validate-only',action='store_true')
 a=p.parse_args();run(a.root,a.validate_only)
