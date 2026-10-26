'use strict';
(() => {
const T = 32, W = 80, H = 80, $ = id => document.getElementById(id);
const cv = $('c'), ctx = cv.getContext('2d'), mm = $('mm'), mctx = mm.getContext('2d'), MM = 150;
let vw = 1, vh = 1, dpr = 1;

/* ---------- بيانات اللعبة ---------- */
const ARMIES = {
  iraq: { n: 'العراق', c: '#d8362a', d: '+10٪ صحة لكل الوحدات', hp: 1.1 },
  ksa:  { n: 'السعودية', c: '#1e9a56', d: '+20٪ دخل الذهب', inc: 1.2 },
  qat:  { n: 'قطر', c: '#9b1b45', d: '+400 ذهب في البداية', gold: 400 },
  egy:  { n: 'مصر', c: '#e0b030', d: '+10٪ ضرر', dmg: 1.1 }
};
const DIFF = {
  easy:   { n: 'سهل',   every: 17, wave: 5, gm: .7, bt: 40 },
  normal: { n: 'متوسط', every: 10, wave: 7, gm: 1,  bt: 28 },
  hard:   { n: 'صعب',   every: 6,  wave: 9, gm: 1.4, bt: 18 }
};
const UD = {
  inf:  { n: 'مشاة', ic: '🪖', hp: 70,  sp: 2.4, rng: 4.5, dmg: 9,  cd: .7,  cost: 100, t: 4, vis: 7, r: 6 },
  tank: { n: 'دبابة', ic: '🛡️', hp: 260, sp: 1.9, rng: 6.5, dmg: 30, cd: 1.5, cost: 350, t: 8, vis: 8, r: 11, noAir: true },
  art:  { n: 'مدفعية', ic: '💥', hp: 110, sp: 1.5, rng: 11, dmg: 40, cd: 2.6, cost: 450, t: 10, vis: 7, r: 10, noAir: true },
  heli: { n: 'مروحية', ic: '🚁', hp: 150, sp: 3.4, rng: 5.5, dmg: 14, cd: .5, cost: 500, t: 10, vis: 9, r: 10, air: true },
  jet:  { n: 'مقاتلة', ic: '✈️', hp: 120, sp: 5.2, rng: 6, dmg: 26, cd: 1, cost: 700, t: 14, vis: 10, r: 10, air: true }
};
const BD = {
  hq:  { n: 'مقر القيادة', ic: '🏛️', s: 3, hp: 1600, vis: 10, cost: 0, bt: 0 },
  bar: { n: 'ثكنة', ic: '🏰', s: 2, hp: 700, vis: 7, cost: 300, bt: 8, train: ['inf'] },
  fac: { n: 'مصنع دبابات', ic: '🏭', s: 3, hp: 950, vis: 7, cost: 600, bt: 12, train: ['tank', 'art'] },
  air: { n: 'مطار', ic: '🛫', s: 3, hp: 900, vis: 8, cost: 800, bt: 14, train: ['heli', 'jet'] },
  twr: { n: 'برج دفاع', ic: '🗼', s: 1, hp: 520, vis: 8, cost: 250, bt: 6, rng: 7.5, dmg: 15, cd: .9 }
};
const BASE = [{ x: 8, y: H - 12 }, { x: W - 11, y: 9 }];
const MINES = [[19, 58], [13, 38], [24, 74], [60, 21], [66, 41], [55, 5]];
const DX = [1, -1, 0, 0, 1, 1, -1, -1], DY = [0, 0, 1, -1, 1, -1, 1, -1];

/* ---------- حالة ---------- */
let terr, blk, terrCv, fogCv, fogCtx, fogImg, explored, visible;
let units = [], blds = [], mines = [], fx = [], uid = 0, G = null;
let cam = { x: 0, y: 0, z: 1 }, sel = [], mode = '', placeType = '', amoveNext = false, boxMode = false;
let running = false, paused = false, lastPt = { x: 0, y: 0 }, box = null;
let pickedArmy = 'iraq', pickedDiff = 'normal', lastSig = '';

/* ---------- أدوات ---------- */
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rnd = (a, b) => a + Math.random() * (b - a);
const pickOne = a => a[Math.random() * a.length | 0];
function mulberry(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
function makeNoise(r, n) {
  const g = []; for (let i = 0; i < (n + 1) * (n + 1); i++) g.push(r());
  const s = t => t * t * (3 - 2 * t);
  return (x, y) => {
    x *= n; y *= n; const xi = x | 0, yi = y | 0, xf = s(x - xi), yf = s(y - yi);
    const a = g[yi * (n + 1) + xi], b = g[yi * (n + 1) + xi + 1], c = g[(yi + 1) * (n + 1) + xi], d = g[(yi + 1) * (n + 1) + xi + 1];
    const top = a + (b - a) * xf, bot = c + (d - c) * xf; return top + (bot - top) * yf;
  };
}
const hs = (x, y, k) => { let h = Math.imul(x + k * 131, 374761393) ^ Math.imul(y + k * 977, 668265263); h = Math.imul(h ^ h >>> 13, 1274126177); return ((h ^ h >>> 16) >>> 0) / 4294967296; };
let toastT = 0;
function toast(s) { const t = $('toast'); t.textContent = s; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('show'), 1800); }

/* ---------- الصوت والموسيقى ---------- */
let AC = null, SG = null, MG = null, NB = null, muted = false, step = 0, nextT = 0, musTimer = null, mi = 7, lastShot = 0;
function ac() {
  if (!AC) {
    AC = new (window.AudioContext || window.webkitAudioContext)();
    SG = AC.createGain(); SG.gain.value = .55; SG.connect(AC.destination);
    MG = AC.createGain(); MG.gain.value = muted ? 0 : .2; MG.connect(AC.destination);
    NB = AC.createBuffer(1, AC.sampleRate, AC.sampleRate); const d = NB.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  if (AC.state === 'suspended') AC.resume();
}
function tone(f, t0, dur, type, vol, dest, f2) {
  const o = AC.createOscillator(), g = AC.createGain(); o.type = type; o.frequency.setValueAtTime(f, t0);
  if (f2) o.frequency.exponentialRampToValueAtTime(f2, t0 + dur);
  g.gain.setValueAtTime(vol, t0); g.gain.exponentialRampToValueAtTime(.001, t0 + dur);
  o.connect(g); g.connect(dest || SG); o.start(t0); o.stop(t0 + dur + .03);
}
function noise(t0, dur, vol, fc, dest, hp) {
  const s = AC.createBufferSource(), f = AC.createBiquadFilter(), g = AC.createGain(); s.buffer = NB;
  f.type = hp ? 'highpass' : 'lowpass'; f.frequency.value = fc;
  g.gain.setValueAtTime(vol, t0); g.gain.exponentialRampToValueAtTime(.001, t0 + dur);
  s.connect(f); f.connect(g); g.connect(dest || SG); s.start(t0, Math.random() * .5); s.stop(t0 + dur + .03);
}
function sfx(k, near = true) {
  if (!AC || muted || !near) return; const t = AC.currentTime;
  if (k === 'click') tone(660, t, .06, 'square', .08);
  else if (k === 'ok') { tone(520, t, .08, 'triangle', .12); tone(780, t + .07, .1, 'triangle', .12); }
  else if (k === 'bad') tone(150, t, .18, 'sawtooth', .12);
  else if (k === 'shot') { if (t - lastShot < .05) return; lastShot = t; noise(t, .09, .2, 2400); tone(220, t, .08, 'square', .05, null, 90); }
  else if (k === 'cannon') { if (t - lastShot < .05) return; lastShot = t; noise(t, .25, .35, 700); tone(110, t, .22, 'sine', .3, null, 40); }
  else if (k === 'boom') { noise(t, .6, .5, 500); tone(90, t, .5, 'sine', .4, null, 30); }
  else if (k === 'cap') { tone(440, t, .1, 'triangle', .14); tone(660, t + .1, .1, 'triangle', .14); tone(880, t + .2, .2, 'triangle', .14); }
  else if (k === 'win') [0, 4, 7, 12].forEach((n, i) => tone(262 * 2 ** (n / 12), t + i * .16, .4, 'triangle', .2));
  else if (k === 'lose') [0, -3, -7, -12].forEach((n, i) => tone(262 * 2 ** (n / 12), t + i * .22, .5, 'sawtooth', .12));
}
const BASEN = [146.83, 155.56, 185, 196, 220, 233.08, 261.63];
const nf = i => BASEN[((i % 7) + 7) % 7] * 2 ** Math.floor(i / 7);
const RHY = [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0];
function musStep(t) {
  const sd = 60 / 92 / 2, p = step % 16;
  if (step % 16 === 0) { tone(73.42, t, sd * 16, 'sine', .22, MG); tone(110, t, sd * 16, 'sine', .12, MG); }
  const b = step % 8;
  if (b === 0 || b === 4) tone(130, t, .22, 'sine', .55, MG, 45);
  if (b === 2 || b === 3 || b === 6) noise(t, .07, .22, 3500, MG, true);
  if (RHY[p]) {
    const mv = pickOne([-2, -1, -1, 0, 1, 1, 2]);
    mi = clamp(mi + mv, 2, 12);
    if (step % 32 === 30) mi = 7;
    const f = nf(mi);
    tone(f, t, .55, 'triangle', .5, MG); tone(f * 2.004, t, .3, 'square', .05, MG);
  }
  step++;
}
function startMusic() {
  ac(); stopMusic(); step = 0; nextT = AC.currentTime + .1;
  musTimer = setInterval(() => { if (paused || !AC) { nextT = AC ? AC.currentTime + .1 : 0; return; } while (nextT < AC.currentTime + .4) { musStep(nextT); nextT += 60 / 92 / 2; } }, 100);
}
function stopMusic() { if (musTimer) clearInterval(musTimer); musTimer = null; }
function setMuted(m) { muted = m; if (MG) MG.gain.value = m ? 0 : .2; $('bSound').textContent = m ? '🔇' : '🔊'; }

/* ---------- الخريطة ---------- */
function genMap(seed) {
  const r = mulberry(seed), n1 = makeNoise(r, 6), n2 = makeNoise(r, 14), ph = r() * 6.28;
  terr = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const v = n1(x / W, y / H) * .65 + n2(x / W, y / H) * .35;
    let t = v > .6 ? 2 : (v < .37 ? 1 : 0);
    const cx = W / 2 + Math.sin(y * .13 + ph) * 9, d = Math.abs(x - cx);
    if (d < 2.7) t = 3; else if (d < 4.5 && t === 2) t = 0;
    terr[y * W + x] = t;
  }
  for (const by of [16, 40, 62]) for (let y = by - 1; y <= by + 1; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x; if (terr[i] === 3) terr[i] = 4; else if (terr[i] === 2) terr[i] = 0;
  }
  for (const b of BASE) { const bx = b.x + 1, by = b.y + 1; for (let y = by - 12; y <= by + 12; y++) for (let x = bx - 12; x <= bx + 12; x++) if (x >= 0 && y >= 0 && x < W && y < H && (x - bx) ** 2 + (y - by) ** 2 < 150) terr[y * W + x] = ((x * 7 + y * 3) % 11 === 0) ? 1 : 0; }
  for (const [mx, my] of MINES) for (let y = my - 2; y <= my + 3; y++) for (let x = mx - 2; x <= mx + 3; x++) if (x >= 0 && y >= 0 && x < W && y < H) terr[y * W + x] = 0;
}
function recalcBlk() {
  blk = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) blk[i] = (terr[i] === 2 || terr[i] === 3) ? 1 : 0;
  for (const b of blds) if (b.hp > 0) for (let y = b.ty; y < b.ty + b.h; y++) for (let x = b.tx; x < b.tx + b.w; x++) blk[y * W + x] = 1;
  for (const m of mines) for (let y = m.ty; y < m.ty + 2; y++) for (let x = m.tx; x < m.tx + 2; x++) blk[y * W + x] = 1;
}
function paintTerrain() {
  terrCv = document.createElement('canvas'); terrCv.width = W * T; terrCv.height = H * T; const c = terrCv.getContext('2d');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const t = terr[y * W + x], px = x * T, py = y * T, h = hs(x, y, 1);
    if (t === 3 || t === 4) {
      c.fillStyle = `rgb(${38 + h * 10 | 0},${108 + h * 14 | 0},${150 + h * 16 | 0})`; c.fillRect(px, py, T, T);
      if (h > .55) { c.strokeStyle = 'rgba(190,230,245,.35)'; c.lineWidth = 1.5; c.beginPath(); const yy = py + 6 + h * 18; c.moveTo(px + 4, yy); c.quadraticCurveTo(px + 12, yy - 3, px + 20, yy); c.stroke(); }
    } else if (t === 1) { c.fillStyle = `rgb(${100 + h * 14 | 0},${136 + h * 14 | 0},${64 + h * 10 | 0})`; c.fillRect(px, py, T, T); }
    else { c.fillStyle = `rgb(${209 + h * 14 | 0},${181 + h * 12 | 0},${125 + h * 10 | 0})`; c.fillRect(px, py, T, T); }
  }
  const r = mulberry(7);
  for (let i = 0; i < 700; i++) { const x = r() * W * T, y = r() * H * T, t = terr[(y / T | 0) * W + (x / T | 0)]; if (t === 0 || t === 1) { c.fillStyle = r() > .5 ? 'rgba(255,236,176,.08)' : 'rgba(120,80,30,.06)'; c.beginPath(); c.ellipse(x, y, 30 + r() * 60, 10 + r() * 18, r() * 3, 0, 7); c.fill(); } }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const t = terr[y * W + x], px = x * T, py = y * T, h = hs(x, y, 2);
    if (t === 0 || t === 1) {
      const wet = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([a, b]) => { const nx = x + a, ny = y + b; return nx >= 0 && ny >= 0 && nx < W && ny < H && terr[ny * W + nx] === 3; });
      c.fillStyle = 'rgba(70,60,30,.28)';
      if (wet[0]) c.fillRect(px + T - 5, py, 5, T); if (wet[1]) c.fillRect(px, py, 5, T); if (wet[2]) c.fillRect(px, py + T - 5, T, 5); if (wet[3]) c.fillRect(px, py, T, 5);
      if (t === 0 && h > .93) { c.fillStyle = 'rgba(110,90,60,.5)'; c.beginPath(); c.arc(px + h * 90 % T, py + (h * 700 % T), 2 + h * 2, 0, 7); c.fill(); }
      if (t === 1 && h > .5) drawPalm(c, px + 8 + hs(x, y, 3) * 16, py + 10 + hs(x, y, 4) * 16, .7 + h * .5);
    } else if (t === 2) {
      c.fillStyle = '#8a7660'; c.fillRect(px, py, T, T);
      const k = .5 + h * .6; c.fillStyle = '#a5917a'; c.beginPath(); c.moveTo(px - 2, py + T); c.lineTo(px + T * .45, py + T - T * k - 4); c.lineTo(px + T + 2, py + T); c.fill();
      c.fillStyle = '#6d5c49'; c.beginPath(); c.moveTo(px + T * .45, py + T - T * k - 4); c.lineTo(px + T + 2, py + T); c.lineTo(px + T * .5, py + T); c.fill();
    } else if (t === 4) {
      c.fillStyle = '#6b4a2b'; c.fillRect(px, py + 2, T, T - 4);
      c.strokeStyle = '#3f2a16'; c.lineWidth = 1.5; for (let k = 0; k < 4; k++) { c.beginPath(); c.moveTo(px + k * 8 + 4, py + 2); c.lineTo(px + k * 8 + 4, py + T - 2); c.stroke(); }
      c.fillStyle = '#8c6a44'; c.fillRect(px, py + 2, T, 3); c.fillRect(px, py + T - 5, T, 3);
    }
  }
}
function drawPalm(c, x, y, s) {
  c.save(); c.translate(x, y); c.scale(s, s);
  c.fillStyle = 'rgba(0,0,0,.2)'; c.beginPath(); c.ellipse(3, 8, 9, 4, 0, 0, 7); c.fill();
  c.strokeStyle = '#6a4a28'; c.lineWidth = 3; c.beginPath(); c.moveTo(0, 8); c.quadraticCurveTo(2, -2, 0, -8); c.stroke();
  c.strokeStyle = '#2f6b2b'; c.lineWidth = 2.5; c.lineCap = 'round';
  for (let i = 0; i < 7; i++) { const a = i / 7 * 6.28; c.beginPath(); c.moveTo(0, -8); c.quadraticCurveTo(Math.cos(a) * 7, -8 + Math.sin(a) * 4 - 4, Math.cos(a) * 12, -8 + Math.sin(a) * 7); c.stroke(); }
  c.restore();
}

