import './style.css';
import { createHostState } from './host-state.js';
import { PassportScene, TIMING, TOTAL_DURATION } from './scene.js';
import { createPaperCanvas } from './textures.js';
import { createPassportBrowser } from './browsing.js';

async function initializePassport() {
  if (document.fonts) {
    await document.fonts.load('400 80px "PingFang TC"', '牛奶護照').catch(() => {});
    await document.fonts.ready;
  }
const $ = id => document.getElementById(id);
const state = createHostState(), stage = $('stage'), lifecycle = new AbortController();
const listen = (target, event, handler) => target.addEventListener(event, handler, {signal: lifecycle.signal});
const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
let busy = false, scene = null, pending = null, animationFrame = 0, phase = '', reduced = false;
let lastTime = 0, elapsed = 0, contextLost = false, browser = null, frames = 0, queuedReplay = null;
function announce(text) { $('live-status').textContent = text; }
function updateUI() {
  const current = state.snapshot(), stamps = current.stamps;
  $('replay').disabled = busy || !stamps.length || !current.ready;
  $('open-passport').disabled = busy || !current.ready;
  $('reduce-motion').disabled = busy;
  document.body.dataset.count = String(stamps.length);
}
function onPhase(next) {
  if (phase === next) return;
  phase = next; document.body.dataset.phase = next;
  if (next === 'admire') announce(`已收藏 ${state.snapshot().stamps.length} 枚印章。`);
}
function onContact(detail) {
  // Contact controls the ink only. Flutter's existing record is authoritative.
  document.body.dataset.ink = 'visible';
  document.dispatchEvent(new CustomEvent('passport:contact', {detail: {...detail, replay: true, count: state.snapshot().stamps.length}}));
}
function fallbackSheet() {
  const stamps = state.snapshot().stamps;
  const index = Math.max(0, stamps.findIndex(stamp => stamp.id === pending.id));
  const page = Math.floor(index / 4);
  const paper = createPaperCanvas({side: 'right', stamps: stamps.slice(page * 4, page * 4 + 4).map((stamp, slot) => ({...stamp, slot})), pageNumber: page + 1});
  const wrapper = document.createElement('div'); wrapper.className = 'fallback-paper'; wrapper.append(paper);
  stage.querySelector('.fallback-idle')?.setAttribute('hidden', ''); stage.querySelector('.fallback-paper')?.remove(); stage.append(wrapper);
  $('passport-canvas').style.display = 'none'; document.body.classList.add('no-webgl');
}
function showFallbackIdle() {
  contextLost = true; document.body.dataset.renderer = 'paper';
  document.body.classList.add('no-webgl'); $('passport-canvas').style.display = 'none';
  if (!stage.querySelector('.fallback-idle')) {
    const label = document.createElement('p'); label.className = 'fallback-idle'; label.textContent = '可使用紙本護照翻閱收藏。'; stage.append(label);
  }
}
function ensureRenderer() {
  if (scene || contextLost || state.snapshot().disposed) return;
  try {
    scene = new PassportScene($('passport-canvas'), stage, {onPhase, onContact, onContextLost() {
      showFallbackIdle();
      if (busy) { reduced = true; elapsed = 0; onContact({id: pending.id, type: pending.type, contactDistance: 0}); fallbackSheet(); onPhase('admire'); }
      else browser?.recover();
    }});
    document.body.dataset.renderer = 'webgl';
  } catch { showFallbackIdle(); }
}
function stopPlayback() {
  cancelAnimationFrame(animationFrame); animationFrame = 0; busy = false; pending = null;
  document.body.classList.remove('animating'); $('main').inert = false; $('main').setAttribute('aria-busy', 'false'); document.body.dataset.phase='idle'; phase='';
  stage.querySelector('.fallback-paper')?.remove(); stage.querySelector('.fallback-idle')?.removeAttribute('hidden');
  if (scene && !contextLost) { scene.idle(); scene.resize(); scene.render(); }
}
function startPlayback(stamp) {
  const current = state.snapshot();
  if (!stamp || busy || current.disposed) return false;
  if (current.suspended || document.hidden) { queuedReplay = stamp; return true; }
  if ($('passport-browser').open) browser?.close(); ensureRenderer(); pending = {...stamp};
  busy = true; reduced = $('reduce-motion').checked || contextLost; elapsed = 0; lastTime = 0; phase = '';
  document.body.dataset.ink = 'hidden'; document.body.classList.add('animating'); updateUI(); $('main').inert=true; $('main').setAttribute('aria-busy','true');
  if (scene && !contextLost) { scene.prepare(current.stamps, pending); scene.frame(0, reduced); }
  else { onContact({id: pending.id, type: pending.type, contactDistance: 0}); fallbackSheet(); onPhase('admire'); }
  announce('正在翻開這一週的收藏。'); animationFrame = requestAnimationFrame(tick); return true;
}
function tick(now) {
  animationFrame = 0;
  if (!busy || state.snapshot().suspended || state.snapshot().disposed || document.hidden) return;
  if (lastTime) elapsed += Math.min(now - lastTime, 80);
  lastTime = now; frames++;
  if (scene && !contextLost) scene.frame(elapsed, reduced);
  if (elapsed >= (reduced ? 2200 : TOTAL_DURATION)) {
    stopPlayback(); updateUI(); announce(`已收好 ${state.snapshot().stamps.length} 枚印章。`);
    $('open-passport').focus({preventScroll: true}); return;
  }
  animationFrame = requestAnimationFrame(tick);
}
function suspend() {
  if (state.snapshot().disposed) return;
  state.suspend(); lastTime = 0; cancelAnimationFrame(animationFrame); animationFrame = 0; browser?.suspend();
}
function resume() {
  if (state.snapshot().disposed || document.hidden) return;
  state.resume(); lastTime = 0;
  if (queuedReplay) { const stamp = queuedReplay; queuedReplay = null; startPlayback(stamp); }
  else if (busy && !animationFrame) animationFrame = requestAnimationFrame(tick);
  else if (scene && !contextLost) { scene.resize(); scene.render(); }
}
function dispose() {
  if (state.snapshot().disposed) return;
  cancelAnimationFrame(animationFrame); animationFrame = 0; queuedReplay = null; busy = false;
  browser?.dispose(); lifecycle.abort(); scene?.dispose(); scene = null; state.dispose();
}
function setRecords(payload) {
  const result = state.accept(payload);
  if (!result.accepted) return false;
  if (result.changed) { if ($('passport-browser').open) browser?.close(); if (busy) stopPlayback(); }
  $('reduce-motion').checked = payload.reduceMotion || motionPreference.matches;
  ensureRenderer(); updateUI();
  if (result.replay) startPlayback(result.replay);
  return true;
}
$('reduce-motion').checked = motionPreference.matches;
listen($('replay'), 'click', () => startPlayback(state.snapshot().stamps.at(-1)));
listen(motionPreference, 'change', event => { if (!busy) $('reduce-motion').checked = event.matches || state.snapshot().reduceMotion; });
listen(document, 'visibilitychange', () => document.hidden ? suspend() : resume());
listen(window, 'pagehide', dispose);
browser = createPassportBrowser({stage, getScene: () => contextLost ? null : scene, getState: () => state.snapshot(), prefersReduced: () => $('reduce-motion').checked, isCollecting: () => busy, announce});
window.milkPassportHost = Object.freeze({setRecords, suspend, resume, dispose,
  getState: () => ({...state.snapshot(), busy, fallback: contextLost, renderMode: scene && !contextLost ? 'webgl' : contextLost ? 'paper' : 'uninitialized', frames, phase}),
});
function notifyReady() {
  try { window.flutter_inappwebview?.callHandler('passportReady', {version: 1})?.catch(() => {}); } catch { /* onLoadStop is an independent native bootstrap. */ }
}
listen(window, 'flutterInAppWebViewPlatformReady', notifyReady);
updateUI(); document.body.dataset.phase = 'idle'; notifyReady();

}
initializePassport();
