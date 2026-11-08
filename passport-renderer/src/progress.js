const STORAGE_KEY = 'milk-passport-demo.progress.v1';
const INITIAL_WEEK = '2026-11-02';
const DAY_MS = 24 * 60 * 60 * 1000;
const TYPES = new Set(['milk', 'soy']);

function sampleStamps() {
  return [
    ['2026-09-28', 'milk'],
    ['2026-10-05', 'soy'],
    ['2026-10-19', 'milk'],
    ['2026-10-26', 'soy'],
  ].map(([week, type]) => ({
    id: `pickup-${week}`,
    type,
    week,
    date: `${week}T09:00:00.000Z`,
  }));
}

function freshState(sampleMode = true) {
  return {
    stamps: sampleMode ? sampleStamps() : [],
    week: INITIAL_WEEK,
    sampleMode,
  };
}

function validWeek(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime())
    && date.toISOString().slice(0, 10) === value
    && date.getUTCDay() === 1;
}

function readState(storage) {
  try {
    const raw = storage?.getItem(STORAGE_KEY);
    if (!raw) return freshState();
    const saved = JSON.parse(raw);
    if (saved.version !== 1 || !validWeek(saved.week)
      || !Array.isArray(saved.stamps) || typeof saved.sampleMode !== 'boolean') {
      return freshState();
    }
    const weeks = new Set();
    for (const stamp of saved.stamps) {
      if (!stamp || typeof stamp.id !== 'string' || !stamp.id
        || !TYPES.has(stamp.type) || !validWeek(stamp.week)
        || stamp.week > saved.week || weeks.has(stamp.week)
        || typeof stamp.date !== 'string'
        || !Number.isFinite(Date.parse(stamp.date))) {
        return freshState();
      }
      weeks.add(stamp.week);
    }
    return {
      stamps: saved.stamps.map(({ id, type, week, date }) => ({ id, type, week, date })),
      week: saved.week,
      sampleMode: saved.sampleMode,
    };
  } catch {
    // 儲存資料損毀或瀏覽器禁止存取時，仍可在本次頁面內操作示範。
    return freshState();
  }
}

function browserStorage() {
  try {
    return globalThis.localStorage;
  } catch {
    return undefined;
  }
}

/**
 * 每次成功記錄一週的領取就永久保留一枚印章。
 * 傳入 null 可建立不寫入瀏覽器儲存空間的獨立示範。
 */
export function createProgress(storage = browserStorage()) {
  let data = readState(storage);

  function getState() {
    return {
      stamps: data.stamps.map((stamp) => ({ ...stamp })),
      week: data.week,
      claimedThisWeek: data.stamps.some((stamp) => stamp.week === data.week),
      sampleMode: data.sampleMode,
    };
  }

  function save() {
    try {
      storage?.setItem(STORAGE_KEY, JSON.stringify({ version: 1, ...data }));
    } catch {
      // 無痕模式、空間不足等情況不應中斷領取或播放動畫。
    }
    return getState();
  }

  function claim(type) {
    if (!TYPES.has(type)) throw new TypeError('請選擇鮮奶或豆漿。');
    const existing = data.stamps.find((stamp) => stamp.week === data.week);
    if (existing) return { added: false, stamp: { ...existing }, state: getState() };
    const stamp = {
      id: `pickup-${data.week}`,
      type,
      week: data.week,
      date: `${data.week}T09:00:00.000Z`,
    };
    data.stamps.push(stamp);
    return { added: true, stamp: { ...stamp }, state: save() };
  }

  function reset() {
    data = freshState(false);
    return save();
  }

  function setSample(enabled) {
    data = freshState(Boolean(enabled));
    return save();
  }

  function nextWeek() {
    data.week = new Date(Date.parse(`${data.week}T00:00:00.000Z`) + 7 * DAY_MS)
      .toISOString().slice(0, 10);
    return save();
  }

  function latest() {
    const stamp = data.stamps.at(-1);
    return stamp ? { ...stamp } : null;
  }

  return { getState, claim, reset, setSample, nextWeek, latest };
}