/* ---------- المسارات ---------- */
const pv = new Int32Array(W * H), pq = new Int32Array(W * H), ps = new Int32Array(W * H); let pstamp = 0;
function findPath(sx, sy, gx, gy) {
  sx = clamp(sx, 0, W - 1); sy = clamp(sy, 0, H - 1); gx = clamp(gx, 0, W - 1); gy = clamp(gy, 0, H - 1);
  if (blk[gy * W + gx]) {
    let best = null, bd = 1e9;
    for (let r = 1; r < 8 && !best; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue; const nx = gx + dx, ny = gy + dy;
      if (nx < 0 || ny < 0 || nx >= W || ny >= H || blk[ny * W + nx]) continue;
      const d = (nx - sx) ** 2 + (ny - sy) ** 2; if (d < bd) { bd = d; best = [nx, ny]; }
    }
    if (!best) return null; gx = best[0]; gy = best[1];
  }
  if (sx === gx && sy === gy) return [];
  pstamp++; let h = 0, t = 0; const si = sy * W + sx; pq[t++] = si; ps[si] = pstamp; pv[si] = -1;
  let found = false, bestI = si, bestD = 1e9;
  while (h < t) {
    const c = pq[h++], cx = c % W, cy = c / W | 0, dd = (cx - gx) ** 2 + (cy - gy) ** 2;
    if (dd < bestD) { bestD = dd; bestI = c; }
    if (cx === gx && cy === gy) { found = true; break; }
    for (let k = 0; k < 8; k++) {
      const nx = cx + DX[k], ny = cy + DY[k]; if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
      const ni = ny * W + nx; if (ps[ni] === pstamp || blk[ni]) continue;
      if (k > 3 && (blk[cy * W + nx] || blk[ny * W + cx])) continue;
      ps[ni] = pstamp; pv[ni] = c; pq[t++] = ni;
    }
  }
  let c = found ? gy * W + gx : bestI; const p = [];
  while (c !== si && c !== -1) { p.push([c % W, c / W | 0]); c = pv[c]; }
  return p.reverse();
}

