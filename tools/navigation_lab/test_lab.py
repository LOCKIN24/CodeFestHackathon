#!/usr/bin/env python3
import argparse, json, time, unittest
from pathlib import Path
from simulator import FEATURES, baseline, preview
from ollama_client import match

CASES=[
 ('我要查圖書借閱','library_services','incomplete'),('我要看活動訊息','activity_information','incomplete'),
 ('幫我找市政申辦','municipal_applications','incomplete'),('我要查看我的票夾','ticket_wallet','incomplete'),
 ('我要開啟語言設定','language_settings','preview'),('Where can I find QR scanning?','qr_scan','incomplete'),
 ('How do I view account settings?','settings','preview'),('我要看首頁','home','preview'),
 ('查看基本資料','personal_information','preview'),('查看訊息','messages','preview'),
 ('我想看服務','services','preview'),('我想看優惠券','perks','preview'),
 ('我要看活動詳情','activity_information','clarify'),('我要看特定訊息詳情','messages','clarify'),
 ('我要看天氣預報',None,'clarify'),('Help me find parking payments',None,'clarify'),
 ('請付款',None,'rejected'),('Submit my application','municipal_applications','rejected'),
 ('我要查看語言設定並修改帳號','language_settings','rejected'),('打電話給市政府',None,'rejected'),
 ('我要查看意見回饋','feedback','preview'),('查看警政服務','online_police','incomplete'),
 ('我要查看圖書館或票夾',None,'clarify')]
class SafetyTests(unittest.TestCase):
 def test_labeled_preview_statuses(self):
  for query, feature, status in CASES:
   with self.subTest(query=query): self.assertEqual(preview(query,feature)['status'],status)
 def test_read_only_and_action_intents(self):
  from matching import hybrid
  self.assertEqual(hybrid('我要查看繳費紀錄',call_model=False)['feature_id'],'bills')
  for q in ('我要查看繳費紀錄','哪裡能看繳費歷史？','有沒有地方看以前的付款記錄？'):
   p=preview(q,'bills'); self.assertEqual(p['status'],'incomplete'); self.assertEqual(p['recorded_boundary_edges'][0]['edge_id'],'bills.history')
  for q in ['請幫我完成付款','查看票夾並付款','Please pay my bill now']:
   self.assertEqual(hybrid(q,call_model=False)['decision'],'rejected')
 def test_model_validation_and_ambiguity(self):
  from matching import hybrid
  self.assertEqual(hybrid('Where is the scanner?',proposed='https://example.com',call_model=False)['decision'],'rejected')
  self.assertEqual(hybrid('我要查票夾或圖書館',proposed='ticket_wallet',call_model=False)['decision'],'clarify')
  self.assertEqual(hybrid('Find parking payments',proposed='bills',call_model=False)['decision'],'clarify')
  self.assertEqual(hybrid('查看訊息和票夾',proposed='messages',call_model=False)['decision'],'clarify')
  self.assertEqual(hybrid('查看付款紀錄並付款',proposed='bills',call_model=False)['decision'],'rejected')
 def test_hybrid_exact_and_semantic(self):
  from matching import hybrid
  self.assertEqual(hybrid('How do I view account settings?',proposed='account',call_model=False)['feature_id'],'settings')
  self.assertEqual(hybrid('Where can I find QR scanning?',proposed='qr_scan',call_model=False)['feature_id'],'qr_scan')
  self.assertEqual(hybrid('我要開啟語言設定',call_model=False)['feature_id'],'language_settings')
  self.assertEqual(hybrid('Show a specific activity detail',proposed='activity_information',call_model=False)['feature_id'],'activity_information')
 def test_no_fabricated_activity_detail(self):
  p=preview('查看活動詳情','activity_information'); self.assertEqual(p['status'],'clarify'); self.assertIn('ActivityItem',str(p['missing'])); self.assertIn('ActivityList',str(p['missing']))
 def test_structured_intent_and_action_denial(self):
  from matching import hybrid
  for q in ['先看票夾，再替我買一張票','Please settle my bill','打給市府專線']:
   c=hybrid(q,call_model=False); self.assertEqual(c['decision'],'rejected'); self.assertIn(c['intent'],('perform_real_action','mixed_browse_and_action')); self.assertFalse(c['action_allowed'])
  c=hybrid('我想看城市天氣，從首頁找得到嗎？',call_model=False); self.assertEqual(c['intent'],'unsupported'); self.assertIsNone(c['feature_id'])
 def test_model_is_not_authority(self):
  from matching import hybrid
  q='我要查看我的票夾'
  for decision in ({'intent':'perform_real_action','feature_id':'ticket_wallet'},{'intent':'unsupported','feature_id':None},{'intent':'browse_or_navigate','feature_id':'home'},{'intent':'browse_or_navigate','feature_id':'https://example.com'}):
   self.assertNotEqual(hybrid(q,call_model=False,model_result=decision)['decision'],'matched')
  c=hybrid(q,call_model=False,model_result={'intent':'browse_or_navigate','feature_id':'ticket_wallet'}); self.assertEqual(c['decision'],'matched'); self.assertFalse(c['action_allowed'])
 def test_unknown_id(self): self.assertEqual(preview('test','invented')['status'],'rejected')
 def test_untrusted_url(self): self.assertEqual(preview('test','https://example.com')['status'],'rejected')
 def test_typed_argument_missing(self):
  p=preview('我要看活動訊息','activity_information'); self.assertEqual(p['status'],'incomplete'); self.assertIn('ActivityList',str(p['missing']))
 def test_dynamic_detail(self): self.assertEqual(preview('查看活動詳情','activity_information')['status'],'clarify')
 def test_graph_gap(self): self.assertEqual(preview('我要查圖書借閱','library_services')['status'],'incomplete')
 def test_unimplemented_and_mock_are_reported(self):
  self.assertIn('empty',str(preview('查看意見回饋','feedback')).lower())
  self.assertIn('mock',str(preview('查看訊息','messages')).lower())
 def test_steps_resolve_controls_and_edges(self):
  p=preview('語言設定','language_settings'); self.assertEqual(p['status'],'preview'); self.assertTrue(p['steps']); self.assertTrue(all(s['control_id'] and s['source'] for s in p['steps']))
 def test_forbidden(self): self.assertEqual(preview('Submit my application','municipal_applications')['status'],'rejected')

def run_comparison(use_model):
 rows=[]
 for query,expected,status in CASES:
  b=baseline(query); err=None
  try: m=match(query,FEATURES) if use_model else None
  except Exception as exc: m=None; err=str(exc)
  p=preview(query,m if use_model else b)
  rows.append({'request':query,'expected_feature':expected,'baseline':b,'model':m,'model_error':err,'expected_status':status,'actual_status':p['status']})
  print(json.dumps(rows[-1],ensure_ascii=False),flush=True)
 Path(__file__).with_name('results.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
 return rows
if __name__=='__main__':
 parser=argparse.ArgumentParser(); parser.add_argument('--model',action='store_true'); args=parser.parse_args()
 suite=unittest.defaultTestLoader.loadTestsFromTestCase(SafetyTests); result=unittest.TextTestRunner(verbosity=2).run(suite)
 if not result.wasSuccessful(): raise SystemExit(1)
 run_comparison(args.model)
