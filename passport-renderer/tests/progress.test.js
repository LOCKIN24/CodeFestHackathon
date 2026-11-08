import test from 'node:test';
import assert from 'node:assert/strict';
import { createProgress } from '../src/progress.js';

function memoryStorage() {
  const values = new Map();
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
}

test('初始四枚印章保留漏週，且本週尚未領取', () => {
  const state = createProgress(null).getState();
  assert.equal(state.stamps.length, 4);
  assert.equal(state.week, '2026-11-02');
  assert.equal(state.claimedThisWeek, false);
  assert.equal(state.sampleMode, true);
  assert.equal(state.stamps.some((stamp) => stamp.week === '2026-10-12'), false);
});

test('鮮奶與豆漿每次皆增加一枚印章', () => {
  for (const type of ['milk', 'soy']) {
    const progress = createProgress(null);
    progress.reset();
    const result = progress.claim(type);
    assert.equal(result.added, true);
    assert.equal(result.stamp.type, type);
    assert.equal(result.state.stamps.length, 1);
    assert.equal(result.state.claimedThisWeek, true);
  }
});

test('同週重複點選或切換飲品不會增加印章', () => {
  const progress = createProgress(null);
  const first = progress.claim('milk');
  const duplicate = progress.claim('soy');
  assert.equal(duplicate.added, false);
  assert.deepEqual(duplicate.stamp, first.stamp);
  assert.equal(duplicate.state.stamps.length, 5);
});

test('漏掉多週不會移除、重設或改變先前印章', () => {
  const progress = createProgress(null);
  const before = progress.getState().stamps;
  progress.nextWeek();
  progress.nextWeek();
  progress.nextWeek();
  assert.deepEqual(progress.getState().stamps, before);
  assert.equal(progress.getState().week, '2026-11-23');
  const result = progress.claim('soy');
  assert.deepEqual(result.state.stamps.slice(0, -1), before);
  assert.equal(result.state.stamps.length, 5);
});

test('重新開啟仍保留進度及同週領取限制', () => {
  const storage = memoryStorage();
  const first = createProgress(storage);
  first.claim('milk');
  first.nextWeek();
  first.claim('soy');
  const second = createProgress(storage);
  assert.deepEqual(second.getState(), first.getState());
  assert.equal(second.claim('milk').added, false);
});

test('重播讀取 latest 不更動印章；回傳物件不洩漏內部狀態', () => {
  const progress = createProgress(null);
  const before = progress.getState();
  const latest = progress.latest();
  latest.type = 'milk';
  const snapshot = progress.getState();
  snapshot.stamps[0].type = 'soy';
  snapshot.stamps.push({});
  assert.deepEqual(progress.getState(), before);
});

test('重設及範例切換可得到空白或四枚歷史章', () => {
  const progress = createProgress(null);
  progress.claim('soy');
  progress.nextWeek();
  assert.equal(progress.reset().stamps.length, 0);
  assert.equal(progress.latest(), null);
  assert.equal(progress.getState().week, '2026-11-02');
  assert.equal(progress.setSample(true).stamps.length, 4);
  assert.equal(progress.setSample(false).stamps.length, 0);
  assert.equal(progress.getState().sampleMode, false);
});

test('儲存不可用或資料損毀仍可操作', () => {
  const blocked = createProgress({
    getItem() { throw new Error('不可用'); },
    setItem() { throw new Error('不可用'); },
  });
  assert.equal(blocked.claim('milk').state.stamps.length, 5);
  const corrupt = createProgress({ getItem: () => '{損毀', setItem() {} });
  assert.equal(corrupt.getState().stamps.length, 4);
  assert.equal(corrupt.claim('soy').added, true);
});

test('無效飲品不改變進度', () => {
  const progress = createProgress(null);
  assert.throws(() => progress.claim('coffee'), /鮮奶或豆漿/);
  assert.equal(progress.getState().stamps.length, 4);
});