const pathFor = (u, gx, gy) => UD[u.type].air ? [[clamp(gx, 0, W - 1), clamp(gy, 0, H - 1)]] : (findPath(u.x / T | 0, u.y / T | 0, gx, gy) || []);
/* ---------- الكيانات ---------- */
function addB(type, team, tx, ty, built) {
  const d = BD[type], b = { id: ++uid, kind: 'b', type, team, tx, ty, w: d.s, h: d.s, hp: d.hp, max: d.hp, q: [], qt: 0, cd: 0, con: built ? 1 : 0, rally: null, ta: 0 };
  blds.push(b); return b;
}
function addU(type, team, x, y) {
  const d = UD[type], a = ARMIES[G.army[team]], hp = d.hp * (a.hp || 1);
  const u = { id: ++uid, kind: 'u', type, team, x, y, a: team ? Math.PI : 0, ta: 0, hp, max: hp, path: null, tgt: null, cd: 0, amove: false, dest: null, rp: 0, forced: false, sent: false };
  units.push(u); return u;
}
function freeSpot(b) {
  const cx = b.tx + b.w / 2, cy = b.ty + b.h / 2; let best = null, bd = 1e9;
  for (let r = Math.ceil(b.w / 2) + 1; r < 9 && !best; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    if (Math.max(Math.abs(dx), Math.abs(dy)) !== r) continue; const nx = (cx + dx) | 0, ny = (cy + dy) | 0;
    if (nx < 0 || ny < 0 || nx >= W || ny >= H || blk[ny * W + nx]) continue;
    const d = Math.hypot(nx - (BASE[b.team ? 0 : 1].x), ny - BASE[b.team ? 0 : 1].y); if (d < bd) { bd = d; best = [nx, ny]; }
  }
  return best ? [best[0] * T + T / 2, best[1] * T + T / 2] : [cx * T, (cy + 2) * T];
}
function canPlace(team, type, tx, ty) {
  const s = BD[type].s; if (tx < 1 || ty < 1 || tx + s > W - 1 || ty + s > H - 1) return false;
  for (let y = ty; y < ty + s; y++) for (let x = tx; x < tx + s; x++) { const i = y * W + x; if (blk[i]) return false; if (team === 0 && !explored[i]) return false; }
  for (const m of mines) if (tx < m.tx + 3 && tx + s > m.tx - 1 && ty < m.ty + 3 && ty + s > m.ty - 1) return false;
  const hq = blds.find(b => b.team === team && b.type === 'hq' && b.hp > 0); if (!hq || Math.hypot(tx - hq.tx, ty - hq.ty) > 16) return false;
  return true;
}
function queue(b, type) { const c = UD[type].cost; if (G.gold[b.team] < c || b.q.length >= 6) return false; G.gold[b.team] -= c; b.q.push(type); return true; }

/* ---------- القتال ---------- */
const isVis = (x, y) => visible[clamp(y / T | 0, 0, H - 1) * W + clamp(x / T | 0, 0, W - 1)] === 1;
function nearestEnemy(x, y, team, rad, canAir = true) {
  let bu = null, bd = rad * rad, bb = null, bbd = rad * rad;
  for (const u of units) { if (u.team === team || u.hp <= 0) continue; if (!canAir && UD[u.type].air) continue; if (team === 0 && !isVis(u.x, u.y)) continue; const d = (u.x - x) ** 2 + (u.y - y) ** 2; if (d < bd) { bd = d; bu = u; } }
  if (bu) return bu;
  for (const b of blds) { if (b.team === team || b.hp <= 0) continue; const cx = (b.tx + b.w / 2) * T, cy = (b.ty + b.h / 2) * T; if (team === 0 && !isVis(cx, cy) && !explored[(b.ty * W + b.tx)]) continue; const e = Math.max(0, Math.hypot(cx - x, cy - y) - b.w * T / 2); if (e * e < bbd) { bbd = e * e; bb = b; } }
  return bb;
}
function hit(tg, dm, fromTeam) {
  if (tg.hp <= 0) return; tg.hp -= dm;
  if (tg.hp <= 0 && !tg.dead) {
    tg.dead = 1; const x = tg.kind === 'b' ? (tg.tx + tg.w / 2) * T : tg.x, y = tg.kind === 'b' ? (tg.ty + tg.h / 2) * T : tg.y;
    fx.push({ k: 'boom', x, y, t: tg.kind === 'b' ? .9 : .45, d: tg.kind === 'b' ? .9 : .45, s: tg.kind === 'b' ? 46 : 20 });
    sfx('boom', fromTeam === 0 || tg.team === 0 || isVis(x, y));
  }
}
function fire(u, tg, d, a) {
  let dm = d.dmg * (a.dmg || 1); if (tg.kind === 'b' && u.type === 'tank') dm *= 1.4; if (tg.type === 'tank' && u.type === 'inf') dm *= .55;
  const tx = tg.kind === 'b' ? (tg.tx + tg.w / 2) * T : tg.x, ty = tg.kind === 'b' ? (tg.ty + tg.h / 2) * T : tg.y;
  fx.push({ k: 'tr', x1: u.x + Math.cos(u.ta) * 9, y1: u.y + Math.sin(u.ta) * 9, x2: tx + rnd(-5, 5), y2: ty + rnd(-5, 5), t: .12, d: .12, big: u.type === 'tank' });
  hit(tg, dm, u.team); sfx(u.type === 'tank' ? 'cannon' : 'shot', isVis(u.x, u.y) || u.team === 0);
}
function moveAlong(u, dt, d) {
  const p = u.path; if (!p || !p.length) return; const w = p[0], wx = w[0] * T + T / 2, wy = w[1] * T + T / 2, dx = wx - u.x, dy = wy - u.y, dist = Math.hypot(dx, dy), st = d.sp * T * dt;
  u.a = Math.atan2(dy, dx); if (dist <= st) { u.x = wx; u.y = wy; p.shift(); } else { u.x += dx / dist * st; u.y += dy / dist * st; }
}
function updU(u, dt) {
  const d = UD[u.type], a = ARMIES[G.army[u.team]]; u.cd -= dt;
  if (u.tgt && u.tgt.hp <= 0) { u.tgt = null; u.forced = false; }
  if (u.tgt && d.noAir && u.tgt.kind === 'u' && UD[u.tgt.type].air) { u.tgt = null; u.forced = false; }
  if (!u.tgt && (u.amove || !u.path || !u.path.length)) {
    const e = nearestEnemy(u.x, u.y, u.team, (u.amove ? d.rng + 2.5 : d.rng + 3) * T, !d.noAir); if (e) { u.tgt = e; u.path = null; }
  }
  if (u.tgt) {
    const tg = u.tgt, tx = tg.kind === 'b' ? (tg.tx + tg.w / 2) * T : tg.x, ty = tg.kind === 'b' ? (tg.ty + tg.h / 2) * T : tg.y;
    const dist = Math.hypot(tx - u.x, ty - u.y) - (tg.kind === 'b' ? tg.w * T / 2 : 0); u.ta = Math.atan2(ty - u.y, tx - u.x);
    if (dist > d.rng * T) {
      if (dist > (d.rng + 9) * T && !u.forced) { u.tgt = null; }
      else { u.rp -= dt; if (!u.path || u.rp <= 0) { u.rp = .8; u.path = pathFor(u, tx / T | 0, ty / T | 0); } moveAlong(u, dt, d); }
    } else { u.path = null; u.a = u.ta; if (u.cd <= 0) { fire(u, tg, d, a); u.cd = d.cd; } }
  } else if (u.path && u.path.length) moveAlong(u, dt, d);
  else if (u.amove && u.dest) {
    if (Math.hypot(u.dest[0] * T + T / 2 - u.x, u.dest[1] * T + T / 2 - u.y) > T * 1.5) u.path = pathFor(u, u.dest[0], u.dest[1]);
    else { u.amove = false; u.dest = null; }
  }
}
function updB(b, dt) {
  if (b.con < 1) { b.con = Math.min(1, b.con + dt / BD[b.type].bt); return; }
  const d = BD[b.type];
  if (d.train && b.q.length) {
    b.qt += dt; if (b.qt >= UD[b.q[0]].t) {
      b.qt = 0; const t = b.q.shift(), p = freeSpot(b), u = addU(t, b.team, p[0], p[1]);
      if (b.rally && b.team === 0) u.path = pathFor(u, b.rally[0], b.rally[1]);
      if (b.team === 0) sfx('ok');
    }
  }
  if (b.type === 'twr') {
    b.cd -= dt; const cx = (b.tx + .5) * T, cy = (b.ty + .5) * T, e = nearestEnemy(cx, cy, b.team, d.rng * T);
    if (e) { const tx = e.kind === 'b' ? (e.tx + e.w / 2) * T : e.x, ty = e.kind === 'b' ? (e.ty + e.h / 2) * T : e.y; b.ta = Math.atan2(ty - cy, tx - cx); if (b.cd <= 0) { b.cd = d.cd; fx.push({ k: 'tr', x1: cx + Math.cos(b.ta) * 10, y1: cy + Math.sin(b.ta) * 10, x2: tx, y2: ty, t: .12, d: .12 }); hit(e, d.dmg * (ARMIES[G.army[b.team]].dmg || 1), b.team); sfx('shot', isVis(cx, cy)); } }
  }
}

