#!/usr/bin/env python3
"""Read-only, source-audited navigation previews. Never invokes app APIs."""
import json, re
from collections import deque
from pathlib import Path
from ollama_client import match as model_match

ROOT = Path(__file__).resolve().parents[2]
def load(name, key):
    return json.loads((ROOT / 'docs' / (name + '.json')).read_text())[key]
FEATURES = {x['id']: x for x in load('APP_FEATURE_REGISTRY', 'features')}
EDGES = load('NAVIGATION_EDGES', 'edges')
CONTROLS = {x['id']: x for x in load('UI_CONTROL_REGISTRY', 'controls')}
ROUTES = load('ROUTE_AUDIT_REGISTRY', 'routes')
STATES = load('SCREEN_STATE_REGISTRY', 'states')
def baseline(query):
    q = query.casefold(); matches=[]
    for f in FEATURES.values():
        terms = [f['display_name'], *f.get('aliases', [])]
        found = [t for t in terms if len(t) > 1 and t.casefold() in q]
        if found: matches.append((max(map(len, found)), f['id']))
    if not matches: return None
    best=max(x[0] for x in matches); winners=[x[1] for x in matches if x[0]==best]
    return winners[0] if len(winners)==1 else None

def paths(target):
    # Only concrete screen-to-screen edges; exclude arbitrary/external transitions and action callbacks.
    q=deque([('flutter.main', [])]); seen={'flutter.main'}
    while q:
        current, path=q.popleft()
        if current==target: return path
        for e in EDGES:
            d=e.get('destination_screen_id'); cid=e.get('trigger_control_id')
            if e['source_screen_id']!=current or not d or d in seen or e.get('external_destination') or cid not in CONTROLS: continue
            if e['edge_id'].startswith(('fees.step.confirm','ticket.payment.confirm','buy.pay','citizen.form.done','disaster.form.done','police.form.done','application.preview.confirm')): continue
            seen.add(d); q.append((d,path+[e]))
    return None

