import test from 'node:test';
import assert from 'node:assert/strict';
import { classifyGesture, GESTURE_LIMITS } from '../src/gesture.js';

const gesture = (changes = {}) => ({ dx: 0, dy: 0, maxDistance: 0, duration: 120, ...changes });

test('快速輕點可開啟護照', () => {
  assert.equal(classifyGesture(gesture()), 'tap');
});

test('手指小幅晃動仍是輕點', () => {
  assert.equal(classifyGesture(gesture({ dx: 3, dy: -4, maxDistance: 8 })), 'tap');
});

test('左滑下一頁，右滑上一頁', () => {
  assert.equal(classifyGesture(gesture({ dx: -86, dy: 13, maxDistance: 90, duration: 360 })), 'next');
  assert.equal(classifyGesture(gesture({ dx: 86, dy: -13, maxDistance: 90, duration: 360 })), 'previous');
});

test('橫向佔優的斜滑可翻頁，接近對角線則取消', () => {
  assert.equal(classifyGesture(gesture({ dx: -60, dy: 40, maxDistance: 74 })), 'next');
  assert.equal(classifyGesture(gesture({ dx: -60, dy: 50, maxDistance: 80 })), 'cancel');
});

test('垂直滑動不翻頁或開啟護照', () => {
  assert.equal(classifyGesture(gesture({ dx: 4, dy: 95, maxDistance: 96 })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: 46, dy: -90, maxDistance: 105 })), 'cancel');
});

test('拖離後回到起點不能變成輕點', () => {
  assert.equal(classifyGesture(gesture({ dx: 0, dy: 0, maxDistance: 11 })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: 2, dy: 2, maxDistance: 90 })), 'cancel');
});

test('指標取消優先於輕點與滑動', () => {
  assert.equal(classifyGesture(gesture({ cancelled: true })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: -100, maxDistance: 100, cancelled: true })), 'cancel');
});

test('長按與過慢滑動都取消', () => {
  assert.equal(classifyGesture(gesture({ duration: 651 })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: -100, maxDistance: 100, duration: 1401 })), 'cancel');
});

test('輕點距離與時間上限皆包含等號', () => {
  assert.equal(classifyGesture(gesture({ dx: 6, dy: 8, maxDistance: 10, duration: 650 })), 'tap');
  assert.equal(classifyGesture(gesture({ maxDistance: 10.001, duration: 650 })), 'cancel');
  assert.equal(classifyGesture(gesture({ duration: 650.001 })), 'cancel');
});

test('滑動距離與時間上限包含等號，方向比值不包含等號', () => {
  assert.equal(classifyGesture(gesture({ dx: -45, maxDistance: 45, duration: 1400 })), 'next');
  assert.equal(classifyGesture(gesture({ dx: 45, maxDistance: 45, duration: 1400 })), 'previous');
  assert.equal(classifyGesture(gesture({ dx: -44.999, maxDistance: 50 })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: -65, dy: 50, maxDistance: 83 })), 'cancel');
  assert.equal(classifyGesture(gesture({ dx: -65.001, dy: 50, maxDistance: 83 })), 'next');
});

test('不接受無效數值、負時間或矛盾的位移紀錄', () => {
  assert.equal(classifyGesture(), 'cancel');
  for (const changes of [
    { dx: NaN }, { dy: Infinity }, { maxDistance: -1 }, { duration: -1 },
    { duration: '120' }, { dx: 20, maxDistance: 0 },
    { dx: -60, maxDistance: 30 }, { dx: 8, dy: 8, maxDistance: 10 },
  ]) {
    assert.equal(classifyGesture(gesture(changes)), 'cancel');
  }
});

test('判定不改寫輸入，設定值為唯讀', () => {
  const input = Object.freeze(gesture({ dx: -50, maxDistance: 50 }));
  assert.equal(classifyGesture(input), 'next');
  assert.ok(Object.isFrozen(GESTURE_LIMITS));
  assert.equal(GESTURE_LIMITS.tapDistance, 10);
  assert.equal(GESTURE_LIMITS.swipeDistance, 45);
});