/* ---------- الذكاء الاصطناعي ---------- */
const ai = { t: 0, bt: 10, wt: 0, mt: 14 };
function autoPlace(type) {
  const hq = blds.find(b => b.team === 1 && b.type === 'hq' && b.hp > 0); if (!hq) return false;
  for (let i = 0; i < 40; i++) { const tx = hq.tx + (Math.random() * 24 - 12 | 0), ty = hq.ty + (Math.random() * 24 - 12 | 0); if (canPlace(1, type, tx, ty)) { G.gold[1] -= BD[type].cost; addB(type, 1, tx, ty, false); recalcBlk(); return true; } }
  return false;
}
function updAI(dt) {
  const cf = DIFF[G.diff]; ai.t += dt;
  if (ai.t >= cf.every) {
    ai.t = 0; const ready = blds.filter(b => b.team === 1 && b.hp > 0 && b.con >= 1), facs = ready.filter(b => b.type === 'fac'), bars = ready.filter(b => b.type === 'bar');
    let b = null, tp = null;
    const airs = ready.filter(b => b.type === 'air'); if (airs.length && G.gold[1] >= 800 && Math.random() < .4) { b = pickOne(airs); tp = pickOne(['heli', 'jet']); } else if (facs.length && G.gold[1] >= UD.tank.cost + 120 && Math.random() < .55) { b = pickOne(facs); tp = Math.random() < .25 ? 'art' : 'tank'; } else if (bars.length && G.gold[1] >= UD.inf.cost) { b = pickOne(bars); tp = 'inf'; }
    if (b && b.q.length < 3) queue(b, tp);
  }
  ai.bt += dt;
  if (ai.bt >= cf.bt) {
    ai.bt = 0; const mine = blds.filter(b => b.team === 1 && b.hp > 0), n = t => mine.filter(b => b.type === t).length, maxF = G.diff === 'hard' ? 3 : G.diff === 'normal' ? 2 : 1;
    if (G.diff !== 'easy' && n('air') < 1 && n('fac') >= 1 && G.gold[1] >= 1000) autoPlace('air');
    else if (n('fac') < maxF && G.gold[1] >= 800) autoPlace('fac');
    else if (n('bar') < maxF + 1 && G.gold[1] >= 500) autoPlace('bar');
    else if (n('twr') < maxF * 2 && G.gold[1] >= 650) autoPlace('twr');
  }
  ai.wt += dt;
  if (ai.wt >= 3) {
    ai.wt = 0; const free = units.filter(u => u.team === 1 && u.hp > 0 && !u.sent);
    if (free.length >= cf.wave) {
      const tgtB = blds.filter(b => b.team === 0 && b.hp > 0).sort((a, b) => (a.type === 'hq' ? 0 : 1) - (b.type === 'hq' ? 0 : 1))[0];
      if (tgtB) for (const u of free) { u.sent = true; u.amove = true; u.dest = [tgtB.tx + 1, tgtB.ty + 1]; u.path = pathFor(u, u.dest[0], u.dest[1]); }
    }
  }
  ai.mt += dt;
  if (ai.mt >= 22) {
    ai.mt = 0; const free = units.filter(u => u.team === 1 && u.hp > 0 && !u.sent && u.type === 'inf');
    const hq = BASE[1], m = mines.filter(m => m.owner !== 1).sort((a, b) => Math.hypot(a.tx - hq.x, a.ty - hq.y) - Math.hypot(b.tx - hq.x, b.ty - hq.y))[0];
    if (m && free.length >= 2) for (const u of free.slice(0, 2)) { u.sent = true; u.path = findPath(u.x / T | 0, u.y / T | 0, m.tx, m.ty) || []; }
  }
}

/* ---------- الضباب ---------- */
function updFog() {
  visible.fill(0);
  const mark = (cx, cy, r) => { const r2 = r * r; for (let y = Math.max(0, cy - r | 0); y <= Math.min(H - 1, cy + r | 0); y++) for (let x = Math.max(0, cx - r | 0); x <= Math.min(W - 1, cx + r | 0); x++) if ((x - cx) ** 2 + (y - cy) ** 2 <= r2) { visible[y * W + x] = 1; explored[y * W + x] = 1; } };
  for (const u of units) if (u.team === 0) mark(u.x / T, u.y / T, UD[u.type].vis);
  for (const b of blds) if (b.team === 0) mark(b.tx + b.w / 2, b.ty + b.h / 2, BD[b.type].vis);
  const d = fogImg.data; for (let i = 0; i < W * H; i++) { d[i * 4] = 14; d[i * 4 + 1] = 10; d[i * 4 + 2] = 6; d[i * 4 + 3] = !explored[i] ? 255 : !visible[i] ? 115 : 0; }
  fogCtx.putImageData(fogImg, 0, 0);
}

