// The renderer is a read-only projection. It never owns allowance or progress.
const TYPES = new Set(['milk', 'soy']);
function validDay(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const day = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(day.getTime()) && day.toISOString().slice(0, 10) === value;
}
function validate(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)
      || Object.keys(payload).some(key => !['version', 'stamps', 'replayLatest', 'reduceMotion'].includes(key))
      || payload.version !== 1 || !Array.isArray(payload.stamps) || payload.stamps.length > 10000
      || typeof payload.replayLatest !== 'boolean' || typeof payload.reduceMotion !== 'boolean') return null;
  const ids = new Set(), weeks = new Set();
  const stamps = [];
  for (const stamp of payload.stamps) {
    if (!stamp || typeof stamp !== 'object' || Array.isArray(stamp)
        || Object.keys(stamp).sort().join(',') !== 'date,id,type,week'
        || typeof stamp.id !== 'string' || !/^[A-Za-z0-9_-]{1,100}$/.test(stamp.id)
        || !TYPES.has(stamp.type) || !validDay(stamp.week)
        || new Date(`${stamp.week}T00:00:00Z`).getUTCDay() !== 1
        || typeof stamp.date !== 'string' || stamp.date.length > 40 || !validDay(stamp.date.slice(0, 10))
        || ids.has(stamp.id) || weeks.has(stamp.week)) return null;
    const weekStart = Date.parse(`${stamp.week}T00:00:00Z`);
    const dateDay = Date.parse(`${stamp.date.slice(0, 10)}T00:00:00Z`);
    if (dateDay < weekStart || dateDay >= weekStart + 7 * 86400000) return null;
    ids.add(stamp.id); weeks.add(stamp.week);
    stamps.push({ id: stamp.id, type: stamp.type, week: stamp.week, date: stamp.date });
  }
  stamps.sort((a, b) => a.week.localeCompare(b.week));
  return stamps;
}
export function createHostState() {
  let stamps = [], ready = false, suspended = false, disposed = false;
  let reduceMotion = false, replayCount = 0;
  const replayed = new Set();
  return {
    accept(payload) {
      if (disposed) return { accepted: false, replay: null, changed: false };
      const next = validate(payload);
      if (!next) return { accepted: false, replay: null, changed: false };
      const changed = JSON.stringify(stamps) !== JSON.stringify(next);
      stamps = next; ready = true; reduceMotion = payload.reduceMotion;
      const latest = stamps.at(-1);
      const key = latest && JSON.stringify(latest);
      const replay = payload.replayLatest && latest && !replayed.has(key) ? { ...latest } : null;
      if (replay) { replayed.add(key); replayCount++; }
      return { accepted: true, replay, changed };
    },
    snapshot() { return { stamps: stamps.map(stamp => ({ ...stamp })), ready, suspended, disposed, reduceMotion, replayCount }; },
    suspend() { if (!disposed) suspended = true; },
    resume() { if (!disposed) suspended = false; },
    dispose() { disposed = true; suspended = true; stamps = []; replayed.clear(); },
  };
}
