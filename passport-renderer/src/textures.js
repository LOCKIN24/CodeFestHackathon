/**
 * 所有材質皆於本機以 Canvas 繪製，沒有外部圖片、字型或模型請求。
 * 封面保留護照名稱與奶瓶徽章；集章頁採每頁 2 × 2 的格狀配置。
 * v 由紙張上方往下計算；3D 頁面的貼圖沿用這個座標。
 */
export const SLOT_CENTERS = Object.freeze([
  { u: 224 / 768, v: 380 / 1080 }, { u: 544 / 768, v: 380 / 1080 },
  { u: 224 / 768, v: 700 / 1080 }, { u: 544 / 768, v: 700 / 1080 },
]);

const COVER_FONT = '"PingFang TC", "Noto Sans TC", "Microsoft JhengHei", sans-serif';
const INK = { milk: '#8e2d25', soy: '#875b0d' };
const stampCache = new Map();

function random(seed = 1) {
  let a = (Number(seed) || 1) >>> 0;
  return () => {
    a += 0x6d2b79f5;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hash(value) {
  let h = 2166136261;
  for (const ch of String(value)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return h >>> 0;
}

function canvas(w, h = w) {
  const element = document.createElement('canvas');
  element.width = w;
  element.height = h;
  return element;
}

function roundRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}

function line(ctx, points) {
  ctx.beginPath();
  points.forEach(([x, y], index) => index ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
  ctx.stroke();
}

function ellipse(ctx, x, y, rx, ry, rotation = 0, fill = false) {
  ctx.beginPath();
  ctx.ellipse(x, y, rx, ry, rotation, 0, Math.PI * 2);
  fill ? ctx.fill() : ctx.stroke();
}

function leaf(ctx, x, y, length, width, rotation, filled = true) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.bezierCurveTo(-width, -length * 0.26, -width * 0.7, -length * 0.79, 0, -length);
  ctx.bezierCurveTo(width * 0.7, -length * 0.79, width, -length * 0.26, 0, 0);
  if (filled) ctx.fill(); else ctx.stroke();
  ctx.save();
  if (filled) ctx.globalCompositeOperation = 'destination-out';
  const savedWidth = ctx.lineWidth;
  ctx.lineWidth = filled ? 2.8 : Math.max(1, savedWidth * 0.5);
  line(ctx, [[0, -5], [0, -length + 12]]);
  for (let i = 1; i < 5; i++) {
    const yy = -length * (0.15 + i * 0.13);
    line(ctx, [[0, yy - 13], [-width * 0.56, yy - 25]]);
    line(ctx, [[0, yy - 13], [width * 0.56, yy - 25]]);
  }
  ctx.restore();
  ctx.restore();
}

function bottle(ctx, x = 256, y = 232, scale = 1, solid = false) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.lineJoin = 'round';
  ctx.lineCap = 'round';
  ctx.lineWidth = solid ? 12 : 9;
  // 瓶身與瓶肩不完全對稱，保留手刻橡皮章的感覺。
  ctx.beginPath();
  ctx.moveTo(-30, -99);
  ctx.lineTo(-30, -67);
  ctx.bezierCurveTo(-31, -53, -51, -43, -54, -22);
  ctx.lineTo(-61, 88);
  ctx.quadraticCurveTo(-60, 104, -43, 107);
  ctx.lineTo(46, 107);
  ctx.quadraticCurveTo(61, 105, 61, 89);
  ctx.lineTo(55, -22);
  ctx.bezierCurveTo(52, -43, 31, -54, 30, -68);
  ctx.lineTo(30, -99);
  ctx.closePath();
  ctx.stroke();
  if (solid) {
    ctx.beginPath();ctx.moveTo(-48,10);
    ctx.bezierCurveTo(-20,0,10,23,50,10);
    ctx.lineTo(55,89);ctx.quadraticCurveTo(54,99,44,100);
    ctx.lineTo(-43,100);ctx.quadraticCurveTo(-54,99,-55,89);ctx.closePath();ctx.fill();
  }
  ctx.lineWidth = 6;
  roundRect(ctx, -35, -117, 70, 20, 4);
  ctx.stroke();
  line(ctx, [[-24, -107], [25, -107]]);
  ctx.lineWidth = 4;
  for (let i = -21; i <= 21; i += 9) line(ctx, [[i, -114], [i, -101]]);
  ctx.beginPath();
  ctx.moveTo(-50, 8);
  ctx.bezierCurveTo(-20, -1, 11, 22, 52, 8);
  ctx.stroke();
  ctx.lineWidth = 3;
  line(ctx, [[-45, 36], [-48, 79]]);
  // 奶滴是挖空的輪廓，而非貼上的符號。
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(3, 29);
  ctx.bezierCurveTo(-7, 46, -19, 56, -17, 65);
  ctx.bezierCurveTo(-15, 87, 21, 87, 23, 66);
  ctx.bezierCurveTo(25, 56, 11, 42, 3, 29);
  ctx.closePath();
  if(solid){ctx.globalCompositeOperation='destination-out';ctx.fill();}else ctx.stroke();
  ctx.restore();
}

function roughCircle(ctx, cx, cy, radius, rng, width) {
  ctx.beginPath();
  for (let i = 0; i <= 180; i++) {
    const angle = i / 180 * Math.PI * 2;
    const r = radius + (rng() - 0.5) * 2.8;
    const xx = cx + Math.cos(angle) * r;
    const yy = cy + Math.sin(angle) * r;
    i ? ctx.lineTo(xx, yy) : ctx.moveTo(xx, yy);
  }
  ctx.closePath();
  ctx.lineWidth = width;
  ctx.stroke();
}

/** 512px 透明底的純圖像墨印；保留瓶身、豆葉及外圈，無文字或裝飾射線。
 * 同一 seed 的磨損位置永久一致。 */
export function createStampCanvas(type, seed = 1) {
  const normalizedType = type === 'soy' ? 'soy' : 'milk';
  const cacheKey = `${normalizedType}:${seed}`;
  if (stampCache.has(cacheKey)) return stampCache.get(cacheKey);
  const result = canvas(512);
  const ctx = result.getContext('2d');
  const rng = random(hash(cacheKey));
  ctx.strokeStyle = ctx.fillStyle = INK[normalizedType];
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  if (normalizedType === 'milk') {
    roughCircle(ctx, 256, 256, 219, rng, 16);
    roughCircle(ctx, 256, 256, 202, rng, 4);
    bottle(ctx, 256, 246, 0.93, true);
  } else {
    for (const [radius, width] of [[226, 16], [208, 4]]) {
      ctx.lineWidth = width;
      ctx.beginPath();
      for (let i = 0; i <= 6; i++) {
        const a = -Math.PI / 2 + i * Math.PI / 3;
        const x = 256 + radius * Math.cos(a);
        const y = 256 + radius * Math.sin(a);
        i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      ctx.closePath();
      ctx.stroke();
    }
    ctx.lineWidth = 8;
    ctx.beginPath();
    ctx.moveTo(231, 326);
    ctx.bezierCurveTo(247, 267, 265, 223, 270, 161);
    ctx.stroke();
    leaf(ctx, 262, 219, 77, 32, -0.7);
    leaf(ctx, 255, 251, 93, 33, 0.91);
    leaf(ctx, 242, 284, 79, 29, -1.08);
    ctx.lineWidth = 7;
    ellipse(ctx, 201, 325, 25, 23, -0.28);
    ellipse(ctx, 251, 339, 28, 25, 0.2);
    ellipse(ctx, 302, 319, 25, 24, 0.5);
    ctx.lineWidth = 2.8;
    ctx.beginPath();
    ctx.arc(203, 327, 14, 2.7, 4.5);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(254, 341, 16, 2.7, 4.5);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(304, 322, 14, 2.7, 4.4);
    ctx.stroke();
  }

  // 印泥不是單一透明度：細微孔洞、薄墨區和纖維斷痕都在印章本身。
  const pixels = ctx.getImageData(0, 0, 512, 512);
  for (let y = 0; y < 512; y++) {
    for (let x = 0; x < 512; x++) {
      const index = (y * 512 + x) * 4 + 3;
      if (!pixels.data[index]) continue;
      const pore = rng();
      const pressure = 0.94 + 0.09 * Math.sin(x * 0.029 + y * 0.021) + 0.07 * Math.sin(y * 0.09);
      pixels.data[index] *= pore < 0.06 ? 0 : Math.min(1, pressure * (0.87 + rng() * 0.22));
    }
  }
  ctx.putImageData(pixels, 0, 0);
  ctx.save();
  ctx.globalCompositeOperation = 'destination-out';
  for (let i = 0; i < 280; i++) {
    ctx.globalAlpha = 0.35 + rng() * 0.55;
    const x = rng() * 512;
    const y = rng() * 512;
    ellipse(ctx, x, y, 0.65 + rng() * 2.0, 0.7 + rng() * 3.4, rng() * Math.PI, true);
  }
  for (let i = 0; i < 38; i++) {
    ctx.globalAlpha = 0.2 + rng() * 0.45;
    ctx.lineWidth = 0.6 + rng() * 1.1;
    const x = rng() * 512;
    const y = rng() * 512;
    line(ctx, [[x, y], [x + 7 + rng() * 14, y + rng() * 4]]);
  }
  ctx.restore();
  // 限定快取，長時間示範仍不會無限累積 Canvas。
  if (stampCache.size > 64) stampCache.delete(stampCache.keys().next().value);
  stampCache.set(cacheKey, result);
  return result;
}

/** 可重複鋪排的皮革紋。 */
export function createLeatherCanvas() {
  const result = canvas(256);
  const ctx = result.getContext('2d');
  const rng = random(318);
  const image = ctx.createImageData(256, 256);
  for (let y = 0; y < 256; y++) {
    for (let x = 0; x < 256; x++) {
      const i = (y * 256 + x) * 4;
      const n = (rng() - 0.5) * 8 + Math.sin(x * Math.PI / 8) * Math.sin(y * Math.PI / 8) * 0.7;
      image.data[i] = 25 + n;
      image.data[i + 1] = 40 + n;
      image.data[i + 2] = 58 + n;
      image.data[i + 3] = 255;
    }
  }
  ctx.putImageData(image, 0, 0);
  ctx.lineWidth = 0.6;
  for (let i = 0; i < 320; i++) {
    const x = rng() * 256;
    const y = rng() * 256;
    ctx.strokeStyle = `rgba(4,14,24,${0.05 + rng() * 0.07})`;
    ctx.beginPath();
    ctx.arc(x, y, 1 + rng() * 2, rng() * Math.PI, Math.PI * 2);
    ctx.stroke();
  }
  return result;
}

export function createWoodCanvas() {
  const result = canvas(256);
  const ctx = result.getContext('2d');
  const rng = random(72);
  ctx.fillStyle = '#875030';
  ctx.fillRect(0, 0, 256, 256);
  // 沿手柄長軸的細木紋；橫向自然色帶，無任何圖片依賴。
  for (let x = 0; x < 256; x++) {
    const phase = x / 256 * Math.PI * 2;
    ctx.strokeStyle = `rgba(${x % 4 ? '48,23,10' : '219,156,90'},${0.035 + rng() * 0.07})`;
    ctx.lineWidth = 0.8 + rng() * 1.6;
    ctx.beginPath();
    for (let y = 0; y <= 256; y += 4) {
      const xx = x + Math.sin(y / 256 * Math.PI * 2 + phase) * 3 + Math.sin(y * 0.055 + phase) * 0.7;
      y ? ctx.lineTo(xx, y) : ctx.moveTo(xx, y);
    }
    ctx.stroke();
  }
  const shine = ctx.createLinearGradient(0, 0, 256, 0);
  shine.addColorStop(0, 'rgba(36,12,4,.08)');
  shine.addColorStop(0.4, 'rgba(245,192,122,.04)');
  shine.addColorStop(1, 'rgba(36,12,4,.08)');
  ctx.fillStyle = shine;
  ctx.fillRect(0, 0, 256, 256);
  return result;
}

/** 深藍材質、金色書名與原版奶瓶徽章，沒有副標或標語。 */
export function createCoverCanvas() {
  const result = canvas(768, 1080);
  const ctx = result.getContext('2d');
  ctx.fillStyle = ctx.createPattern(createLeatherCanvas(), 'repeat');
  ctx.fillRect(0, 0, 768, 1080);
  const shade = ctx.createLinearGradient(0, 0, 768, 0);
  shade.addColorStop(0, 'rgba(0,0,0,.27)');
  shade.addColorStop(0.08, 'rgba(0,0,0,.04)');
  shade.addColorStop(0.56, 'rgba(255,255,255,.025)');
  shade.addColorStop(1, 'rgba(0,0,0,.10)');
  ctx.fillStyle = shade;
  ctx.fillRect(0, 0, 768, 1080);
  ctx.fillStyle = '#d4b77d';
  ctx.textAlign = 'center';
  ctx.font = `400 80px ${COVER_FONT}`;
  ctx.letterSpacing = '5px';
  ctx.textBaseline = 'middle';
  ctx.shadowColor = 'rgba(0,0,0,.55)';
  ctx.shadowBlur = 1;
  ctx.shadowOffsetY = 2;
  ctx.fillText('牛奶護照', 384, 244);
  ctx.shadowColor = 'transparent';
  // 恢復原版的完整奶瓶與雙枝植紋徽章。
  ctx.save();
  ctx.translate(384, 646);
  ctx.strokeStyle = ctx.fillStyle = '#bca273';
  ctx.lineWidth = 1.7;
  ellipse(ctx, 0, 0, 137, 165);
  ellipse(ctx, 0, 0, 146, 174);
  bottle(ctx, 0, -2, 0.73);
  ctx.lineWidth = 2;
  for (const side of [-1, 1]) {
    ctx.save();
    ctx.scale(side, 1);
    ctx.beginPath();
    ctx.moveTo(16, 173);
    ctx.bezierCurveTo(160, 145, 194, 13, 150, -119);
    ctx.stroke();
    for (let i = 0; i < 7; i++) {
      const a = -0.7 + i * 0.30;
      const xx = 158 * Math.cos(a);
      const yy = 149 * Math.sin(a);
      leaf(ctx, xx, yy, 30, 8, a + 0.6, false);
      leaf(ctx, xx - 4, yy + 8, 25, 7, a - 0.7, false);
    }
    ctx.restore();
  }
  ctx.restore();
  return result;
}

function paintPaper(ctx, width, height, side, seed) {
  const rng = random(seed);
  const pixels = ctx.createImageData(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const grain = (rng() - 0.5) * 8;
      const cloud = Math.sin(x * 0.019 + y * 0.007) * Math.sin(y * 0.013) * 1.4;
      pixels.data[i] = 247 + grain + cloud;
      pixels.data[i + 1] = 239 + grain + cloud;
      pixels.data[i + 2] = 221 + grain + cloud;
      pixels.data[i + 3] = 255;
    }
  }
  ctx.putImageData(pixels, 0, 0);
  // 靠書脊的微暗帶與外緣的薄暖色，強化紙張實體感。
  const gutter = ctx.createLinearGradient(0, 0, width, 0);
  if (side === 'left') {
    gutter.addColorStop(0, 'rgba(123,88,36,.04)');
    gutter.addColorStop(0.78, 'rgba(123,88,36,0)');
    gutter.addColorStop(0.94, 'rgba(123,88,36,.035)');
    gutter.addColorStop(1, 'rgba(91,65,30,.15)');
  } else {
    gutter.addColorStop(0, 'rgba(91,65,30,.15)');
    gutter.addColorStop(0.06, 'rgba(123,88,36,.035)');
    gutter.addColorStop(0.22, 'rgba(123,88,36,0)');
    gutter.addColorStop(1, 'rgba(123,88,36,.04)');
  }
  ctx.fillStyle = gutter;
  ctx.fillRect(0, 0, width, height);
  ctx.lineWidth = 0.6;
  ctx.strokeStyle = 'rgba(118,90,47,.055)';
  for (let i = 0; i < 2700; i++) {
    const x = rng() * width;
    const y = rng() * height;
    line(ctx, [[x, y], [x + rng() * 6 + 1, y + rng() * 3 - 1.5]]);
  }
}

/**
 * stamps: [{ type, date, slot, id }]
 * collection 在淡金 2 × 2 格線內置中繪製墨印；日期不顯示。
 * blank、intro、notes 等其他頁型皆為空白紙，不繪製格線、文字或頁碼。
 * pageNumber 只決定紙紋種子，傳入 highlightSlot 不會新增裝飾。
 */
export function createPaperCanvas({ side = 'right', stamps = [], pageNumber = 1, variant = 'collection' } = {}) {
  const result = canvas(768, 1080);
  const ctx = result.getContext('2d');
  paintPaper(ctx, 768, 1080, side, 514 + pageNumber);
  if (variant !== 'collection') return result;

  ctx.strokeStyle = 'rgba(151, 125, 78, .40)';
  ctx.lineWidth = 2;
  roundRect(ctx, 64, 220, 640, 640, 15);
  ctx.stroke();
  line(ctx, [[384, 220], [384, 860]]);
  line(ctx, [[64, 540], [704, 540]]);

  SLOT_CENTERS.forEach(({ u, v }, slot) => {
    const stamp = stamps.find((item) => item.slot === slot);
    if (!stamp) return;
    const stampSeed = hash(stamp.id ?? `${stamp.type}-${stamp.date}-${slot}`);
    ctx.save();
    ctx.translate(u * 768, v * 1080);
    ctx.drawImage(createStampCanvas(stamp.type, stampSeed), -153, -153, 306, 306);
    ctx.restore();
  });
  return result;
}
