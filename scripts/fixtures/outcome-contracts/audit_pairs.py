"""Audit provenance/completeness only. Does not assign behavioral PASS."""
import argparse
import base64
import json
from pathlib import Path

from runtime import sha, verify_snapshot


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def planned_entries(manifest):
    entries=[]
    for scenario in manifest['scenarios']:
        entries += [dict(v,caseId=scenario['id']+'-'+v['id'],phases=['baseline','candidate']) for v in scenario['variants']]
    entries += [dict(v,caseId=v['id'],phases=['candidate'],reference=v['basedOn']+'-base') for v in manifest['heldOut']]
    return entries


def missing_slots(manifest, present):
    return sorted((phase,e['caseId']) for e in planned_entries(manifest) for phase in e['phases'] if (phase,e['caseId']) not in present)


def validate_protocol(records, case, provenance):
    """Compare observed requests, not a self-reported provenance declaration."""
    errors=[]; starts=[]; texts=[]; steering=[]; acknowledged=set()
    last_operation=None
    for record in records:
        message=record['message']
        if record['direction']=='receive':
            if message.get('method')=='item/tool/call':
                last_operation=message.get('params',{}).get('arguments',{}).get('operation')
            if 'result' in message and any(s['id']==message.get('id') for s in steering):
                acknowledged.add(message['id'])
            continue
        method=message.get('method')
        if method=='thread/start':
            starts.append(message['params'])
        elif method=='turn/start':
            texts.append([part.get('text') for part in message['params']['input'] if part.get('type')=='text'])
        elif method=='turn/steer':
            steering.append({'id':message['id'], 'texts':[part.get('text') for part in message['params']['input'] if part.get('type')=='text'], 'afterOperation':last_operation})
    if texts!=[[t['text']] for t in case['turns']]:
        errors.append('actual user text/order differs from fixture')
    if len(starts)!=1:
        errors.append('actual thread/start count differs from one')
    else:
        start=starts[0]
        if sha(start.get('developerInstructions','').encode())!=provenance['adapterSha256']:
            errors.append('actual developer instructions digest mismatch')
        if sha(json.dumps(start.get('dynamicTools',[]),sort_keys=True).encode())!=provenance['toolSchemaSha256']:
            errors.append('actual dynamic tool schema digest mismatch')
    expected=[t['steer'] for t in case['turns'] if 'steer' in t]
    if len(steering)!=len(expected):
        errors.append('actual steering request count mismatch')
    for actual,wanted in zip(steering,expected):
        if actual['texts']!=[wanted['text']] or actual['afterOperation']!=wanted['afterOperation']:
            errors.append('actual steering text/operation boundary mismatch')
        if actual['id'] not in acknowledged:
            errors.append('actual steering acknowledgement missing')
    return errors


def select_entries(manifest, selected):
    entries=planned_entries(manifest)
    if selected is None:
        return entries
    wanted=set(selected)
    known={e['caseId'] for e in entries}
    if not wanted or wanted-known:
        raise ValueError('Unknown or empty audit scope: '+repr(sorted(wanted-known)))
    return [e for e in entries if e['caseId'] in wanted]


def runtime_identity(directory, fields):
    provenance=read(directory/'provenance.json')
    effective=read(directory/'effective-runtime.json')
    requested=read(directory/'requested-runtime.json')
    pointer=read(directory/'bootstrap-pointer.json')
    return {'effective':{k:effective.get(k) for k in fields},
        'environments':effective['thread'].get('environments'),
        'cliVersion':effective['thread']['cliVersion'],
        'executableSha256':requested['executableSha256'],
        'processOverrides':requested['overrides'],
        **{k:provenance[k] for k in ['caseSha256','toolSchemaSha256','adapterSha256']},
        'bootstrapSha256':pointer['sha256']}


