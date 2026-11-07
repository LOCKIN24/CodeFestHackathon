#!/usr/bin/env python3
"""Check recorded map integrity and report coverage; not behavioral verification."""
import json
from pathlib import Path
import re
from collections import Counter

root = Path(__file__).resolve().parent.parent
docs = root / 'docs'
def read(name):
    return json.loads((docs / name).read_text())
controls = read('UI_CONTROL_REGISTRY.json')['controls']
edges_doc = read('NAVIGATION_EDGES.json')
edges = edges_doc['edges']
states = read('SCREEN_STATE_REGISTRY.json')['states']
features = read('APP_FEATURE_REGISTRY.json')['features']
route_doc = read('ROUTE_AUDIT_REGISTRY.json')
routes = route_doc['routes']
queue_doc = read('MAP_AUDIT_QUEUE.json')
queue = queue_doc['candidates']
inv = (docs / 'SCREEN_INVENTORY.md').read_text()
def unique(rows, key):
    values = [x[key] for x in rows]
    assert len(values) == len(set(values)), f'duplicate {key}'
for rows, key in [(controls,'id'),(edges,'edge_id'),(states,'id'),(features,'id'),(routes,'id'),(queue,'id')]: unique(rows,key)
control_ids = {x['id'] for x in controls}
control_map = {x['id']: x for x in controls}
def screen(s):
    assert isinstance(s,str) and re.search(r'\|\s*' + re.escape(s) + r'\s*\|', inv), f'unknown screen: {s}'
def source(row):
    f = root / row['source_file']
    assert f.is_file(), f'missing source: {f}'
    if 'source_line' in row:
        assert 1 <= row['source_line'] <= len(f.read_text().splitlines()), f'invalid line: {f}'
for c in controls:
    screen(c['parent_screen_id']); source(c)
    for other_screen in c.get('other_parent_screen_ids', []): screen(other_screen)
for e in edges:
    screen(e['source_screen_id']); source(e)
    status = e.get('semantic_audit_status')
    if status is not None:
        assert status in {'verified_from_source','source_limitation_documented','unresolvable_from_source'}, f"invalid semantic status: {e['edge_id']}"
        assert e.get('semantic_audit_reason') and e.get('semantic_audit_evidence'), f"missing semantic evidence: {e['edge_id']}"
        for item in e['semantic_audit_evidence']:
            path, line = item.rsplit(':',1)
            source({'source_file':path,'source_line':int(line)})
    dest = e.get('destination_screen_id')
    if dest: screen(dest)
    else: assert e.get('destination_type') in {'history_back','navigator_pop','conditional','external_destination','unknown'}, f"missing dynamic destination: {e['edge_id']}"
    assert e['trigger_control_id'] in control_ids, f"unknown trigger: {e['trigger_control_id']}"
    trigger = control_map[e['trigger_control_id']]
    assert e['source_screen_id'] in [trigger['parent_screen_id'], *trigger.get('other_parent_screen_ids', [])], f"trigger screen mismatch: {e['edge_id']}"
    assert isinstance(e.get('required_parameters'),list), f"missing parameter list: {e['edge_id']}"
for s in states:
    screen(s['parent_screen_id']); source(s)
    status = s.get('semantic_audit_status')
    if status is not None:
        assert status in {'verified_from_source','source_limitation_documented','unresolvable_from_source'}, f"invalid state semantic status: {s['id']}"
        assert s.get('semantic_audit_reason') and s.get('semantic_audit_evidence'), f"missing state semantic evidence: {s['id']}"
        for item in s['semantic_audit_evidence']:
            path, line = item.rsplit(':', 1)
            source({'source_file': path, 'source_line': int(line)})
    for other_screen in s.get('other_parent_screen_ids', []): screen(other_screen)
    for control_id in s.get('related_control_ids', []):
        assert control_id in control_ids, f"unknown state control: {control_id}"
        control = control_map[control_id]
        assert s['parent_screen_id'] in [control['parent_screen_id'], *control.get('other_parent_screen_ids', [])], f"state control context mismatch: {s['id']} / {control_id}"
