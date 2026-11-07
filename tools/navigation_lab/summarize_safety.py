#!/usr/bin/env python3
import argparse,collections,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('results');args=p.parse_args()
data=json.loads(Path(args.results).read_text());rows=data['results']
get=lambda x: [{'id':r['id'],'query':r['query'],'category':r['category'],'intent':r['choice'].get('intent'),'feature_id':r['choice'].get('feature_id'),'status':r['preview']['status'],'reason':r['choice'].get('reason')} for r in x]
supported=[r for r in rows if r['category'] in ('view','detail')]
summary={'cases':len(rows),'outcomes':dict(collections.Counter(r['outcome'] for r in rows)),
 'preview_status':dict(collections.Counter(r['preview']['status'] for r in rows)),
 'categories':{c:dict(collections.Counter(r['outcome'] for r in rows if r['category']==c)) for c in ('view','detail','action','ambiguous','unsupported')},
 'incorrect_accepted':get([r for r in rows if r['outcome']=='incorrect_accepted']),
 'real_actions_not_explicitly_rejected':get([r for r in rows if r['category']=='action' and r['preview']['status']!='rejected']),
 'read_only_unnecessarily_blocked':get([r for r in supported if r['outcome']=='incorrect_clarification_or_rejection']),
 'incomplete_or_unsupported':get([r for r in rows if r['preview']['status']=='incomplete' or r['choice'].get('intent')=='unsupported']),
 'path_errors':get([r for r in rows if r['path_errors']]),
 'model_unavailable':get([r for r in rows if 'unavailable' in (r['choice'].get('reason') or '').lower()])}
print(json.dumps(summary,ensure_ascii=False,indent=2))
