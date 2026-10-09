"""Real installed CLI receipts. Writes are confined to a new disposable task-space."""
import argparse
import copy
import hashlib
import json
import subprocess
import time
import uuid
from pathlib import Path

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')

class Suite:
 def __init__(self,cli,output):
  self.cli=cli.resolve(strict=True);self.cli_hash=sha(self.cli)
  self.output=output.absolute()
  assert not self.output.exists(),'Evidence directory must be new; never overwrite receipts'
  self.output.mkdir(parents=True);self.output=self.output.resolve()
  self.tasks=self.output/'task-space';self.tasks.mkdir();self.calls=[];self.checks=[]
  self.guard()

 def guard(self):
  assert self.tasks.resolve(strict=True)==self.output/'task-space'
  assert self.tasks.is_relative_to(self.output) and self.tasks.parent==self.output
  for p in [self.tasks,*self.tasks.parents]:
   assert not p.is_symlink() and not p.is_junction(),'Reparse path rejected: '+str(p)
  assert sha(self.cli)==self.cli_hash,'Executable drift'

 def call(self,label,args,source=True,success=True):
  self.guard()
  argv=[str(self.cli),*args]
  if source:argv+=['--tasks',str(self.tasks)]
  argv+=['--format','json']
  proc=subprocess.run(argv,cwd=self.output,capture_output=True,text=True,encoding='utf-8',timeout=60)
  try:value=json.loads(proc.stdout)
  except ValueError:raise AssertionError({'label':label,'exit':proc.returncode,'stdout':proc.stdout,'stderr':proc.stderr})
  record={'label':label,'argv':argv,'exitCode':proc.returncode,'stdout':value,'stderr':proc.stderr}
  self.calls.append(record);save(self.output/'calls.json',self.calls)
  if success:assert proc.returncode==0 and value.get('success',True),record
  else:assert proc.returncode!=0 and value.get('success') is False,record
  return value

 def check(self,name,value):
  assert value,name;self.checks.append({'check':name,'status':'PASS'});save(self.output/'checks.json',self.checks)
  print('PASS: '+name,flush=True)

 def task(self,id,label='readback'):
  return self.call(label,['task','--id',id,'--include','details,relations,criteria,history,execution'])

 def hashes(self):
  self.guard()
  # Hash observations only; no decoded task-file reads or direct edits.
  return {str(p.relative_to(self.tasks)):sha(p) for p in sorted(self.tasks.rglob('*')) if p.is_file() and p.name!='.unlimotion.lock'}

 def request(self,name,operations,preconditions):
  r=copy.deepcopy(self.example)
  r.update(applicationId='fixture-'+str(uuid.uuid4()),proposalRefs=[{'id':name,'revision':1}],author='cli-contracts',reason='Authorized disposable fixture check',operations=operations,preconditions=preconditions)
  p=self.output/(name+'.request.json');save(p,r);return p

 def apply(self,name,request):
  before=self.hashes()
  preview=self.call(name+'-preview',['apply','--request',str(request),'--dry-run','--diff','full'])
  self.check(name+' preview did not write',preview['didMutate'] is False and before==self.hashes())
  preview_file=self.output/(name+'.preview.json');save(preview_file,preview)
  receipt=self.call(name+'-write',['apply','--request',str(request),'--expect-preview',str(preview_file)])
  changed=receipt['changedTaskIds']
  readbacks={id:self.task(id,name+'-readback-'+id) for id in changed}
  save(self.output/(name+'.readbacks.json'),readbacks)
  return receipt,readbacks

 def run(self):
  version=self.call('version',['version'],source=False)
  self.call('help-search',['help','search'],source=False)
  for cmd in ('create','claim','execution result','execution complete','apply','release'):
   self.call('help-'+cmd,['help',cmd],source=False)
  self.call('apply-schema',['apply','schema'],source=False)
  self.example=self.call('apply-example',['apply','example','set-field'],source=False)
  context=self.call('context',['context'])
  self.check('Pinned disposable source and binary',Path(context['tasksPath']).resolve()==self.tasks and context['sourceKind']=='explicitTasks')
  self.call('initial-validate',['validate'])

  created=[]
  def create(name,parents=[]):
   argv=['create','--title',name,'--description','fixture-only; preserve this user text','--author','cli-contracts']
   for parent in parents:argv+=['--parent',parent]
   receipt=self.call('create-'+name,argv);id=receipt['task']['id'];created.append(id)
   for changed in receipt['changedTaskIds']:self.task(changed,'create-readback')
   return id
  root=create('Root');a=create('Parent A',[root]);b=create('Parent B',[root]);child=create('Work',[a,b])
  seed=self.task(child,'seed-preconditions')
  seed_ops=[
   {'operationId':'seed-begin','kind':'setField','taskId':child,'field':'plannedBeginDateTime','value':'2026-10-07T00:00:00+03:00'},
   {'operationId':'seed-end','kind':'setField','taskId':child,'field':'plannedEndDateTime','value':'2026-10-08T00:00:00+03:00'},
   {'operationId':'seed-duration','kind':'setField','taskId':child,'field':'plannedDuration','value':'PT30M'},
   {'operationId':'seed-criterion','kind':'addCriterion','taskId':child,'criterionId':'preserved-criterion','text':'Original fixture criterion must be preserved','isSatisfied':True},
  ]
  seed_req=self.request('seed-protected-fields',seed_ops,[{'taskId':child,'etag':seed['etag']}])
  self.apply('seed-protected-fields',seed_req)
  before=self.task(child,'baseline-child');save(self.output/'child-before.json',before)
  self.check('Real multiparent relationships',a in json.dumps(before['relations']) and b in json.dumps(before['relations']))
  # Roots and both shared-ancestor paths are read through CLI; cycle/missing model cases are virtual.
  for id in (a,b,root):self.task(id,'all-parent-read')
  frozen=self.hashes()
  self.call('readonly-analysis',['search','--query','Work'])
  self.task(child,'readonly-inspect');self.call('readonly-validate',['validate'])
  self.check('Unauthorized artifact/parent/consultation policy: no writes dispatched',frozen==self.hashes())

  pc=lambda t:[{'taskId':t['task']['id'],'etag':t['etag']}]
  setfield=lambda id,text:{'operationId':'set-description','kind':'setField','taskId':id,'field':'descriptionUserText','value':text}
  req=self.request('description',[setfield(child,'fixture-only; approved field')],pc(before))
  receipt,reads=self.apply('description',req)
  after=reads[child];save(self.output/'child-after-description.json',after)
  protected=lambda x:{'status':x['task']['status'],'title':x['task']['title'],'details':{k:v for k,v in x['details'].items() if k not in ('description','descriptionUserText','updatedDateTime')},'criteria':x['criteria'],'relations':x['relations']}
  self.check('Only approved ID/description, protected fields preserved',set(receipt['changedTaskIds'])=={child} and protected(before)==protected(after) and after['details']['descriptionUserText']=='fixture-only; approved field')
  def lifecycle_semantics(x):
   return {'id':x['task']['id'],'title':x['task']['title'],
    'details':{k:v for k,v in x['details'].items() if k not in ('description','updatedDateTime')},
    'criteria':x['criteria'],
    'relations':sorted((r['type'],r['id'],r['exists']) for r in x['relations'])}
  graph_before={id:self.task(id,'lifecycle-baseline') for id in (root,a,b,child)}
  save(self.output/'lifecycle-field-contract.json',{'directTaskId':child,'permittedDerivedIds':[root,a,b],
   'directChanges':['status','execution','history append','managed description','updated timestamp','availability'],
   'ancestorChanges':['availability summaries','updated timestamp'],
   'protected':['user text','title','planned dates/duration','repeater','criteria','relation edges','ancestor status/execution/history']})
  def lifecycle_check(label,receipt,status):
   permitted=set(graph_before)
   self.check(label+' changed IDs bounded',child in receipt['changedTaskIds'] and set(receipt['changedTaskIds'])<=permitted)
   states={id:self.task(id,label+'-readback') for id in receipt['changedTaskIds']}
   self.check(label+' protected fields and relation edges preserved',all(lifecycle_semantics(states[id])==lifecycle_semantics(graph_before[id]) for id in states))
   self.check(label+' ancestor statuses/execution/history preserved',all(states[id]['task']['status']==graph_before[id]['task']['status'] and states[id].get('execution')==graph_before[id].get('execution') and states[id]['history']==graph_before[id]['history'] for id in states if id!=child))
   self.check(label+' observed child status',states[child]['task']['status']==status)
   self.check(label+' original child history prefix preserved',states[child]['history'][:len(graph_before[child]['history'])]==graph_before[child]['history'])
   save(self.output/(label+'.protected-readbacks.json'),states)
   return states[child]
  inspect=self.call('receipt-inspect',['apply','inspect','--request',str(req)])
  save(self.output/'receipt-inspect.json',inspect)
  self.check('Exact-request receipt matched',inspect.get('assessment')=='receiptMatched' and inspect.get('receiptState')=='matching' and inspect.get('postconditionsMatch')=='all')

  stale=self.request('stale',[setfield(child,'must not apply')],pc(before));frozen=self.hashes()
  denied=self.call('stale-preview',['apply','--request',str(stale),'--dry-run'],success=False)
  self.check('Stale ETag rejected with zero writes',denied['error']['kind']=='preconditionFailed' and frozen==self.hashes())
  self.task(child,'stale-reread')
  cycle=self.request('cycle',[{'operationId':'cycle','kind':'addRelation','relation':'contains','fromTaskId':child,'toTaskId':root}],pc(self.task(child))+pc(self.task(root)))
  frozen=self.hashes();denied=self.call('cycle-preview',['apply','--request',str(cycle),'--dry-run'],success=False)
  cycle_issues=denied.get('validation',{}).get('referenceIssues',[])
  self.check('Real CLI refuses cycle without graph edits',denied['error']['kind']=='validationFailed' and any(x['kind']=='ContainmentCycle' for x in cycle_issues) and all(x['sourceTaskId'] in graph_before and x['targetTaskId'] in graph_before and x['relation']=='ContainsTasks' for x in cycle_issues) and frozen==self.hashes())
  missing=self.request('missing',[{'operationId':'missing','kind':'addRelation','relation':'contains','fromTaskId':child,'toTaskId':str(uuid.uuid4())}],pc(self.task(child)))
  frozen=self.hashes();denied=self.call('missing-preview',['apply','--request',str(missing),'--dry-run'],success=False)
  self.check('Real CLI refuses missing edge with zero writes',denied['error']['kind']=='notFound' and frozen==self.hashes())

  claimed=self.call('claim',['claim','--id',child,'--agent','cli-contracts','--expected-status','Prepared']);lease=claimed['execution']['leaseId']
  lifecycle_check('claim',claimed,'InProgress')
  self.check('Prepared claim obtains matching lease',claimed['task']['status']=='InProgress' and claimed['execution']['agentId']=='cli-contracts')
  frozen=self.hashes()
  denied=self.call('foreign-lease',['execution','result','--id',child,'--agent','other-agent','--lease',str(uuid.uuid4()),'--summary','must not save'],success=False)
  self.task(child,'foreign-lease-readback')
  self.check('Foreign lease refused and no writes',denied['error']['kind']=='leaseMismatch' and frozen==self.hashes())
  frozen=self.hashes()
  denied=self.call('stale-same-agent-lease',['execution','result','--id',child,'--agent','cli-contracts','--lease',str(uuid.uuid4()),'--summary','must not save stale lease'],success=False)
  state=self.task(child,'stale-lease-readback')
  self.check('Same-agent stale lease refused without retry or writes',denied['error']['kind']=='leaseMismatch' and state['execution']['leaseId']==lease and frozen==self.hashes())
  args=['--id',child,'--agent','cli-contracts','--lease',lease]
  receipt=self.call('unfinished-result',['execution','result',*args,'--summary','Unfinished fixture: required evidence remains'])
  result=lifecycle_check('unfinished-result',receipt,'InProgress')
  self.check('Intermediate result does not complete',result['task']['status']=='InProgress' and 'Unfinished fixture' in json.dumps(result))
  # Completion is permitted only for a separate proven fixture artifact.
  artifact=self.output/'verified-result.txt';artifact.write_text('Анна, Борис\n',encoding='utf-8')
  self.check('Fixture outcome verified',artifact.read_text(encoding='utf-8')=='Анна, Борис\n')
  receipt=self.call('finished-result',['execution','result',*args,'--summary','Verified deduplicated fixture list','--link',artifact.as_uri()])
  result=lifecycle_check('finished-result',receipt,'InProgress')
  complete=self.call('execution-complete',['execution','complete',*args,'--summary','Verified fixture outcome reached','--link',artifact.as_uri()])
  lifecycle_check('complete',complete,'Completed')
  final=self.task(child,'final-child')
  self.check('Explicitly authorized completion after outcome',final['task']['status']=='Completed')

  unfinished=create('Unsatisfied criterion fixture');initial=self.task(unfinished)
  criterion=self.request('unsatisfied-criterion',[{'operationId':'criterion','kind':'addCriterion','taskId':unfinished,'criterionId':'required-evidence','text':'Required evidence not yet available','isSatisfied':False}],pc(initial))
  self.apply('unsatisfied-criterion',criterion)
  incomplete_claim=self.call('incomplete-claim',['claim','--id',unfinished,'--agent','cli-contracts','--expected-status','Prepared'])
  incomplete_args=['--id',unfinished,'--agent','cli-contracts','--lease',incomplete_claim['execution']['leaseId']]
  self.task(unfinished,'incomplete-claim-readback')
  frozen=self.hashes()
  denied=self.call('unsatisfied-completion',['execution','complete',*incomplete_args,'--summary','Must be refused: required criterion is not satisfied'],success=False)
  state=self.task(unfinished,'unsatisfied-readback')
  self.check('Unsatisfied criterion blocks real completion with zero writes',state['task']['status']=='InProgress' and frozen==self.hashes())

  recovery_task=create('Recovery fixture');old=self.task(recovery_task)
  recover=self.request('response-loss',[setfield(recovery_task,'single approved recovery write')],pc(old))
  preview=self.call('recovery-preview',['apply','--request',str(recover),'--dry-run','--diff','full']);preview_file=self.output/'recovery.preview.json';save(preview_file,preview)
  self.guard()
  argv=[str(self.cli),'apply','--request',str(recover),'--expect-preview',str(preview_file),'--tasks',str(self.tasks),'--format','json']
  # One real mutation, intentionally discarded response, deadline observed without killing/retry.
  with (self.output/'recovery.stderr.txt').open('w',encoding='utf-8') as err:
   proc=subprocess.Popen(argv,cwd=self.output,stdout=subprocess.DEVNULL,stderr=err)
   timed_out=False
   try:proc.wait(timeout=.001)
   except subprocess.TimeoutExpired:timed_out=True
   code=proc.wait(timeout=60)
  save(self.output/'uncertain-process.json',{'argv':argv,'pid':proc.pid,'deadlineObserved':timed_out,'exitCode':code,'dispatchCount':1,'responseDiscarded':True,'endedBeforeInspect':True})
  self.check('Controlled deadline/process end before recovery',timed_out and code==0)
  inspected=self.call('uncertain-inspect',['apply','inspect','--request',str(recover)])
  read=self.task(recovery_task,'uncertain-readback')
  self.check('Uncertain outcome recovered, no repeat mutation',inspected.get('assessment')=='receiptMatched' and inspected.get('receiptState')=='matching' and inspected.get('changedTaskIds')==[recovery_task] and read['details']['descriptionUserText']=='single approved recovery write')
  frozen=self.hashes()
  missing_source=self.output/'absent-task-space'
  # Explicit unavailable source: no fallback to real desktop settings or environment.
  self.guard();proc=subprocess.run([str(self.cli),'context','--tasks',str(missing_source),'--format','json'],capture_output=True,text=True,encoding='utf-8',timeout=60)
  failure=json.loads(proc.stdout);save(self.output/'source-failure.json',{'exitCode':proc.returncode,'stdout':failure,'explicitTasks':str(missing_source)})
  self.check('Unavailable explicit source fails, fixture unchanged',proc.returncode!=0 and frozen==self.hashes() and not missing_source.exists())
  valid=self.call('final-validate',['validate'])
  self.check('Final graph valid',valid.get('isValid') is True)
  save(self.output/'summary.json',{'status':'PASS','layer':'installed-cli-only','version':version,'executable':str(self.cli),'executableSha256':self.cli_hash,'tasksPath':str(self.tasks),'checks':len(self.checks),'createdTaskIds':created,'hashes':self.hashes(),'limits':['Policy zero-write fixture receipts do not prove model behavior; paired virtual smoke is separate.','Controlled deadline/response-loss is not an injected storage crash.','No production source or direct JSON mutation.']})

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--cli',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 suite=Suite(a.cli,a.output)
 try:suite.run()
 except Exception as e:
  save(suite.output/'summary.json',{'status':'FAIL','error':str(e),'checks':suite.checks,'tasksPath':str(suite.tasks),'noBlindRetry':True});raise
