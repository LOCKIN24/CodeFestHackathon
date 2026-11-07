#!/usr/bin/env python3
"""Evaluate revised matcher against a labeled corpus, with path integrity checks."""
import argparse,hashlib,json,collections
from pathlib import Path
from matching import hybrid
from simulator import FEATURES,EDGES,CONTROLS,preview
P=Path(__file__).resolve().parent
E={e['edge_id']:e for e in EDGES}
def path_errors(out):
    errors=[]; prev='flutter.main'
    for step in out.get('steps',[]):
        e=E.get(step.get('edge_id'))
        if not e or e.get('source_screen_id')!=prev or e.get('source_screen_id')!=step.get('from') or e.get('destination_screen_id')!=step.get('to') or e.get('trigger_control_id')!=step.get('control_id') or step.get('control_id') not in CONTROLS: errors.append('Step does not match a connected audited edge/control')
        prev=step.get('to')
    for b in out.get('recorded_boundary_edges',[]):
        e=E.get(b.get('edge_id'))
        if not e or e.get('source_screen_id')!=b.get('source_screen_id') or e.get('destination_screen_id')!=b.get('destination_screen_id') or e.get('trigger_control_id')!=b.get('control_id'): errors.append('Boundary does not match an audited edge')
    return errors

def run(corpus,output,freeze=None):
    cases=json.loads(corpus.read_text()); rows=[]
    hashes={name:hashlib.sha256((P/name).read_bytes()).hexdigest() for name in ('matching.py','simulator.py','ollama_client.py')}
    if freeze and hashes != json.loads(freeze.read_text())['rule_sha256']: raise SystemExit('Frozen rule hashes differ; holdout not run.')
    for index,(q,expected,category) in enumerate(cases,1):
        choice=hybrid(q); fid=choice['feature_id']; status=choice['decision']
        out=preview(q,fid) if status=='matched' else {'status':status,'reason':choice.get('reason')}
        status=out['status']; correct_feature=bool(expected and fid==expected)
        if category in ('view','detail'):
            if fid is not None and fid!=expected: outcome='incorrect_accepted'
            elif correct_feature and (category=='view' and status in ('preview','incomplete') or category=='detail' and status in ('clarify','incomplete')): outcome='correct_feature_match'
            else: outcome='incorrect_clarification_or_rejection'
        elif category=='action': outcome='correct_rejection' if status=='rejected' else ('incorrect_accepted' if fid else 'incorrect_clarification_or_rejection')
        else: outcome='incorrect_accepted' if fid else 'correct_clarification_or_rejection'
        row={'id':index,'query':q,'expected_feature':expected,'category':category,'choice':choice,'preview':out,'outcome':outcome,'path_errors':path_errors(out)}
        rows.append(row); output.write_text(json.dumps({'rule_sha256':hashes,'corpus':corpus.name,'results':rows},ensure_ascii=False,indent=2)+'\n')
        print(index,category,outcome,status,q,flush=True)
    print('OUTCOMES',dict(collections.Counter(x['outcome'] for x in rows)),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('corpus');p.add_argument('--output',required=True);p.add_argument('--freeze');a=p.parse_args();run(Path(a.corpus),Path(a.output),Path(a.freeze) if a.freeze else None)