/* ---------- تحديث ---------- */
let fogTimer = 0, panelTimer = 0;
function update(dt) {
  G.time += dt;
  for (let t = 0; t < 2; t++) {
    const mc = mines.filter(m => m.owner === t).length, a = ARMIES[G.army[t]], inc = (2 + 4 * mc) * (a.inc || 1) * (t ? DIFF[G.diff].gm : 1);
    G.gold[t] += inc * dt; G.inc[t] = inc;
  }
  for (const m of mines) {
    const c = [0, 0], mx = (m.tx + 1) * T, my = (m.ty + 1) * T; for (const u of units) if (u.hp > 0 && !UD[u.type].air && Math.hypot(u.x - mx, u.y - my) < 3.4 * T) c[u.team]++;
    const tm = c[0] && !c[1] ? 0 : c[1] && !c[0] ? 1 : -1;
    if (tm >= 0 && m.owner !== tm) { m.prog += dt; if (m.prog >= 3) { m.owner = tm; m.prog = 0; if (tm === 0) { sfx('cap'); toast('سيطرت على منجم ذهب ⛏'); } } } else m.prog = Math.max(0, m.prog - dt);
  }
  for (const b of blds) updB(b, dt);
  for (const u of units) updU(u, dt);
  for (let i = 0; i < units.length; i++) for (let j = i + 1; j < units.length; j++) {
    const a = units[i], b = units[j]; if (!!UD[a.type].air !== !!UD[b.type].air) continue; const dx = b.x - a.x, dy = b.y - a.y, md = (UD[a.type].r + UD[b.type].r) * .9, d2 = dx * dx + dy * dy;
    if (d2 < md * md && d2 > .01) { const d = Math.sqrt(d2), p = (md - d) / 2, ux = dx / d * p, uy = dy / d * p; if (UD[a.type].air || !blkAt(a.x - ux, a.y - uy)) { a.x -= ux; a.y -= uy; } if (UD[b.type].air || !blkAt(b.x + ux, b.y + uy)) { b.x += ux; b.y += uy; } }
  }
  updAI(dt);
  const nb = blds.length; units = units.filter(u => u.hp > 0); blds = blds.filter(b => b.hp > 0); if (blds.length !== nb) recalcBlk();
  sel = sel.filter(e => e.hp > 0);
  for (const f of fx) f.t -= dt; fx = fx.filter(f => f.t > 0);
  fogTimer -= dt; if (fogTimer <= 0) { fogTimer = .2; updFog(); }
  panelTimer -= dt; if (panelTimer <= 0) { panelTimer = .25; hudTick(); }
  if (!G.over) {
    if (!blds.some(b => b.team === 1 && b.type === 'hq')) endGame(true); else if (!blds.some(b => b.team === 0 && b.type === 'hq')) endGame(false);
  }
}
const blkAt = (x, y) => { const tx = x / T | 0, ty = y / T | 0; return tx < 0 || ty < 0 || tx >= W || ty >= H || blk[ty * W + tx]; };
function endGame(win) {
  G.over = true; sfx(win ? 'win' : 'lose'); $('endT').textContent = win ? 'النصر! 🏆' : 'هُزمت 💔';
  const m = G.time / 60 | 0, s = G.time % 60 | 0; $('endS').textContent = (win ? 'دمّرت مقر العدو' : 'سقط مقر قيادتك') + ' · المدة ' + m + ':' + String(s).padStart(2, '0');
  setTimeout(() => { $('end').hidden = false; }, 1200);
}

