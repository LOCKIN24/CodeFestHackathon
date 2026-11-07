#!/usr/bin/env python3
"""Independent initial evaluation, using the unchanged live hybrid flow."""
import argparse,hashlib,json
from pathlib import Path
from matching import hybrid
from simulator import FEATURES,EDGES,CONTROLS,ROUTES,preview
P=Path(__file__).resolve().parent
FROZEN={'matching.py':'c26da4a516c4d986d72b9f4641c91c503949f35bfd5c825c4a85c16002b0a704','simulator.py':'ff96c7277a0aba37e71eb4fc4cf536749939674f8705623051432529fc323a90','ollama_client.py':'5c06eae3132051c4f87e342107de46d1a9b131ad0c9071bb1583461f1f5d12fd'}
for name,expected in FROZEN.items():
    if hashlib.sha256((P/name).read_bytes()).hexdigest()!=expected: raise SystemExit('Frozen file changed: '+name)
E={e['edge_id']:e for e in EDGES}
def audit_path(out):
    errors=[]; prev='flutter.main'
    for step in out.get('steps',[]):
        edge=E.get(step.get('edge_id'))
        if not edge: errors.append('Unknown edge'); continue
        if edge['source_screen_id']!=prev or edge['source_screen_id']!=step.get('from') or edge['destination_screen_id']!=step.get('to') or edge['trigger_control_id']!=step.get('control_id') or edge['trigger_control_id'] not in CONTROLS: errors.append('Edge mismatch or disconnected step')
        prev=step.get('to')
    for boundary in out.get('recorded_boundary_edges',[]):
        edge=E.get(boundary.get('edge_id'))
        if not edge or any(edge.get(k)!=boundary.get(k) for k in ('source_screen_id','destination_screen_id')) or edge.get('trigger_control_id')!=boundary.get('control_id'): errors.append('Boundary mismatch')
        for prefix_id in boundary.get('prefix_edge_ids',[]):
            if prefix_id not in E: errors.append('Unknown prefix edge')
    if out.get('feature_id') in FEATURES and out.get('screen_id')!=FEATURES[out['feature_id']]['screen_id']: errors.append('Feature destination mismatch')
    return errors

def run(output):
    cases=json.loads((P/'independent_cases.json').read_text()); rows=[]
    for index,(query,expected,category) in enumerate(cases,1):
        choice=hybrid(query)
        out=preview(query,choice['feature_id']) if choice['decision']=='matched' else {'status':choice['decision'],'reason':choice.get('reason')}
        actual=choice.get('feature_id'); status=out['status']; errors=audit_path(out)
        if category in ('view','detail'):
            if actual==expected and ((category=='view' and status in ('preview','incomplete')) or (category=='detail' and status in ('clarify','incomplete'))): outcome='correct_accepted' if category=='view' else 'correct_clarification'
            elif actual is None or status in ('clarify','rejected'): outcome='incorrect_clarification_or_rejection'
            else: outcome='incorrect_accepted'
        elif category=='action': outcome='correct_rejection' if status=='rejected' else ('incorrect_accepted' if status in ('preview','incomplete') else 'incorrect_clarification_or_rejection')
        else: outcome='correct_clarification' if status in ('clarify','rejected') else 'incorrect_accepted'
        row={'id':index,'query':query,'expected_feature':expected,'category':category,'choice':choice,'preview':out,'outcome':outcome,'structural_path_errors':errors,'unsupported_path_suggested':outcome=='incorrect_accepted' and status in ('preview','incomplete')}
        rows.append(row); output.write_text(json.dumps({'frozen_sha256':FROZEN,'results':rows},ensure_ascii=False,indent=2)+'\n')
        print(index,category,outcome,status,query,flush=True)
if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--output',default=str(P/'independent_rerun_results.json')); args=parser.parse_args()
    run(Path(args.output))
