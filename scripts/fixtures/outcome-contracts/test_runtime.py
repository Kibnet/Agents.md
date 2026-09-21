import json
from pathlib import Path
import tempfile
import unittest

from runtime import Backend, snapshot, verify_snapshot
from audit_pairs import planned_entries, missing_slots, validate_protocol, select_entries
from runtime import sha
import copy


class RuntimeBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.backend = Backend({'files':{'src/state.json':'{"ready":false}'},'operations':{}},
            {'AGENTS.md':'catalog instructions'}, self.path/'out', self.path)

    def test_external_and_oracle_paths_are_unavailable(self):
        for path in ['C:/Users/example/secret.txt','../oracles/S01.json','oracles/S01.json']:
            result=self.backend.observe('fixture_read',{'path':path})
            self.assertFalse(result['success'])

    def test_catalog_is_immutable_and_pointer_resolves_to_snapshot(self):
        result=self.backend.observe('fixture_read',{'path':'C:/Users/example/.codex/agents/AGENTS.md'})
        self.assertEqual('catalog instructions',result['contentItems'][0]['text'])
        result=self.backend.observe('fixture_write',{'path':'catalog/AGENTS.md','text':'replacement'})
        self.assertFalse(result['success'])
        self.assertEqual('catalog instructions',self.backend.catalog['AGENTS.md'])

    def test_observation_depends_on_current_artifact(self):
        self.backend.operations['check']={'description':'Check state','result':{},
            'predicate':{'file':'src/state.json','jsonProperty':'ready','equals':True},
            'trueResult':{'passed':True},'falseResult':{'passed':False}}
        def observed():
            return json.loads(self.backend.observe('fixture_action',{'operation':'check','parameters':{}})['contentItems'][0]['text'])['passed']
        self.assertFalse(observed())
        self.backend.observe('fixture_write',{'path':'src/state.json','text':'{"ready":true}'})
        self.assertTrue(observed())

    def test_snapshot_rejects_source_and_copy_drift(self):
        root=self.path/'root'; root.mkdir()
        (root/'AGENTS.md').write_text('original',encoding='utf-8')
        snap=self.path/'snapshot'; snapshot(root,snap)
        verify_snapshot(root,snap)
        (root/'AGENTS.md').write_text('changed',encoding='utf-8')
        with self.assertRaisesRegex(RuntimeError,'drift'):
            verify_snapshot(root,snap)
        (root/'AGENTS.md').write_text('original',encoding='utf-8')
        (snap/'catalog.json').write_text('{"AGENTS.md":"tampered"}',encoding='utf-8')
        with self.assertRaisesRegex(RuntimeError,'drift'):
            verify_snapshot(root,snap)

    def test_completeness_requires_21_pairs_and_two_candidate_heldouts(self):
        manifest=json.loads((Path(__file__).parent/'manifest.json').read_text(encoding='utf-8'))
        entries=planned_entries(manifest)
        present={(phase,e['caseId']) for e in entries for phase in e['phases']}
        self.assertEqual(44,len(present))
        self.assertNotIn(('baseline','H06'),present)
        self.assertNotIn(('baseline','H11'),present)
        self.assertEqual([],missing_slots(manifest,present))
        present.remove(('candidate','H11'))
        self.assertEqual([('candidate','H11')],missing_slots(manifest,present))

    def test_actual_prompt_and_tools_are_audited(self):
        tools=[{'name':'fixture_read','type':'function'}]
        provenance={'adapterSha256':sha(b'adapter'),'toolSchemaSha256':sha(json.dumps(tools,sort_keys=True).encode())}
        case={'turns':[{'text':'First'},{'text':'Second'}]}
        records=[{'direction':'send','message':{'method':'thread/start','params':{'developerInstructions':'adapter','dynamicTools':tools}}}]
        records += [{'direction':'send','message':{'method':'turn/start','params':{'input':[{'type':'text','text':text}]}}} for text in ['First','Second']]
        self.assertEqual([],validate_protocol(records,case,provenance))
        wrong=copy.deepcopy(records);wrong[1]['message']['params']['input'][0]['text']='tampered'
        self.assertIn('actual user text/order differs from fixture',validate_protocol(wrong,case,provenance))
        wrong=copy.deepcopy(records);wrong[0]['message']['params']['dynamicTools'][0]['name']='external_write'
        self.assertIn('actual dynamic tool schema digest mismatch',validate_protocol(wrong,case,provenance))
        wrong=copy.deepcopy(records);wrong[0]['message']['params']['developerInstructions']='tampered'
        self.assertIn('actual developer instructions digest mismatch',validate_protocol(wrong,case,provenance))

    def test_audit_scope_is_explicit_and_rejects_unknown_cases(self):
        manifest=json.loads((Path(__file__).parent/'manifest.json').read_text(encoding='utf-8'))
        delta=select_entries(manifest,['S02-base','S03-base','S04-base','S05-base','S13-base','S14-base'])
        self.assertEqual(12,sum(len(e['phases']) for e in delta))
        heldout=select_entries(manifest,['H06','H11'])
        self.assertEqual(2,sum(len(e['phases']) for e in heldout))
        with self.assertRaises(ValueError):
            select_entries(manifest,['S99-base'])
        with self.assertRaises(ValueError):
            select_entries(manifest,[])

    def test_actual_steer_text_and_boundary_are_audited(self):
        provenance={'adapterSha256':sha(b'a'),'toolSchemaSha256':sha(b'[]')}
        case={'turns':[{'text':'Deliver','steer':{'text':'Status?','afterOperation':'commit'}}]}
        records=[{'direction':'send','message':{'method':'thread/start','params':{'developerInstructions':'a','dynamicTools':[]}}},
            {'direction':'send','message':{'method':'turn/start','params':{'input':[{'type':'text','text':'Deliver'}]}}},
            {'direction':'receive','message':{'method':'item/tool/call','params':{'arguments':{'operation':'commit'}}}},
            {'direction':'send','message':{'id':4,'method':'turn/steer','params':{'input':[{'type':'text','text':'Status?'}]}}},
            {'direction':'receive','message':{'id':4,'result':{}}}]
        self.assertEqual([],validate_protocol(records,case,provenance))
        wrong=copy.deepcopy(records);wrong[3]['message']['params']['input'][0]['text']='Approve?'
        self.assertIn('actual steering text/operation boundary mismatch',validate_protocol(wrong,case,provenance))


if __name__ == '__main__':
    unittest.main()