/* ---------- الرسم ---------- */
function drawUnit(u) {
  const d = UD[u.type], col = ARMIES[G.army[u.team]].c; ctx.save(); ctx.translate(u.x, u.y);
  ctx.fillStyle = 'rgba(0,0,0,.28)'; ctx.beginPath(); ctx.ellipse(1, d.air ? 17 : 3, d.r, d.r * .7, 0, 0, 7); ctx.fill();
  if (d.air) ctx.translate(0, -14);
  ctx.rotate(u.a);
  if (u.type === 'tank') {
    ctx.fillStyle = '#2b2823'; ctx.fillRect(-12, -9, 24, 4); ctx.fillRect(-12, 5, 24, 4);
    ctx.fillStyle = col; ctx.fillRect(-10, -6, 20, 12); ctx.fillStyle = 'rgba(0,0,0,.22)'; ctx.fillRect(-10, 1, 20, 5);
    ctx.rotate((u.tgt ? u.ta : u.a) - u.a); ctx.fillStyle = '#26323d'; ctx.beginPath(); ctx.arc(0, 0, 5.5, 0, 7); ctx.fill(); ctx.strokeStyle = col; ctx.lineWidth = 1.5; ctx.stroke(); ctx.fillStyle = '#1a232b'; ctx.fillRect(0, -1.6, 14, 3.2);
  } else if (u.type === 'art') {
    ctx.fillStyle = '#2b2823'; ctx.fillRect(-11, -8, 22, 4); ctx.fillRect(-11, 4, 22, 4); ctx.fillStyle = col; ctx.fillRect(-9, -5, 18, 10); ctx.fillStyle = '#1a232b'; ctx.fillRect(-2, -2, 24, 4);
  } else if (u.type === 'heli') {
    ctx.fillStyle = col; ctx.beginPath(); ctx.ellipse(0, 0, 11, 5.5, 0, 0, 7); ctx.fill(); ctx.fillRect(-20, -1.5, 11, 3); ctx.fillStyle = '#9fd3e8'; ctx.beginPath(); ctx.ellipse(5, 0, 4, 3, 0, 0, 7); ctx.fill();
    ctx.rotate((G ? G.time : 0) * 22 - u.a); ctx.strokeStyle = 'rgba(240,240,240,.75)'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(-17, 0); ctx.lineTo(17, 0); ctx.moveTo(0, -17); ctx.lineTo(0, 17); ctx.stroke();
  } else if (u.type === 'jet') {
    ctx.fillStyle = col; ctx.strokeStyle = '#1a1a1a'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(16, 0); ctx.lineTo(-9, -11); ctx.lineTo(-4, 0); ctx.lineTo(-9, 11); ctx.closePath(); ctx.fill(); ctx.stroke(); ctx.fillStyle = '#9fd3e8'; ctx.fillRect(3, -1.5, 5, 3);
  } else {
    ctx.fillStyle = col; ctx.beginPath(); ctx.arc(0, 0, 5, 0, 7); ctx.fill(); ctx.fillStyle = '#d6c79a'; ctx.beginPath(); ctx.arc(1, 0, 2.8, 0, 7); ctx.fill(); ctx.fillStyle = '#222'; ctx.fillRect(3, 1.5, 9, 2);
  }
  ctx.restore();
  if (u.hp < u.max || sel.includes(u)) bar(u.x, u.y - (d.air ? 32 : u.type === 'tank' ? 17 : 12), 20, u.hp / u.max);
  if (sel.includes(u)) { ctx.strokeStyle = '#7dff9b'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.ellipse(u.x, u.y + 2, d.r + 4, d.r * .8 + 3, 0, 0, 7); ctx.stroke(); }
}
function bar(x, y, w, f) { ctx.fillStyle = 'rgba(0,0,0,.65)'; ctx.fillRect(x - w / 2 - 1, y - 1, w + 2, 5); ctx.fillStyle = f > .5 ? '#5ed36b' : f > .25 ? '#e8c14a' : '#e0503e'; ctx.fillRect(x - w / 2, y, w * Math.max(0, f), 3); }
function drawB(b) {
  const col = ARMIES[G.army[b.team]].c, x = b.tx * T, y = b.ty * T, w = b.w * T; ctx.save(); ctx.globalAlpha = b.con < 1 ? .55 : 1;
  ctx.fillStyle = 'rgba(0,0,0,.3)'; ctx.fillRect(x + 4, y + 5, w, w);
  if (b.type === 'hq') {
    ctx.fillStyle = '#c4a46c'; ctx.fillRect(x, y, w, w); ctx.strokeStyle = '#6d5530'; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, w - 2);
    ctx.fillStyle = '#a88a55'; ctx.fillRect(x + 6, y + 6, w - 12, w - 12);
    ctx.fillStyle = '#e9d58c'; ctx.beginPath(); ctx.arc(x + w / 2, y + w / 2, w * .26, 0, 7); ctx.fill(); ctx.strokeStyle = '#8a7237'; ctx.lineWidth = 2; ctx.stroke();
    ctx.strokeStyle = '#2f8d9c'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(x + w / 2, y + w / 2, w * .16, 0, 7); ctx.stroke();
    for (const [cx, cy] of [[x + 5, y + 5], [x + w - 5, y + 5], [x + 5, y + w - 5], [x + w - 5, y + w - 5]]) { ctx.fillStyle = '#8f7444'; ctx.beginPath(); ctx.arc(cx, cy, 6, 0, 7); ctx.fill(); }
    ctx.fillStyle = '#4a3a20'; ctx.fillRect(x + w / 2 - 1, y - 12, 2, 20); ctx.fillStyle = col; ctx.fillRect(x + w / 2 + 1, y - 12, 14, 9);
  } else if (b.type === 'bar') {
    ctx.fillStyle = '#b09468'; ctx.fillRect(x, y, w, w); ctx.strokeStyle = '#6d5530'; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, w - 2);
    ctx.fillStyle = col; ctx.fillRect(x + 4, y + 4, w - 8, 12); ctx.fillStyle = '#3a2d1a'; ctx.fillRect(x + w / 2 - 7, y + w - 20, 14, 18);
    ctx.fillStyle = '#e9d58c'; ctx.fillRect(x + 8, y + 22, 6, 6);
  } else if (b.type === 'fac') {
    ctx.fillStyle = '#8d8a80'; ctx.fillRect(x, y, w, w); ctx.strokeStyle = '#4e4c46'; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, w - 2);
    ctx.fillStyle = col; ctx.fillRect(x + 4, y + 4, w - 8, 8); ctx.fillStyle = '#34322d'; ctx.fillRect(x + 8, y + w - 34, 24, 30); ctx.fillRect(x + w - 32, y + w - 34, 24, 30);
    ctx.fillStyle = '#5c5a54'; ctx.fillRect(x + w - 18, y + 14, 10, 16);
  } else if (b.type === 'air') {
    ctx.fillStyle = '#777b80'; ctx.fillRect(x, y, w, w); ctx.strokeStyle = '#44484c'; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, w - 2);
    ctx.fillStyle = '#ececec'; for (let k = 0; k < 3; k++) ctx.fillRect(x + 12 + k * 30, y + 14, 6, w - 28); ctx.fillStyle = col; ctx.fillRect(x + 4, y + 4, w - 8, 6);
  } else if (b.type === 'twr') {
    ctx.fillStyle = '#7b7467'; ctx.beginPath(); ctx.arc(x + T / 2, y + T / 2, 12, 0, 7); ctx.fill(); ctx.strokeStyle = col; ctx.lineWidth = 3; ctx.stroke();
    ctx.save(); ctx.translate(x + T / 2, y + T / 2); ctx.rotate(b.ta); ctx.fillStyle = '#2a2a2a'; ctx.fillRect(0, -2.5, 16, 5); ctx.beginPath(); ctx.arc(0, 0, 6, 0, 7); ctx.fill(); ctx.restore();
  }
  ctx.restore();
  if (b.con < 1) { ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillRect(x + 4, y + w / 2 - 4, w - 8, 8); ctx.fillStyle = '#e0b050'; ctx.fillRect(x + 5, y + w / 2 - 3, (w - 10) * b.con, 6); }
  if (b.hp < b.max || sel.includes(b)) bar(x + w / 2, y - 6, Math.min(w, 56), b.hp / b.max);
  if (sel.includes(b)) { ctx.strokeStyle = '#7dff9b'; ctx.lineWidth = 2; ctx.strokeRect(x - 3, y - 3, w + 6, w + 6); if (b.rally) { const rx = b.rally[0] * T + T / 2, ry = b.rally[1] * T + T / 2; ctx.strokeStyle = '#7dff9b'; ctx.setLineDash([5, 5]); ctx.beginPath(); ctx.moveTo(x + w / 2, y + w / 2); ctx.lineTo(rx, ry); ctx.stroke(); ctx.setLineDash([]); ctx.fillStyle = '#7dff9b'; ctx.fillRect(rx - 1, ry - 14, 2, 14); ctx.fillRect(rx + 1, ry - 14, 9, 6); } }
}
function drawMine(m) {
  const x = m.tx * T, y = m.ty * T; ctx.fillStyle = 'rgba(70,45,15,.55)'; ctx.beginPath(); ctx.ellipse(x + T, y + T + 4, T * .95, T * .8, 0, 0, 7); ctx.fill();
  for (let i = 0; i < 7; i++) { const a = hs(i, m.tx, 5) * 6.28, r = hs(i, m.ty, 6) * 20, nx = x + T + Math.cos(a) * r, ny = y + T + Math.sin(a) * r * .8, s = 4 + hs(i, 1, 7) * 6; ctx.fillStyle = '#f0c030'; ctx.beginPath(); ctx.moveTo(nx, ny - s); ctx.lineTo(nx + s, ny); ctx.lineTo(nx, ny + s * .7); ctx.lineTo(nx - s, ny); ctx.closePath(); ctx.fill(); ctx.fillStyle = 'rgba(255,255,255,.5)'; ctx.fillRect(nx - 1, ny - s + 2, 2, 3); }
  const oc = m.owner < 0 ? '#ffffff' : ARMIES[G.army[m.owner]].c; ctx.strokeStyle = oc; ctx.lineWidth = 3; ctx.globalAlpha = .9; ctx.beginPath(); ctx.arc(x + T, y + T, T * 1.05, 0, 7); ctx.stroke(); ctx.globalAlpha = 1;
  if (m.prog > 0) { ctx.strokeStyle = '#7dff9b'; ctx.lineWidth = 5; ctx.beginPath(); ctx.arc(x + T, y + T, T * 1.2, -1.57, -1.57 + m.prog / 3 * 6.28); ctx.stroke(); }
}
function render() {
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = '#000'; ctx.fillRect(0, 0, cv.width, cv.height);
  if (!running || !terrCv) return;
  const z = cam.z * dpr; ctx.setTransform(z, 0, 0, z, -cam.x * z, -cam.y * z); ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(terrCv, 0, 0);
  for (const m of mines) if (explored[(m.ty * W + m.tx)]) drawMine(m);
  for (const b of blds) if (b.team === 0 || explored[b.ty * W + b.tx]) drawB(b);
  const vl = [...units].filter(u => u.team === 0 || isVis(u.x, u.y)).sort((a, b) => (!!UD[a.type].air - !!UD[b.type].air) || a.y - b.y); for (const u of vl) drawUnit(u);
  for (const f of fx) {
    if (f.k === 'tr') { ctx.globalAlpha = f.t / f.d; ctx.strokeStyle = f.big ? '#ffb347' : '#ffe27a'; ctx.lineWidth = f.big ? 3 : 1.8; ctx.beginPath(); ctx.moveTo(f.x1, f.y1); ctx.lineTo(f.x2, f.y2); ctx.stroke(); ctx.globalAlpha = 1; }
    else if (f.k === 'boom') { const p = 1 - f.t / f.d; ctx.globalAlpha = Math.max(0, 1 - p); ctx.fillStyle = '#ff8a2a'; ctx.beginPath(); ctx.arc(f.x, f.y, f.s * (.3 + p), 0, 7); ctx.fill(); ctx.fillStyle = '#ffe08a'; ctx.beginPath(); ctx.arc(f.x, f.y, f.s * (.15 + p * .5), 0, 7); ctx.fill(); ctx.globalAlpha = 1; }
    else if (f.k === 'mark') { const p = f.t / f.d; ctx.strokeStyle = f.c || '#7dff9b'; ctx.lineWidth = 2; ctx.globalAlpha = p; ctx.beginPath(); ctx.arc(f.x, f.y, 6 + (1 - p) * 14, 0, 7); ctx.stroke(); ctx.globalAlpha = 1; }
  }
  ctx.drawImage(fogCv, 0, 0, W * T, H * T);
  if (mode === 'place') {
    const hq = blds.find(b => b.team === 0 && b.type === 'hq'); if (hq) { ctx.strokeStyle = 'rgba(125,255,155,.5)'; ctx.setLineDash([8, 8]); ctx.lineWidth = 2; ctx.beginPath(); ctx.arc((hq.tx + 1.5) * T, (hq.ty + 1.5) * T, 16 * T, 0, 7); ctx.stroke(); ctx.setLineDash([]); }
    const s = BD[placeType].s, w = toWorld(lastPt.x, lastPt.y), tx = (w.x / T - s / 2 + .5) | 0, ty = (w.y / T - s / 2 + .5) | 0, ok = canPlace(0, placeType, tx, ty);
    ctx.fillStyle = ok ? 'rgba(80,255,120,.35)' : 'rgba(255,70,60,.35)'; ctx.fillRect(tx * T, ty * T, s * T, s * T); ctx.strokeStyle = ok ? '#7dff9b' : '#ff5a4a'; ctx.lineWidth = 2; ctx.strokeRect(tx * T, ty * T, s * T, s * T);
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  if (box) { ctx.strokeStyle = '#7dff9b'; ctx.fillStyle = 'rgba(125,255,155,.15)'; ctx.lineWidth = 1.5; const x = Math.min(box.x0, box.x1), y = Math.min(box.y0, box.y1), w = Math.abs(box.x1 - box.x0), h = Math.abs(box.y1 - box.y0); ctx.fillRect(x, y, w, h); ctx.strokeRect(x, y, w, h); }
  drawMini();
}
function drawMini() {
  const sc = MM / (W * T); mctx.clearRect(0, 0, MM, MM); mctx.drawImage(terrCv, 0, 0, MM, MM);
  for (const m of mines) if (explored[m.ty * W + m.tx]) { mctx.fillStyle = m.owner < 0 ? '#f0c030' : ARMIES[G.army[m.owner]].c; mctx.fillRect(m.tx * T * sc, m.ty * T * sc, 6, 6); }
  for (const b of blds) if (b.team === 0 || explored[b.ty * W + b.tx]) { mctx.fillStyle = ARMIES[G.army[b.team]].c; mctx.fillRect(b.tx * T * sc, b.ty * T * sc, b.w * T * sc, b.w * T * sc); }
  for (const u of units) if (u.team === 0 || isVis(u.x, u.y)) { mctx.fillStyle = ARMIES[G.army[u.team]].c; mctx.fillRect(u.x * sc - 1, u.y * sc - 1, 3, 3); }
  mctx.drawImage(fogCv, 0, 0, MM, MM);
  mctx.strokeStyle = '#fff'; mctx.lineWidth = 1.5; mctx.strokeRect(cam.x * sc, cam.y * sc, vw / cam.z * sc, vh / cam.z * sc);
}

/* ---------- الكاميرا والإدخال ---------- */
function clampCam() { const zmin = Math.max(vw / (W * T), vh / (H * T)); cam.z = clamp(cam.z, zmin, 2.2); cam.x = clamp(cam.x, 0, W * T - vw / cam.z); cam.y = clamp(cam.y, 0, H * T - vh / cam.z); }
const toWorld = (sx, sy) => ({ x: sx / cam.z + cam.x, y: sy / cam.z + cam.y });
function resize() { dpr = Math.min(window.devicePixelRatio || 1, 2); vw = innerWidth; vh = innerHeight; cv.width = vw * dpr; cv.height = vh * dpr; clampCam(); }
addEventListener('resize', resize);

const ptr = new Map(); let lastC = null, lastD = 0;
cv.addEventListener('contextmenu', e => e.preventDefault());
cv.addEventListener('pointerdown', e => {
  if (!running || paused) return; ac(); cv.setPointerCapture(e.pointerId); lastPt = { x: e.clientX, y: e.clientY };
  ptr.set(e.pointerId, { x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, moved: false, btn: e.button });
  if (ptr.size === 2) { const [a, b] = [...ptr.values()]; lastC = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }; lastD = Math.hypot(a.x - b.x, a.y - b.y); box = null; }
});
cv.addEventListener('pointermove', e => {
  lastPt = { x: e.clientX, y: e.clientY }; const p = ptr.get(e.pointerId); if (!p) return;
  const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY;
  if (ptr.size >= 2) {
    const [a, b] = [...ptr.values()], c = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }, d = Math.hypot(a.x - b.x, a.y - b.y) || 1;
    const wx = lastC.x / cam.z + cam.x, wy = lastC.y / cam.z + cam.y; cam.z *= d / lastD; clampCam(); cam.x = wx - c.x / cam.z; cam.y = wy - c.y / cam.z; clampCam(); lastC = c; lastD = d; p.moved = true; return;
  }
  if (!p.moved && Math.hypot(e.clientX - p.sx, e.clientY - p.sy) > 10) p.moved = true;
  if (p.moved) {
    if (boxMode || e.shiftKey) box = { x0: p.sx, y0: p.sy, x1: e.clientX, y1: e.clientY };
    else { cam.x -= dx / cam.z; cam.y -= dy / cam.z; clampCam(); }
  }
});
function endPtr(e) {
  const p = ptr.get(e.pointerId); if (!p) return; const wasOne = ptr.size === 1; ptr.delete(e.pointerId);
  if (ptr.size === 1) { const q = [...ptr.values()][0]; q.moved = true; }
  if (!wasOne) return;
  if (box) { boxSelect(); box = null; return; }
  if (!p.moved && e.type === 'pointerup') tap(p.x, p.y, p.btn);
}
cv.addEventListener('pointerup', endPtr); cv.addEventListener('pointercancel', endPtr);
cv.addEventListener('wheel', e => { e.preventDefault(); const wx = e.clientX / cam.z + cam.x, wy = e.clientY / cam.z + cam.y; cam.z *= e.deltaY < 0 ? 1.12 : .89; clampCam(); cam.x = wx - e.clientX / cam.z; cam.y = wy - e.clientY / cam.z; clampCam(); }, { passive: false });
const keys = {}; addEventListener('keydown', e => { keys[e.key.toLowerCase()] = 1; }); addEventListener('keyup', e => { keys[e.key.toLowerCase()] = 0; });
function keyPan(dt) { const s = 700 * dt / cam.z; if (keys.a || keys.arrowleft) cam.x -= s; if (keys.d || keys.arrowright) cam.x += s; if (keys.w || keys.arrowup) cam.y -= s; if (keys.s || keys.arrowdown) cam.y += s; clampCam(); }

