#!/usr/bin/env python3
"""Summarize a completed evaluation without contacting the model."""
import collections,json
from pathlib import Path
P=Path(__file__).resolve().parent
rows=json.loads((P/'evaluation_results.json').read_text())
summary={}
for group in ('original','additional','all'):
    data=[r for r in rows if group=='all' or r['corpus']==group]
    supported=[r for r in data if r['category'] in ('view','detail')]
    stats={'cases':len(data),'model_errors':sum(bool(r['model_error']) for r in data),
        'model_id_matches':sum(r['model']==r['expected_feature'] and not r['model_error'] for r in data),
        'baseline_id_matches':sum(r['baseline']==r['expected_feature'] for r in data),
        'hybrid_id_matches':sum(r['hybrid']['feature_id']==r['expected_feature'] for r in data),
        'supported_requests':len(supported),
        'supported_correct':{key:sum((r['hybrid']['feature_id'] if key=='hybrid' else r[key])==r['expected_feature'] and (key!='model' or not r['model_error']) for r in supported) for key in ('model','baseline','hybrid')},
        'incorrect_accepted':[{'query':r['query'],'expected':r['expected_feature'],'actual':r['hybrid']['feature_id'],'category':r['category']} for r in data if r['hybrid']['decision']=='matched' and r['hybrid']['feature_id']!=r['expected_feature']],
        'status_counts':dict(collections.Counter(r['preview_status'] for r in data)),
        'action_decisions':dict(collections.Counter(r['hybrid']['decision'] for r in data if r['category']=='action')),
        'unsupported_ambiguous_decisions':dict(collections.Counter(r['hybrid']['decision'] for r in data if r['category'] in ('unsupported','ambiguous'))),
        'false_rejections':[r['query'] for r in supported if r['preview_status']=='rejected'],
        'supported_clarifications':[r['query'] for r in supported if r['preview_status']=='clarify'],
        'details':len([r for r in supported if r['category']=='detail'])}
    summary[group]=stats
(P/'evaluation_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