def audit(output, baseline, candidate, selected=None, baseline_output=None, reference_candidate_output=None):
    fixtures=Path(__file__).parent
    manifest=read(fixtures/'manifest.json')
    all_entries=planned_entries(manifest)
    entries=select_entries(manifest,selected)
    baseline_output=baseline_output or output
    reference_candidate_output=reference_candidate_output or output
    failures=[]
    results=[]
    source_hashes={}
    for source_output in {output,baseline_output}:
        if (source_output/'HARNESS-INVALID.json').exists():
            failures.append('Evidence set is explicitly marked harness-invalid: '+str(source_output))
    for phase,root in [('baseline',baseline),('candidate',candidate)]:
        try:
            phase_output=baseline_output if phase=='baseline' else output
            _,source_hashes[phase]=verify_snapshot(root,phase_output/'snapshots'/phase)
        except Exception as exc:
            failures.append(f'{phase}: {exc}')
    fields=['model','modelProvider','reasoningEffort','approvalPolicy','approvalsReviewer','sandbox','serviceTier']
    for entry in entries:
        key=entry['caseId']; evidence={}; errors=[]
        case=read(fixtures/entry['input'])
        expected_image_hashes={sha((fixtures/t['image']).read_bytes()) for t in case['turns'] if 'image' in t}
        allowed_image_hashes=expected_image_hashes | {sha((fixtures/v['image']).read_bytes()) for v in case['operations'].values() if 'image' in v}
        for phase in entry['phases']:
            directory=(baseline_output if phase=='baseline' else output)/phase/key
            try:
                state=read(directory/'execution.json')
                provenance=read(directory/'provenance.json')
                effective=read(directory/'effective-runtime.json')
                requested=read(directory/'requested-runtime.json')
                pointer=read(directory/'bootstrap-pointer.json')
                checks=read(directory/'isolation-checks.json')
                if state['status']!='executed': errors.append(phase+': not executed')
                if not all(checks.values()): errors.append(phase+': isolation checks failed')
                if provenance['caseSha256']!=sha((fixtures/entry['input']).read_bytes()): errors.append(phase+': current input drift')
                if provenance['catalogSha256']!=source_hashes.get(phase): errors.append(phase+': catalog mismatch')
                if provenance['oraclePassedToModel'] is not False: errors.append(phase+': oracle leakage flag')
                if state['turnCount']!=len(case['turns']): errors.append(phase+': continuation count mismatch')
                if any('steer' in turn for turn in case['turns']):
                    if read(directory/'steering.json').get('accepted') is not True: errors.append(phase+': steering not accepted')
                images=[];initial_images=[];turn_starts=0
                records=[json.loads(line) for line in (directory/'protocol.jsonl').read_text(encoding='utf-8').splitlines()]
                errors.extend(phase+': '+e for e in validate_protocol(records,case,provenance))
                for item in records:
                    if item['direction']!='send': continue
                    message=item['message']
                    if message.get('method')=='turn/start':
                        turn_starts+=1
                        for part in message['params']['input']:
                            if part.get('type')=='image':
                                h=sha(base64.b64decode(part['url'].split(',',1)[1]));images.append(h);initial_images.append(h)
                    for part in message.get('result',{}).get('contentItems',[]):
                        if part.get('type')=='inputImage': images.append(sha(base64.b64decode(part['imageUrl'].split(',',1)[1])))
                if turn_starts!=len(case['turns']): errors.append(phase+': actual turn/start count mismatch')
                if set(initial_images)!=expected_image_hashes: errors.append(phase+': initial image mismatch')
                if not set(images).issubset(allowed_image_hashes): errors.append(phase+': unexpected image content')
                evidence[phase]=runtime_identity(directory,fields) | {'actualImages':images,'calls':state['callCount'],'directory':str(directory)}
            except Exception as exc:
                errors.append(phase+': missing/invalid evidence: '+str(exc))
        if len(evidence)==2:
            for field in ['effective','environments','cliVersion','executableSha256','processOverrides','caseSha256','toolSchemaSha256','adapterSha256','bootstrapSha256']:
                if evidence['baseline'][field]!=evidence['candidate'][field]: errors.append('pair mismatch: '+field)
        elif 'reference' in entry and 'candidate' in evidence:
            reference=next((r for r in results if r['caseId']==entry['reference']),None)
            if not reference or 'candidate' not in reference['evidence']:
                try:
                    refdir=reference_candidate_output/'candidate'/entry['reference']
                    refentry=next(e for e in all_entries if e['caseId']==entry['reference'])
                    refcase=read(fixtures/refentry['input'])
                    refprovenance=read(refdir/'provenance.json')
                    refrecords=[json.loads(line) for line in (refdir/'protocol.jsonl').read_text(encoding='utf-8').splitlines()]
                    referrors=validate_protocol(refrecords,refcase,refprovenance)
                    if referrors or read(refdir/'execution.json')['status']!='executed':
                        raise ValueError('Reference execution/protocol invalid: '+repr(referrors))
                    reference={'evidence':{'candidate':runtime_identity(refdir,fields)}}
                    evidence['runtimeReference']={'directory':str(refdir),'scope':'runtime comparison only; not a final-catalog rerun of the reference scenario'}
                except Exception as exc:
                    errors.append('heldout reference evidence: '+str(exc))
            if not reference or 'candidate' not in reference['evidence']:
                errors.append('heldout candidate reference unavailable')
            else:
                for field in ['effective','environments','cliVersion','executableSha256','processOverrides','toolSchemaSha256','adapterSha256','bootstrapSha256']:
                    if evidence['candidate'][field]!=reference['evidence']['candidate'][field]: errors.append('heldout runtime mismatch: '+field)
        failures.extend(key+': '+e for e in errors)
        results.append({'caseId':key,'provenanceValid':not errors,'errors':errors,'evidence':evidence})
    valid_status='scoped_valid' if selected is not None else 'valid'
    invalid_status='scoped_incomplete_or_invalid' if selected is not None else 'incomplete_or_invalid'
    summary={'status':valid_status if not failures else invalid_status,'cases':len(entries),
        'scope':{'selectedCases':[e['caseId'] for e in entries],'expectedExecutions':sum(len(e['phases']) for e in entries),'fullManifest':selected is None},
        'baselineOutput':str(baseline_output),'candidateOutput':str(output),
        'sourceHashes':source_hashes,'failures':failures,'results':results,
        'behavioralVerdict':'not_graded; independent oracle review required',
        'implementationProvenanceLimit':'No per-process backend source hash was captured. Current v2 uses retained frozen source plus independent backend semantics review; this is not cryptographic proof of every running process implementation.'}
    payload=json.dumps(summary,ensure_ascii=False,indent=2)
    (output/'pair-audit.json').write_text(payload,encoding='utf-8')
    if selected is not None:
        scope_hash=sha(json.dumps(sorted(selected)).encode())[:12]
        (output/('pair-audit-scoped-'+scope_hash+'.json')).write_text(payload,encoding='utf-8')
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--baseline',type=Path,required=True)
    parser.add_argument('--candidate',type=Path,required=True)
    parser.add_argument('--cases',help='Comma-separated explicit case IDs; yields scoped provenance verdict only')
    parser.add_argument('--baseline-output',type=Path,help='Reuse baseline traces and snapshot from this output root')
    parser.add_argument('--reference-candidate-output',type=Path,help='Candidate runtime reference evidence for heldout S06/S11')
    args=parser.parse_args()
    result=audit(args.output,args.baseline,args.candidate,args.cases.split(',') if args.cases else None,args.baseline_output,args.reference_candidate_output)
    print(json.dumps({'status':result['status'],'cases':result['cases'],'failures':len(result['failures']),'behavioralVerdict':result['behavioralVerdict']},ensure_ascii=False))
    raise SystemExit(0 if result['status'] in ('valid','scoped_valid') else 1)