function pick(wx, wy) {
  let best = null, bd = 1e9;
  for (const u of units) { if (u.hp <= 0 || (u.team === 1 && !isVis(u.x, u.y))) continue; const r = UD[u.type].r + 9, d = Math.hypot(u.x - wx, u.y - wy); if (d < r && d < bd) { bd = d; best = u; } }
  if (best) return best;
  for (const b of blds) { if (b.team === 1 && !explored[b.ty * W + b.tx]) continue; if (wx >= b.tx * T && wx <= (b.tx + b.w) * T && wy >= b.ty * T && wy <= (b.ty + b.h) * T) return b; }
  return null;
}
function setSel(a) { sel = a; hudTick(true); }
function tap(sx, sy, btn) {
  const w = toWorld(sx, sy);
  if (mode === 'place') { tryPlace(w); return; }
  const hit = pick(w.x, w.y);
  if (btn !== 2 && hit && hit.team === 0) { setSel([hit]); sfx('click'); return; }
  const su = sel.filter(e => e.kind === 'u');
  if (su.length) {
    if (hit && hit.team === 1) { for (const u of su) { u.tgt = hit; u.forced = true; u.path = null; u.amove = false; } fx.push({ k: 'mark', x: w.x, y: w.y, t: .5, d: .5, c: '#ff6a5a' }); sfx('click'); }
    else { orderMove(su, w.x, w.y, amoveNext); fx.push({ k: 'mark', x: w.x, y: w.y, t: .5, d: .5 }); sfx('click'); if (amoveNext) setAmove(false); }
  } else if (sel.length && sel[0].kind === 'b' && !hit) {
    const b = sel[0]; if (BD[b.type].train) { b.rally = [clamp(w.x / T | 0, 0, W - 1), clamp(w.y / T | 0, 0, H - 1)]; fx.push({ k: 'mark', x: w.x, y: w.y, t: .5, d: .5 }); toast('نقطة التجمع'); }
  } else if (!hit) setSel([]);
}
const SPIRAL = (() => { const a = []; for (let y = -5; y <= 5; y++) for (let x = -5; x <= 5; x++) a.push([x, y]); return a.sort((p, q) => p[0] ** 2 + p[1] ** 2 - q[0] ** 2 - q[1] ** 2); })();
function orderMove(us, wx, wy, am) {
  const tx = wx / T | 0, ty = wy / T | 0; let k = 0, n = 0;
  for (const u of us) {
    let g = null; while (k < SPIRAL.length) { const o = SPIRAL[k++], nx = clamp(tx + o[0] * 1, 0, W - 1), ny = clamp(ty + o[1] * 1, 0, H - 1); if (!blk[ny * W + nx]) { g = [nx, ny]; break; } }
    if (!g) g = [tx, ty]; u.tgt = null; u.forced = false; u.amove = am; u.dest = g; u.path = pathFor(u, g[0], g[1]); n++;
  }
}
function boxSelect() {
  const a = toWorld(Math.min(box.x0, box.x1), Math.min(box.y0, box.y1)), b = toWorld(Math.max(box.x0, box.x1), Math.max(box.y0, box.y1));
  const s = units.filter(u => u.team === 0 && u.x >= a.x && u.x <= b.x && u.y >= a.y && u.y <= b.y); setSel(s); if (s.length) { sfx('click'); toast(s.length + ' وحدة محددة'); }
}
function tryPlace(w) {
  const s = BD[placeType].s, tx = (w.x / T - s / 2 + .5) | 0, ty = (w.y / T - s / 2 + .5) | 0;
  if (G.gold[0] < BD[placeType].cost) { toast('الذهب غير كافٍ'); sfx('bad'); return; }
  if (!canPlace(0, placeType, tx, ty)) { toast('لا يمكن البناء هنا'); sfx('bad'); return; }
  G.gold[0] -= BD[placeType].cost; addB(placeType, 0, tx, ty, false); recalcBlk(); mode = ''; sfx('ok'); hudTick(true);
}

