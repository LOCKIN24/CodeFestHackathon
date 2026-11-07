import io, json, unittest
from unittest.mock import patch
from ollama_client import interpret
from matching import hybrid

FEATURES = {'language_settings': {'id': 'language_settings', 'display_name': '語言', 'aliases': [], 'description': ''}}

class GemmaClientTests(unittest.TestCase):
    def response(self, content):
        return io.BytesIO(json.dumps({'message': {'content': content}}).encode())

    def test_structured_request_and_valid_json(self):
        with patch('ollama_client.urllib.request.urlopen', return_value=self.response('{"intent":"browse_or_navigate","feature_id":"language_settings"}')) as call:
            self.assertEqual(interpret('帶我去語言設定', FEATURES)['feature_id'], 'language_settings')
            payload = json.loads(call.call_args.args[0].data)
            self.assertEqual(payload['model'], 'gemma3:4b')
            self.assertEqual(payload['format']['type'], 'object')
            self.assertEqual(payload['stream'], False)

    def test_invalid_response_fails_closed(self):
        for content in ['not json', '{"intent":"browse_or_navigate","feature_id":"/evil"}', '{"intent":"browse_or_navigate","feature_id":"language_settings","url":"https://evil"}']:
            with self.subTest(content=content), patch('ollama_client.urllib.request.urlopen', return_value=self.response(content)):
                with self.assertRaises((ValueError, TypeError)):
                    interpret('帶我去語言設定', FEATURES)
                with patch('matching.model_interpret', side_effect=ValueError('bad response')):
                    choice = hybrid('帶我去語言設定')
                    self.assertEqual(choice['decision'], 'clarify')
                    self.assertFalse(choice['action_allowed'])

if __name__ == '__main__': unittest.main()