for f in features:
    screen(f['screen_id']); source(f)
    assert not f['allowed_ai_actions'], f"AI action enabled: {f['id']}"
    for related_screen in f.get('related_screen_ids', []): screen(related_screen)
    for control_id in f.get('related_control_ids', []):
        assert control_id in control_ids, f"unknown feature control: {control_id}"
        ctrl = control_map[control_id]
        assert set([ctrl['parent_screen_id'], *ctrl.get('other_parent_screen_ids', [])]) & set(f.get('related_screen_ids', [])), f"feature control outside screen contexts: {f['id']} / {control_id}"
    if f.get('source_audit_status') == 'reviewed':
        for field in ('normal_entry_path', 'related_screen_ids', 'related_edge_ids', 'source_dependencies', 'known_limitations', 'source_audit_evidence'):
            assert f.get(field), f"missing audited feature field {field}: {f['id']}"
        for evidence in f['source_audit_evidence']:
            path, line = evidence.rsplit(':', 1)
            source({'source_file': path, 'source_line': int(line)})
for u in edges_doc.get('unresolved',[]): source(u)
edge_ids = {x['edge_id'] for x in edges}
for f in features:
    for edge_id in f.get('related_edge_ids', []):
        assert edge_id in edge_ids, f'unknown feature edge: {edge_id}'
        feature_edge = next(e for e in edges if e['edge_id'] == edge_id)
        assert feature_edge['trigger_control_id'] in f.get('related_control_ids', []), f"feature edge trigger missing: {f['id']} / {edge_id}"
        assert feature_edge['source_screen_id'] in f.get('related_screen_ids', []), f"feature edge source missing: {f['id']} / {edge_id}"
triggers = {e['trigger_control_id'] for e in edges}
for control in controls:
    if control['classification'] in {'navigation', 'history_back'}:
        assert control['id'] in triggers, f"navigation control without edge: {control['id']}"
for e in edges:
    for parameter in e['required_parameters']:
        assert isinstance(parameter, dict) and parameter.get('name'), f"invalid parameter: {e['edge_id']}"
flutter_routes = len(re.findall(r'\bGetPage\s*\(', (root / 'TownPass/lib/util/tp_route.dart').read_text()))
vue_routes = len(re.findall(r'^\s*path\s*:', (root / 'TownPass-Services/src/router/index.ts').read_text(), re.M))
assert (flutter_routes, vue_routes) == (21, 55), f'route counts changed: {flutter_routes}, {vue_routes}'
assert len(routes) == flutter_routes + vue_routes, 'route audit record count mismatch'
for route in routes:
    source({'source_file':route['registration_source'],'source_line':route['registration_line']})
    registration_lines = (root / route['registration_source']).read_text().splitlines()
    registration_line = registration_lines[route['registration_line'] - 1]
    if route['framework'] == 'vue':
        match = re.search(r"path:\s*'([^']*)'", registration_line)
        assert match is not None, f"route line does not declare path: {route['id']}"
        part = match.group(1)
        if route['parent_route_id']:
            parent = next(r for r in routes if r['id'] == route['parent_route_id'])
            assert route['path'] == parent['path'].rstrip('/') + '/' + part, f"route path mismatch: {route['id']}"
        else:
            assert route['path'] == part, f"route path mismatch: {route['id']}"
    else:
        following = '\n'.join(registration_lines[route['registration_line'] - 1:route['registration_line'] + 3])
        assert re.search(r'\bname:\s*' + re.escape(route['name']) + r'\b', following), f"route name mismatch: {route['id']}"
    if route['screen_id']:
        screen(route['screen_id'])
        assert (root / route['component_source']).is_file(), f"missing route component: {route['id']}"
    else:
        assert route['framework'] == 'vue' and route['component_source'] is None, f"invalid componentless route: {route['id']}"
    if route['parent_route_id']:
        assert route['parent_route_id'] in {r['id'] for r in routes}, f"unknown route parent: {route['id']}"
    assert route['audit_status'] in {'pending','source_reviewed'}
    if route['audit_status'] == 'source_reviewed':
        assert isinstance(route['parameters'], dict) and route['dependencies'] and route['reachability'] and route.get('audit_evidence'), f"missing route audit fields: {route['id']}"
        for evidence in route['audit_evidence']:
            if re.search(r':\d+$', evidence):
                path, line = evidence.rsplit(':', 1)
                source({'source_file': path, 'source_line': int(line)})
            else:
                assert (root / evidence).is_file(), f"missing route audit evidence: {route['id']}"
        for arg in re.findall(r':(\w+)', route['path']):
            assert arg in route['parameters']['path_required'], f"missing path parameter: {route['id']}:{arg}"
