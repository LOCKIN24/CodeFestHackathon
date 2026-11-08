import test from 'node:test';
import assert from 'node:assert/strict';
import { createHostState } from '../src/host-state.js';
const stamp = {id:'record-2026-11-02',type:'soy',week:'2026-11-02',date:'2026-11-08'};
const payload = (stamps=[stamp], extra={}) => ({version:1,stamps,replayLatest:false,reduceMotion:false,...extra});
test('host starts empty with no demo stamps, and can represent an empty passport',()=>{
  const host=createHostState();assert.deepEqual(host.snapshot().stamps,[]);assert.equal(host.snapshot().ready,false);
  assert.equal(host.accept(payload([])).accepted,true);assert.equal(host.snapshot().ready,true);assert.deepEqual(host.snapshot().stamps,[]);
});
test('milk and soy are equal read-only records, skipped weeks remain intact',()=>{
  const host=createHostState(),milk={id:'record-2026-10-19',type:'milk',week:'2026-10-19',date:'2026-10-22'};
  host.accept(payload([stamp,milk]));assert.deepEqual(host.snapshot().stamps,[milk,stamp]);
  const exposed=host.snapshot();exposed.stamps[0].type='soy';exposed.stamps.push(stamp);assert.deepEqual(host.snapshot().stamps,[milk,stamp]);
});
test('native ready and onLoadStop bootstrap cannot replay the same record twice',()=>{
  const host=createHostState();const input=payload([stamp],{replayLatest:true});
  assert.deepEqual(host.accept(input).replay,stamp);assert.equal(host.accept(input).replay,null);assert.equal(host.snapshot().replayCount,1);
  input.stamps[0].type='milk';assert.equal(host.snapshot().stamps[0].type,'soy');
});
test('unknown personal fields, duplicate weeks, bad dates/types and malformed payloads are rejected without mutation',()=>{
  for(const input of [null,[],payload([stamp],{childName:'private'}),payload([{...stamp,cardNumber:'private'}]),payload([stamp,{...stamp,id:'duplicate'}]),payload([{...stamp,date:'2026-10-30'}]),payload([{...stamp,week:'2026-11-03'}]),payload([{...stamp,type:'juice'}]),payload([{...stamp,date:'2026-11-31'}]),payload([{...stamp,id:'<script>'}]),payload([stamp],{version:2}),payload([stamp],{replayLatest:'yes'})]){
    const host=createHostState();assert.equal(host.accept(input).accepted,false);assert.deepEqual(host.snapshot().stamps,[]);assert.equal(host.snapshot().ready,false);
  }
});
test('suspend/resume retain records and dispose clears memory and rejects later injections',()=>{
  const host=createHostState();host.accept(payload());host.suspend();assert.equal(host.snapshot().suspended,true);assert.deepEqual(host.snapshot().stamps,[stamp]);
  host.resume();assert.equal(host.snapshot().suspended,false);host.dispose();assert.equal(host.snapshot().disposed,true);assert.deepEqual(host.snapshot().stamps,[]);assert.equal(host.accept(payload()).accepted,false);
});
test('date formatting and input are stored exactly, with no fabricated time or count changes',()=>{
  const host=createHostState(),input=payload([{...stamp,date:'2026-11-08T09:00:00+08:00'}]);const before=JSON.stringify(input);host.accept(input);assert.equal(JSON.stringify(input),before);assert.equal(host.snapshot().stamps.length,1);
});
