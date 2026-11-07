"""Loopback-only Ollama client; the model returns a feature ID and nothing executable."""
import json, os, urllib.request
URL='http://127.0.0.1:11434/api/chat'
MODEL=os.environ.get('NAV_LAB_MODEL', 'gemma3:4b')
def match(query, features):
    catalog=[{'id':f['id'],'name':f['display_name'],'aliases':f.get('aliases',[]),'description':f.get('description','')} for f in features.values()]
    schema={'type':'object','properties':{'feature_id':{'anyOf':[{'type':'string','enum':list(features)},{'type':'null'}]}},'required':['feature_id'],'additionalProperties':False}
    body={'model':MODEL,'stream':False,'format':schema,'options':{'temperature':0,'num_predict':100,'num_ctx':4096},'messages':[{'role':'system','content':'Choose the single best catalog feature for the user request. Return null for ambiguous or unsupported requests. Never supply routes or parameters. Catalog: '+json.dumps(catalog,ensure_ascii=False)},{'role':'user','content':query}]}
    request=urllib.request.Request(URL,data=json.dumps(body,ensure_ascii=False).encode(),headers={'Content-Type':'application/json'},method='POST')
    with urllib.request.urlopen(request,timeout=120) as response: data=json.load(response)
    result=json.loads(data['message']['content'])
    if set(result)!={'feature_id'} or (result['feature_id'] is not None and (not isinstance(result['feature_id'],str) or result['feature_id'] not in features)): raise ValueError('Invalid model response')
    return result['feature_id']

def interpret(query, features):
    """Propose an intent and feature only; no routes, arguments or commands."""
    catalog=[{'id':f['id'],'name':f['display_name'],'aliases':f.get('aliases',[]),'description':f.get('description','')} for f in features.values()]
    intents=['browse_or_navigate','perform_real_action','mixed_browse_and_action','unsupported','ambiguous']
    schema={'type':'object','properties':{'intent':{'type':'string','enum':intents},'feature_id':{'anyOf':[{'type':'string','enum':list(features)},{'type':'null'}]}},'required':['intent','feature_id'],'additionalProperties':False}
    system=('Classify the full user request. Opening or navigating to a settings screen is browse_or_navigate, not changing settings. For example, 帶我去語言設定 means browse_or_navigate with feature_id language_settings; Open account settings means browse_or_navigate with feature_id settings. Viewing a list or details is browse_or_navigate. '
            'A request to pay, buy, submit, edit, remove, renew, call or otherwise do something is perform_real_action; '
            'both viewing and performing is mixed_browse_and_action. Unsupported topics such as weather, transit or parking are unsupported even when a supported feature is mentioned. '
            'Multiple destinations or unclear intent are ambiguous. For unsupported or ambiguous requests return null feature_id. '
            'Return only the structured intent and a single catalog ID or null; never supply routes, URLs, arguments or commands. Catalog: '+json.dumps(catalog,ensure_ascii=False))
    body={'model':MODEL,'stream':False,'format':schema,'options':{'temperature':0,'num_predict':100,'num_ctx':4096},'messages':[{'role':'system','content':system},{'role':'user','content':query}]}
    request=urllib.request.Request(URL,data=json.dumps(body,ensure_ascii=False).encode(),headers={'Content-Type':'application/json'},method='POST')
    with urllib.request.urlopen(request,timeout=120) as response: data=json.load(response)
    result=json.loads(data['message']['content'])
    if not isinstance(result,dict) or set(result)!={'intent','feature_id'} or result['intent'] not in intents or (result['feature_id'] is not None and (not isinstance(result['feature_id'],str) or result['feature_id'] not in features)): raise ValueError('Invalid model response')
    return result
