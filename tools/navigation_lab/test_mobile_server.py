import json, threading, unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from unittest.mock import patch
from mobile_server import Handler, private_ip

class MobileServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        cls.server.allowed_client='127.0.0.1'; cls.server.token='x'*32
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True); cls.thread.start()
    @classmethod
    def tearDownClass(cls): cls.server.shutdown(); cls.server.server_close(); cls.thread.join()
    def call(self,body,headers=None):
        conn=HTTPConnection('127.0.0.1',self.server.server_port,timeout=3)
        conn.request('POST','/api/mobile/preview',json.dumps(body),headers or {})
        res=conn.getresponse(); data=json.loads(res.read()); conn.close(); return res.status,data
    def test_restrict_bind_addresses(self):
        self.assertEqual(private_ip('192.168.1.2'),'192.168.1.2')
        for addr in ('0.0.0.0','8.8.8.8','example.com'):
            with self.assertRaises(Exception):private_ip(addr)
    def test_auth_and_browser_origin_required(self):
        self.assertEqual(self.call({'query':'x'})[0],401)
        self.assertEqual(self.call({'query':'x'},{'Authorization':'Bearer '+'x'*32,'Origin':'http://127.0.0.1'})[0],403)
    def test_other_clients_are_refused(self):
        self.server.allowed_client='127.0.0.2'
        try:
            self.assertEqual(self.call({'query':'x'},{'Authorization':'Bearer '+'x'*32,'Content-Type':'application/json'})[0],403)
        finally:
            self.server.allowed_client='127.0.0.1'

    def test_unavailable_model_and_real_action(self):
        headers={'Authorization':'Bearer '+'x'*32,'Content-Type':'application/json'}
        with patch('matching.model_interpret', side_effect=OSError('offline')):
            status,data=self.call({'query':'我要查看語言設定'},headers)
        self.assertEqual(status,200);self.assertEqual(data['preview']['status'],'clarify');self.assertIn('unavailable',data['choice']['reason'])
        status,data=self.call({'query':'請幫我完成付款'},headers)
        self.assertEqual(status,200);self.assertEqual(data['preview']['status'],'rejected');self.assertIs(data['choice']['action_allowed'],False)

    def test_navigation_eligibility_is_separate_and_narrow(self):
        headers={'Authorization':'Bearer '+'x'*32,'Content-Type':'application/json'}
        choice={'intent':'browse_or_navigate','decision':'matched','action_allowed':False,'feature_id':'language_settings','source':'name_or_alias'}
        with patch('mobile_server.hybrid',return_value=choice), patch('mobile_server.preview',return_value={'status':'preview','feature_id':'language_settings'}):
            _,data=self.call({'query':'帶我去語言設定'},headers)
            self.assertTrue(data['navigation_eligible']); self.assertFalse(data['choice']['action_allowed'])
        for changed in ({'decision':'clarify'}, {'intent':'perform_real_action'}, {'source':'model_with_evidence'}, {'feature_id':'settings'}, {'action_allowed':True}):
            with self.subTest(changed=changed), patch('mobile_server.hybrid',return_value={**choice,**changed}), patch('mobile_server.preview',return_value={'status':'preview','feature_id':'language_settings'}):
                _,data=self.call({'query':'x'},headers)
                self.assertFalse(data['navigation_eligible'])

    def test_activity_eligibility_requires_matched_list_not_detail(self):
        headers={'Authorization':'Bearer '+'x'*32,'Content-Type':'application/json'}
        choice={'intent':'browse_or_navigate','decision':'matched','action_allowed':False,'feature_id':'activity_information','source':'name_or_alias'}
        for status,eligible in [('incomplete',True),('clarify',False),('rejected',False)]:
            with self.subTest(status=status), patch('mobile_server.hybrid',return_value=choice), patch('mobile_server.preview',return_value={'status':status,'feature_id':'activity_information'}):
                _,data=self.call({'query':'我要看活動訊息'},headers)
                self.assertEqual(data['navigation_eligible'],eligible)
                self.assertFalse(data['choice']['action_allowed'])

    def test_read_only_response_and_validation(self):
        headers={'Authorization':'Bearer '+'x'*32,'Content-Type':'application/json'}
        with patch('mobile_server.hybrid',return_value={'intent':'perform_real_action','decision':'rejected','action_allowed':False,'feature_id':None,'reason':'No actions'}):
            status,data=self.call({'query':'付款'},headers)
        self.assertEqual(status,200);self.assertIs(data['choice']['action_allowed'],False);self.assertEqual(data['preview']['status'],'rejected')
        self.assertEqual(self.call({'query':'x','route':'/anything'},headers)[0],400)