/* ---------- الواجهة ---------- */
function setAmove(v) { amoveNext = v; $('tAtk').classList.toggle('on', v); if (v) toast('اضغط الأرض لتتحرك وتهاجم'); }
function sigNow() { return sel.map(e => e.id).join(',') + '|' + mode + (sel.length ? '' : '|' + blds.filter(b => b.team === 0).length); }
function buildBtns() { if (!blds.some(b => b.team === 0 && b.type === 'hq')) return ''; return ['bar', 'fac', 'air', 'twr'].map(t => `<button class="act" data-build="${t}" data-cost="${BD[t].cost}"><i>${BD[t].ic}</i><b>${BD[t].n}</b><s>${BD[t].cost}</s></button>`).join(''); }
function buildPanel() {
  const p = $('panel'), su = sel.filter(e => e.kind === 'u'), sb = sel.filter(e => e.kind === 'b'); let h = '';
  if (mode === 'place') h = `<div class="info"><b>ضع ${BD[placeType].n}</b><span>اضغط أرضاً مكشوفة قرب المقر</span></div><button class="act" data-cancel><i>✖</i><b>إلغاء</b></button>`;
  else if (su.length) { const f = su.reduce((s, u) => s + u.hp / u.max, 0) / su.length * 100 | 0; h = `<div class="info"><b>${su.length} وحدة</b><span>الصحة ${f}٪</span></div><button class="act" data-stop><i>✋</i><b>إيقاف</b></button>`; }
  else if (sb.length) {
    const b = sb[0], d = BD[b.type]; h = `<div class="info"><b>${d.n}</b><span>${b.con < 1 ? 'قيد البناء' : 'اضغط الأرض لنقطة التجمع'}</span></div>`;
    if (d.train && b.con >= 1) for (const t of d.train) h += `<button class="act" data-train="${t}" data-bid="${b.id}" data-cost="${UD[t].cost}"><i>${UD[t].ic}</i><b>${UD[t].n}</b><s>${UD[t].cost}</s><em class="qn"></em></button>`;
    if (b.type === 'hq') h += buildBtns();
  } else h = buildBtns();
  p.innerHTML = h;
}
$('panel').addEventListener('click', e => {
  const t = e.target.closest('button'); if (!t) return; ac();
  if (t.dataset.build) { if (G.gold[0] < BD[t.dataset.build].cost) { toast('الذهب غير كافٍ'); sfx('bad'); return; } mode = 'place'; placeType = t.dataset.build; sel = []; sfx('click'); hudTick(true); }
  else if (t.dataset.train) { const b = blds.find(x => x.id == t.dataset.bid); if (b && queue(b, t.dataset.train)) sfx('click'); else { toast('الذهب غير كافٍ'); sfx('bad'); } }
  else if ('cancel' in t.dataset) { mode = ''; hudTick(true); }
  else if ('stop' in t.dataset) { for (const u of sel) { u.path = null; u.tgt = null; u.amove = false; } sfx('click'); }
});
function hudTick(force) {
  if (!G) return; const g = $('gold'); g.textContent = G.gold[0] | 0; $('inc').textContent = '+' + (G.inc[0] | 0) + '/ث';
  $('mines').textContent = mines.filter(m => m.owner === 0).length; const m = G.time / 60 | 0, s = G.time % 60 | 0; $('time').textContent = String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  const sg = sigNow(); if (force || sg !== lastSig) { lastSig = sg; buildPanel(); }
  document.querySelectorAll('#panel [data-cost]').forEach(el => el.classList.toggle('dis', G.gold[0] < +el.dataset.cost));
  const q = document.querySelector('#panel .qn'); if (q && sel[0] && sel[0].kind === 'b') q.textContent = sel[0].q.length || '';
}
$('tAll').onclick = () => { ac(); const s = units.filter(u => u.team === 0); setSel(s); toast(s.length + ' وحدة'); sfx('click'); };
$('tAtk').onclick = () => { ac(); setAmove(!amoveNext); };
$('tBox').onclick = () => { ac(); boxMode = !boxMode; $('tBox').classList.toggle('on', boxMode); toast(boxMode ? 'اسحب لرسم إطار التحديد' : 'السحب يحرك الخريطة'); };
$('tBld').onclick = () => { ac(); mode = ''; setSel([]); hudTick(true); };
$('bSound').onclick = () => { ac(); setMuted(!muted); };
$('bPause').onclick = () => { paused = true; $('pause').hidden = false; };
$('bResume').onclick = () => { paused = false; $('pause').hidden = true; };
$('bQuit').onclick = () => { $('pause').hidden = true; toMenu(); };
$('bAgain').onclick = () => { $('end').hidden = true; startGame(); };
$('bMenu').onclick = () => { $('end').hidden = true; toMenu(); };
function fullscreen() {
  const el = document.documentElement, f = el.requestFullscreen || el.webkitRequestFullscreen;
  if (f) { const r = f.call(el); if (r && r.catch) r.catch(() => {}); }
  try { screen.orientation.lock('landscape').catch(() => {}); } catch (e) {}
}
$('bFull').onclick = () => { if (document.fullscreenElement) document.exitFullscreen(); else fullscreen(); };
function mmGo(e) { const r = mm.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * W * T, y = (e.clientY - r.top) / r.height * H * T; cam.x = x - vw / cam.z / 2; cam.y = y - vh / cam.z / 2; clampCam(); }
let mmDown = false; mm.addEventListener('pointerdown', e => { mmDown = true; mm.setPointerCapture(e.pointerId); mmGo(e); }); mm.addEventListener('pointermove', e => { if (mmDown) mmGo(e); }); mm.addEventListener('pointerup', () => mmDown = false);

/* ---------- القائمة وبدء اللعبة ---------- */
function buildMenu() {
  $('armies').innerHTML = Object.entries(ARMIES).map(([k, a]) => `<button class="card${k === pickedArmy ? ' on' : ''}" data-a="${k}"><div class="flag" style="background:${a.c}"></div><b>${a.n}</b><span>${a.d}</span></button>`).join('');
  $('diffs').innerHTML = Object.entries(DIFF).map(([k, d]) => `<button class="pill${k === pickedDiff ? ' on' : ''}" data-d="${k}">${d.n}</button>`).join('');
}
$('armies').addEventListener('click', e => { const b = e.target.closest('[data-a]'); if (b) { pickedArmy = b.dataset.a; buildMenu(); ac(); sfx('click'); } });
$('diffs').addEventListener('click', e => { const b = e.target.closest('[data-d]'); if (b) { pickedDiff = b.dataset.d; buildMenu(); ac(); sfx('click'); } });
$('start').onclick = () => { ac(); fullscreen(); startGame(); };
function toMenu() { running = false; stopMusic(); $('hud').hidden = true; $('menu').hidden = false; }
function startGame() {
  const keysA = Object.keys(ARMIES).filter(k => k !== pickedArmy), enemy = pickOne(keysA);
  G = { army: [pickedArmy, enemy], diff: pickedDiff, gold: [800 + (ARMIES[pickedArmy].gold || 0), 500], inc: [2, 2], time: 0, over: false };
  units = []; blds = []; mines = []; fx = []; sel = []; mode = ''; amoveNext = false; uid = 0; ai.t = 0; ai.bt = 10; ai.wt = 0; ai.mt = 14; $('tAtk').classList.remove('on');
  genMap(Math.random() * 1e9 | 0); paintTerrain();
  explored = new Uint8Array(W * H); visible = new Uint8Array(W * H); fogCv = document.createElement('canvas'); fogCv.width = W; fogCv.height = H; fogCtx = fogCv.getContext('2d'); fogImg = fogCtx.createImageData(W, H);
  for (const [x, y] of MINES) mines.push({ tx: x, ty: y, owner: -1, prog: 0 });
  addB('hq', 0, BASE[0].x, BASE[0].y, true); addB('bar', 0, BASE[0].x + 5, BASE[0].y, true);
  addB('hq', 1, BASE[1].x, BASE[1].y, true); addB('bar', 1, BASE[1].x - 5, BASE[1].y, true); addB('fac', 1, BASE[1].x - 5, BASE[1].y + 4, true);
  recalcBlk();
  for (let t = 0; t < 2; t++) for (let i = 0; i < 4; i++) { const hq = blds.find(b => b.team === t && b.type === 'hq'), p = freeSpot(hq); addU('inf', t, p[0] + i * 6, p[1] + i * 4); }
  resize(); cam.z = Math.max(1, vw / (W * T)); cam.x = (BASE[0].x + 1.5) * T - vw / cam.z / 2; cam.y = (BASE[0].y + 1.5) * T - vh / cam.z / 2; clampCam();
  updFog(); $('menu').hidden = true; $('hud').hidden = false; $('end').hidden = true; $('pause').hidden = true; paused = false; running = true; lastSig = ''; hudTick(true);
  startMusic(); toast('دمّر مقر العدو واستولِ على مناجم الذهب'); setTimeout(() => toast('اضغط وحدة لتحديدها ثم اضغط الأرض'), 2200);
}

let last = 0;
function frame(ts) {
  requestAnimationFrame(frame); const dt = Math.min(.05, (ts - last) / 1000 || 0); last = ts;
  if (running && !paused) { keyPan(dt); update(dt); } render();
}
buildMenu(); resize(); requestAnimationFrame(frame);
})();
