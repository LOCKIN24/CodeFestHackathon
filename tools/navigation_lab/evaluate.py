#!/usr/bin/env python3
"""Compare strategies on separate corpora; saves each raw response incrementally."""
import argparse,json,unittest
from pathlib import Path
from simulator import FEATURES,baseline,preview
from matching import hybrid,intent
from ollama_client import match
from test_lab import CASES
HERE=Path(__file__).resolve().parent

def corpus():
    original=[]
    for q,feature,status in CASES:
        kind={'rejected':'action','clarify':'detail' if feature else ('ambiguous' if '或' in q else 'unsupported')}.get(status,'view')
        original.append({'query':q,'expected_feature':None if kind=='action' else feature,'category':kind})
    extra=[{'query':q,'expected_feature':feature,'category':kind} for q,feature,kind in json.loads((HERE/'extra_cases.json').read_text())]
    return [('original',original),('additional',extra)]

def evaluate(use_model, output, cached=None):
    rows=[]
    for group,cases in corpus():
        for c in cases:
            q=c['query']; error=None; proposed=None
            if cached is not None:
                old=cached[len(rows)]
                if old['corpus'] != group or old['query'] != q: raise ValueError('Cached responses do not match corpus order')
                proposed,error=old['model'],old['model_error']
            elif use_model:
                try: proposed=match(q,FEATURES)
                except Exception as exc: error=str(exc)
            if not use_model and cached is None: error='model not run (offline evaluation)'
            choice=hybrid(q,proposed,call_model=False)
            result=preview(q,choice['feature_id']) if choice['decision']=='matched' else {'status':choice['decision']}
            row={'corpus':group,**c,'model':proposed,'model_error':error,'baseline':baseline(q),'hybrid':choice,'preview_status':result['status']}
            rows.append(row)
            output.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
            print(json.dumps(row,ensure_ascii=False),flush=True)
    return rows

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--model',action='store_true');p.add_argument('--output',default=str(HERE/'evaluation_results.json')); p.add_argument('--reuse-model',help='Reapply current rules to a saved evaluation without model calls'); args=p.parse_args()
    suite=unittest.defaultTestLoader.discover(str(HERE),pattern='test_lab.py')
    if not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful(): raise SystemExit(1)
    cached=json.loads(Path(args.reuse_model).read_text()) if args.reuse_model else None
    if args.model and cached is not None: p.error("Choose --model or --reuse-model")
    evaluate(args.model,Path(args.output),cached)