def preview(query, feature_id):
    # Local import avoids a module import cycle; checks apply even to direct callers.
    from matching import intent, DETAIL
    mode=intent(query)
    if mode=='action': return {'status':'rejected','reason':'Real actions are unavailable.'}
    if mode=='multiple': return {'status':'clarify','reason':'Please choose one destination.'}
    if feature_id is None: return {'status':'clarify','reason':'No unique supported feature identified.'}
    if not isinstance(feature_id,str) or feature_id not in FEATURES: return {'status':'rejected','reason':'Unknown feature ID.'}
    f=FEATURES[feature_id]
    target=f['screen_id']; path=paths(target)
    result={'status':'preview','feature_id':feature_id,'feature_name':f['display_name'], 'screen_id':target,
            'feature_route':f.get('route'), 'entry_evidence':f.get('normal_entry_path'),
            'feature_required_parameters':f.get('required_parameters',[]), 'feature_prerequisites':f.get('prerequisites',[]),
            'limitations':f.get('known_limitations',[]), 'dependencies':f.get('source_dependencies',[]),
            'related_controls':[x for x in f.get('related_control_ids',[]) if x in CONTROLS],
            'screen_states':[{'id':s['id'],'condition':s.get('condition')} for s in STATES if s.get('parent_screen_id')==target],
            'route_audit':[{'id':r['id'],'path':r.get('path'),'parameters':r.get('parameters'),'reachability':r.get('reachability')} for r in ROUTES if r.get('screen_id')==target],
            'steps':[], 'missing':[], 'simulation':'No app navigation or action performed; source review is not runtime verification.'}
    if DETAIL.search(query):
        result['status']='clarify'
        result['missing'].append('The requested specific item and its audited item/route parameters are not supplied or validated.')
        if feature_id=='activity_information': result['missing'].append('ActivityList is required for the list; an ActivityItem is required for activity detail and cannot be fabricated.')
        if feature_id=='messages': result['missing'].append('A MessageItem is required for message detail and cannot be fabricated.')
        return result
    if feature_id == 'bills' and re.search(r'(?:繳費|付款|支付)(?:的)?(?:紀錄|記錄|歷史)|payment\s+(?:history|records?)|billing\s+history',query,re.I):
        edge=next((e for e in EDGES if e['edge_id']=='bills.history'),None)
        if edge and edge.get('trigger_control_id') in CONTROLS:
            result['recorded_boundary_edges']=[{'edge_id':edge['edge_id'],'source_screen_id':edge['source_screen_id'],'control_id':edge['trigger_control_id'],'destination_screen_id':edge['destination_screen_id'],'required_parameters':edge.get('required_parameters',[]),'prerequisites':edge.get('prerequisites',[]),'source':f"{edge.get('source_file')}:{edge.get('source_line')}"}]
        result['status']='incomplete'
        result['missing'].append('History is a recorded WebView boundary; the hosted destination and runtime state are not validated.')
        return result
    if path is None:
        result['status']='incomplete'; result['missing'].append('No complete recorded screen-to-screen path from flutter.main; entry evidence is not an executable edge.')
        # Show a relevant recorded boundary only, never join it to an unrecorded destination.
        edge_ids=set(f.get('related_edge_ids', []))
        result['recorded_boundary_edges']=[]
        for e in EDGES:
            if e['edge_id'] not in edge_ids or not (e.get('destination_screen_id') is None or e.get('destination_screen_id')=='flutter.webView') or e.get('trigger_control_id') not in CONTROLS: continue
            prefix=paths(e['source_screen_id'])
            if prefix is None: continue
            result['recorded_boundary_edges'].append({'prefix_edge_ids':[x['edge_id'] for x in prefix], 'edge_id':e['edge_id'],'source_screen_id':e['source_screen_id'],'control_id':e['trigger_control_id'],'destination_screen_id':e['destination_screen_id'],'required_parameters':e.get('required_parameters',[]),'prerequisites':e.get('prerequisites',[]),'source':f"{e.get('source_file')}:{e.get('source_line')}"})
        result['recorded_boundary_edges']=result['recorded_boundary_edges'][:8]
        return result
    for e in path:
        control=CONTROLS[e['trigger_control_id']]
        step={'edge_id':e['edge_id'],'from':e['source_screen_id'],'control_id':e['trigger_control_id'],'control_label':control.get('label'),'to':e['destination_screen_id'],'required_parameters':e.get('required_parameters',[]),'prerequisites':e.get('prerequisites',[]),'source':f"{e.get('source_file')}:{e.get('source_line')}"}
        result['steps'].append(step)
        for p in e.get('required_parameters',[]):
            # Only numeric, audit-recorded tab indexes are known without runtime state.
            if not (e.get('navigation_type')=='tab_selection' and p.get('name')=='index' and isinstance(p.get('value'),int)):
                result['missing'].append('Runtime argument required: '+str(p))
    for p in f.get('required_parameters',[]):
        if p.get('required'): result['missing'].append('Required feature parameter: '+str(p))
    if result['missing']: result['status']='incomplete'
    result['unverified_prerequisites'] = list(dict.fromkeys(f.get('prerequisites',[])+[p for e in path for p in e.get('prerequisites',[])]))
    return result

def main():
    print('TownPass read-only navigation lab. Type quit to exit.')
    while True:
        try: q=input('\nRequest> ').strip()
        except (EOFError,KeyboardInterrupt): break
        if q.lower() in ('quit','exit'): break
        if not q: continue
        from matching import hybrid
        choice=hybrid(q)
        result=preview(q,choice['feature_id']) if choice['decision']=='matched' else {'status':choice['decision'],'reason':choice.get('reason')}
        print(json.dumps({'baseline_feature_id':baseline(q),'hybrid':choice,'preview':result},ensure_ascii=False,indent=2))
if __name__=='__main__': main()