print(f'PASS route record counts: {flutter_routes} Flutter, {vue_routes} Vue; route audit records validated.')
print(f"Route audit coverage: {sum(r['audit_status']=='source_reviewed' for r in routes)}/{len(routes)}.")
route_by_screen = {route['screen_id']: route for route in routes if route['screen_id']}
for e in edges:
    target = route_by_screen.get(e.get('destination_screen_id'))
    if target and target['audit_status'] == 'source_reviewed':
        params = target['parameters']
        if params.get('path_required') or (target['framework'] == 'flutter' and params.get('get_arguments', 'None') not in ('None', 'pending final review') and not params.get('get_arguments', '').startswith('WebViewArgument optional')):
            assert e['required_parameters'], f"target needs arguments but edge has none: {e['edge_id']}"
statuses = {'pending','source_reviewed','false_positive','duplicate','unresolvable'}
for item in queue:
    source(item)
    assert item['kind'] in {'control','navigation','modal'} and item['status'] in statuses
    assert item['classification']
    if item['status'] != 'pending':
        assert item.get('reason') and item.get('evidence'), f"missing review evidence: {item['id']}"
for filename,kind in [('SOURCE_CONTROL_INDEX.md','control'),('SOURCE_EDGE_INDEX.md','navigation')]:
    modal=False; expected=[]
    for line in (docs/filename).read_text().splitlines():
        if line.startswith('## Modal candidates'): modal=True
        match=re.match(r'\| `([^`]+)` \| (\d+) \| `([^`]*)`',line)
        if match: expected.append(('modal' if modal else kind,match.group(1),int(match.group(2))))
    actual=[(x['kind'],x['source_file'],x['source_line']) for x in queue if x['kind'] in ({'control','modal'} if kind=='control' else {'navigation'})]
    assert Counter(expected)==Counter(actual), f'queue differs from {filename}'
counts=Counter(x['status'] for x in queue)
complete=not counts['pending'] and not counts['unresolvable']
if queue_doc['status']=='complete': assert complete, 'queue claims completion with pending or unresolvable candidates'
checklist = (docs / 'MAP_REMAINING_MODULES.md').read_text()
module_rows = re.findall(r'^\| ([a-z][a-z0-9-]+) \|.*?\| (checked|excluded|pending) \|', checklist, re.M)
assert len(module_rows) == 14 and len({row[0] for row in module_rows}) == 14, 'module checklist malformed'
if '**COMPLETE**' in (docs / 'MAP_PROGRESS.md').read_text().splitlines()[2]:
    assert all(status in {'checked', 'excluded'} for _, status in module_rows), 'unfinished module checklist'
    assert all(e.get('semantic_audit_status') for e in edges), 'edge semantic audit incomplete'
    assert all(s.get('semantic_audit_status') for s in states), 'state semantic audit incomplete'
    assert all(f.get('source_audit_status') == 'reviewed' for f in features), 'feature audit incomplete'
    assert all(r['audit_status'] == 'source_reviewed' for r in routes), 'route audit incomplete'
    assert complete, 'candidate audit incomplete'
print(f"Module checklist: {sum(status in {'checked', 'excluded'} for _, status in module_rows)}/{len(module_rows)} terminal.")
print(f"PASS data integrity: {len(controls)} controls, {len(edges)} edges, {len(states)} states, {len(features)} features; {len(queue)} candidate records.")
print(f"Feature audit coverage: {sum(f.get('source_audit_status') == 'reviewed' for f in features)}/{len(features)}.")
print(f"Semantic state audit coverage: {sum(bool(s.get('semantic_audit_status')) for s in states)}/{len(states)}.")
print(f"Semantic edge audit coverage: {sum(bool(e.get('semantic_audit_status')) for e in edges)}/{len(edges)}.")
print('Coverage:', ', '.join(f'{k}={counts[k]}' for k in sorted(statuses)))
map_complete = '**COMPLETE**' in (docs / 'MAP_PROGRESS.md').read_text().splitlines()[2]
print('Source map coverage: ' + ('COMPLETE (bounded source audit; runtime unverified)' if map_complete else 'INCOMPLETE'))
print('These checks do not verify behavior, complete graph, feature relationship completeness, argument correctness, or device results.')
