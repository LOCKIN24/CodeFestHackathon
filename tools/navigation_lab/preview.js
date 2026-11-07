const form = document.querySelector('#request-form');
const query = document.querySelector('#query');
const result = document.querySelector('#result');
const button = document.querySelector('#submit');
function el(tag, text, cls) { const e = document.createElement(tag); if (text !== undefined && text !== null) e.textContent = text; if (cls) e.className = cls; return e; }
function list(parent, title, items) { if (!items || !items.length) return; parent.append(el('h3', title)); const ul = el('ul'); for (const item of items) ul.append(el('li', typeof item === 'string' ? item : JSON.stringify(item))); parent.append(ul); }
function render(data) {
  result.replaceChildren(); result.hidden = false;
  const p = data.preview, choice = data.choice || {};
  const labels = {preview:'Preview',incomplete:'Incomplete navigation',clarify:'Clarification needed',rejected:'Request rejected'};
  const head = el('div', undefined, 'result-head'); head.append(el('span', labels[p.status] || 'Unavailable', `status ${p.status}`));
  if (p.feature_name) { head.append(el('h2', p.feature_name)); head.append(el('code', p.feature_id)); } else head.append(el('h2', labels[p.status] || 'Unable to preview'));
  result.append(head);
  const decision=el('div',undefined,'decision');
  decision.append(el('p',`Detected intent: ${choice.intent || 'unknown'}`));
  decision.append(el('p',`Catalog support: ${choice.support === 'catalog_feature' ? 'Matched catalog feature' : choice.support || 'unknown'}`));
  decision.append(el('p','Action allowed: No. This interface can only preview source evidence.'));
  result.append(decision);
  if (p.reason) result.append(el('p', p.reason));
  if (p.screen_id) { const card=el('div',undefined,'card'); card.append(el('h3','Destination')); card.append(el('p',`Screen: ${p.screen_id}`)); if (p.feature_route) card.append(el('p',`Audited route: ${p.feature_route}`)); if (p.entry_evidence) card.append(el('p',`Recorded entry evidence: ${p.entry_evidence}`)); result.append(card); }
  if (p.steps && p.steps.length) { const card=el('div',undefined,'card'); card.append(el('h3','Recorded navigation steps')); const ol=el('ol',undefined,'steps'); for (const s of p.steps) { const li=el('li'); li.append(el('strong',`${s.from} → ${s.to}`)); li.append(el('p',`Control: ${s.control_id}${s.control_label ? ' · '+s.control_label : ''}`)); li.append(el('p',`Edge: ${s.edge_id} · ${s.source}`)); list(li,'Required parameters',s.required_parameters); list(li,'Prerequisites',s.prerequisites); ol.append(li); } card.append(ol); result.append(card); }
  if (p.recorded_boundary_edges && p.recorded_boundary_edges.length) { const card=el('div',undefined,'card'); card.append(el('h3','Recorded boundary evidence')); card.append(el('p','These records are evidence only; they do not establish a complete path to the requested feature.')); for (const b of p.recorded_boundary_edges) { const row=el('div',undefined,'boundary'); row.append(el('strong',b.edge_id)); row.append(el('p',`${b.source_screen_id} → ${b.destination_screen_id || 'conditional or dynamic destination'}`)); row.append(el('p',`Control: ${b.control_id} · ${b.source}`)); if (b.prefix_steps && b.prefix_steps.length) { row.append(el('h3','Recorded prefix to boundary')); const prefix=el('ol'); for (const s of b.prefix_steps) { const item=el('li'); item.append(el('strong',`${s.from} → ${s.to}`)); item.append(el('p',`Control: ${s.control_id}${s.control_label ? ' · '+s.control_label : ''} · ${s.edge_id} · ${s.source}`)); list(item,'Required parameters',s.required_parameters); list(item,'Prerequisites',s.prerequisites); prefix.append(item); } row.append(prefix); } list(row,'Required parameters',b.required_parameters); list(row,'Prerequisites',b.prerequisites); card.append(row); } result.append(card); }
  const details=el('div',undefined,'card'); list(details,'Missing information or path gaps',p.missing); list(details,'Required feature parameters',p.feature_required_parameters); list(details,'Unverified prerequisites',p.unverified_prerequisites || p.feature_prerequisites); list(details,'Relevant controls',p.related_controls); list(details,'Known limitations',p.limitations); list(details,'Dependencies',p.dependencies); list(details,'Screen states',p.screen_states); if (details.childElementCount) result.append(details);
  if (p.simulation) result.append(el('p',p.simulation,'muted')); if (choice.source) result.append(el('p',`Match source: ${choice.source}`,'muted'));
}
form.addEventListener('submit',async event=>{ event.preventDefault(); button.disabled=true; button.textContent='Checking…'; result.hidden=false; result.replaceChildren(el('p','Checking the local catalog and model…')); try {const response=await fetch('/api/preview',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({query:query.value})}); const data=await response.json(); if(!response.ok) throw new Error(data.error || 'Request failed'); render(data);} catch(error){result.replaceChildren(el('p',`Unable to preview: ${error.message}`));} finally {button.disabled=false;button.textContent='Preview navigation →';} });
