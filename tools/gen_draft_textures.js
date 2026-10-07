'use strict';
/*
 * gen_draft_textures.js
 * ---------------------------------------------------------------------------
 * Gera as texturas PROVISORIAS ("draft") de "CtHlUhU iS cAlLiNg YoU".
 * Sao placeholders procedurais no estilo PS1 (baixa resolucao, paleta
 * limitada de 16-32 cores quantizada em 15 bits, dithering Bayer 4x4,
 * ruido por pixel, sem gradientes suaves "modernos"). Devem ser
 * SUBSTITUIDAS por arte feita a mao, mantendo exatamente os mesmos nomes
 * de arquivo (o codigo Godot referencia pelos nomes).
 *
 * As texturas marcadas como "tile" sao geradas com ruido periodico e
 * coordenadas modulares, entao repetem sem emenda nas duas direcoes.
 * O PNG e escrito por um encoder minimo proprio (assinatura + IHDR + IDAT
 * via zlib.deflateSync + IEND, com CRC32).
 *
 * Deterministico (PRNG mulberry32 com semente por textura) e usa apenas
 * modulos nativos do Node.js (sem npm). Para rodar, na raiz do projeto:
 *
 *     node tools/gen_draft_textures.js
 *
 * Saida: assets/textures/draft/
 * ---------------------------------------------------------------------------
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT_DIR = path.resolve(__dirname, '..', 'assets', 'textures', 'draft');
const TAU = Math.PI * 2;

// ============================================================== PRNG
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hashStr(s) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  return h;
}
class Rng {
  constructor(seed) { this.f = mulberry32(typeof seed === 'string' ? hashStr(seed) : seed >>> 0); }
  next() { return this.f(); }
  uni(a, b) { return a + (b - a) * this.f(); }
  bi() { return 2 * this.f() - 1; }
  int(a, b) { return a + Math.floor(this.f() * (b - a + 1)); }
  pick(a) { return a[Math.floor(this.f() * a.length)]; }
}

// ============================================================== PNG
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
function crc32(b) { let c = 0xFFFFFFFF; for (let i = 0; i < b.length; i++) c = CRC_TABLE[(c ^ b[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePNG(w, h, ch, px) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = ch === 4 ? 6 : 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = w * ch, raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (stride + 1)] = 0; for (let i = 0; i < stride; i++) raw[y * (stride + 1) + 1 + i] = px[y * stride + i]; }
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', ihdr), pngChunk('IDAT', zlib.deflateSync(raw, { level: 9 })), pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

// ============================================================== utilidades
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const clamp01 = (v) => clamp(v, 0, 1);
const smoothstep = (e0, e1, x) => { const t = clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const lerpC = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const mulC = (a, f) => [a[0] * f, a[1] * f, a[2] * f];
const addC = (a, v) => [a[0] + v, a[1] + v, a[2] + v];
const lum = (c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
const wrapD = (d, p) => d - p * Math.round(d / p);

class Img {
  constructor(w, h, alpha = false) { this.w = w; this.h = h; this.rgb = new Float64Array(w * h * 3); this.a = alpha ? new Float64Array(w * h) : null; }
  idx(x, y) { const w = this.w, h = this.h; x = ((Math.round(x) % w) + w) % w; y = ((Math.round(y) % h) + h) % h; return y * w + x; }
  get(x, y) { const k = this.idx(x, y) * 3; return [this.rgb[k], this.rgb[k + 1], this.rgb[k + 2]]; }
  set(x, y, c) { const k = this.idx(x, y) * 3; this.rgb[k] = c[0]; this.rgb[k + 1] = c[1]; this.rgb[k + 2] = c[2]; }
  blend(x, y, c, t) { this.set(x, y, lerpC(this.get(x, y), c, t)); }
  mul(x, y, f) { this.set(x, y, mulC(this.get(x, y), f)); }
  meanLum() { let s = 0; for (let i = 0; i < this.w * this.h; i++) s += lum([this.rgb[i * 3], this.rgb[i * 3 + 1], this.rgb[i * 3 + 2]]); return s / (this.w * this.h); }
}
// linha de Bresenham (com wrap, via Img.idx)
function line(x0, y0, x1, y1, fn) {
  x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
  const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let err = dx + dy, k = 0;
  for (;;) {
    fn(x0, y0, k++);
    if (x0 === x1 && y0 === y1) break;
    const e2 = 2 * err;
    if (e2 >= dy) { err += dy; x0 += sx; }
    if (e2 <= dx) { err += dx; y0 += sy; }
  }
}

// ============================================================== ruido periodico
function noiseSampler(seed, px, py) {
  const rng = new Rng(seed), g = new Float64Array(px * py);
  for (let i = 0; i < g.length; i++) g[i] = rng.next();
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), fx = x - xi, fy = y - yi;
    const x0 = ((xi % px) + px) % px, y0 = ((yi % py) + py) % py, x1 = (x0 + 1) % px, y1 = (y0 + 1) % py;
    const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
    const a = g[y0 * px + x0], b = g[y0 * px + x1], c = g[y1 * px + x0], d = g[y1 * px + x1];
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v;
  };
}
// fBm periodico em W x H, normalizado para [0,1]
function fbm(seed, W, H, cx, cy, oct = 4, pers = 0.5) {
  const out = new Float64Array(W * H); let amp = 1;
  for (let o = 0; o < oct; o++) {
    const px = Math.min(W, cx << o), py = Math.min(H, cy << o), ns = noiseSampler(seed + ':' + o, px, py);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) out[y * W + x] += amp * ns(x * px / W, y * py / H);
    amp *= pers;
  }
  let mn = Infinity, mx = -Infinity;
  for (const v of out) { if (v < mn) mn = v; if (v > mx) mx = v; }
  for (let i = 0; i < out.length; i++) out[i] = (out[i] - mn) / (mx - mn || 1);
  return out;
}
// Worley F1 periodico, normalizado para [0,1]
function worley(seed, W, H, cells) {
  const rng = new Rng(seed), pts = [];
  for (let j = 0; j < cells; j++) for (let i = 0; i < cells; i++) pts.push([(i + rng.next()) * W / cells, (j + rng.next()) * H / cells]);
  const out = new Float64Array(W * H); let mx = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let best = Infinity;
    for (const [px, py] of pts) { const d = Math.hypot(wrapD(x - px, W), wrapD(y - py, H)); if (d < best) best = d; }
    out[y * W + x] = best; if (best > mx) mx = best;
  }
  for (let i = 0; i < out.length; i++) out[i] /= mx;
  return out;
}

// ============================================================== quantizacao PS1
const BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const to15 = (v) => { const q = clamp(Math.round(v / 255 * 31), 0, 31); return (q << 3) | (q >> 2); };
function nearest(pal, r, g, b) {
  let best = 0, bd = Infinity;
  for (let k = 0; k < pal.length; k++) {
    const c = pal[k], dr = r - c[0], dg = g - c[1], db = b - c[2], d = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
    if (d < bd) { bd = d; best = k; }
  }
  return best;
}
// k-means deterministico -> paleta em 15 bits (sem repetidas)
function kmeansPalette(img, ids, k) {
  const L = (p) => lum([img.rgb[p * 3], img.rgb[p * 3 + 1], img.rgb[p * 3 + 2]]);
  const sorted = ids.slice().sort((a, b) => L(a) - L(b));
  let cent = [];
  for (let j = 0; j < k; j++) { const p = sorted[Math.floor((j + 0.5) / k * sorted.length)]; cent.push([img.rgb[p * 3], img.rgb[p * 3 + 1], img.rgb[p * 3 + 2]]); }
  for (let it = 0; it < 16; it++) {
    const sum = cent.map(() => [0, 0, 0, 0]);
    for (const p of ids) { const r = img.rgb[p * 3], g = img.rgb[p * 3 + 1], b = img.rgb[p * 3 + 2], j = nearest(cent, r, g, b); sum[j][0] += r; sum[j][1] += g; sum[j][2] += b; sum[j][3]++; }
    cent = sum.map((s, j) => (s[3] ? [s[0] / s[3], s[1] / s[3], s[2] / s[3]] : cent[j]));
  }
  const pal = [], seen = new Set();
  for (const c of cent) { const q = c.map(to15), key = q.join(','); if (!seen.has(key)) { seen.add(key); pal.push(q); } }
  return pal;
}
// paleta limitada (aumenta k ate sobrarem nColors cores distintas em 15 bits) + dither Bayer
function quantize(img, nColors, dither = 7) {
  const { w, h } = img, n = w * h, ids = [];
  for (let p = 0; p < n; p++) if (!img.a || img.a[p] > 0.02) ids.push(p);
  if (!ids.length) ids.push(0);
  let pal = kmeansPalette(img, ids, nColors);
  for (let k = nColors + 2; pal.length < nColors && k <= nColors * 4; k += 2) {
    const p2 = kmeansPalette(img, ids, k);
    if (p2.length > pal.length && p2.length <= 32) pal = p2;
  }
  const ch = img.a ? 4 : 3, out = new Uint8Array(n * ch);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = y * w + x, d = (BAYER4[(y & 3) * 4 + (x & 3)] / 16 - 0.469) * dither;
    const c = pal[nearest(pal, img.rgb[p * 3] + d, img.rgb[p * 3 + 1] + d, img.rgb[p * 3 + 2] + d)];
    out[p * ch] = c[0]; out[p * ch + 1] = c[1]; out[p * ch + 2] = c[2];
    if (img.a) out[p * ch + 3] = Math.round(clamp01(img.a[p]) * 15) * 17;
  }
  return { data: out, ch, pal };
}

// ============================================================== TEXTURAS
function texWallpaper() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('wallpaper_boston');
  const stain = fbm('wp_stain', W, H, 2, 2, 4, 0.55), wear = fbm('wp_wear', W, H, 4, 4, 3, 0.6), streak = fbm('wp_streak', W, H, 8, 1, 3, 0.5);
  const MOTIF = [ // motivo damasco desenhado "a mao" (# = traco, o = preenchimento)
    '.......#.......',
    '......###......',
    '.....#.#.#.....',
    '....#..#..#....',
    '...#.#####.#...',
    '..#..#.o.#..#..',
    '.#..#.ooo.#..#.',
    '#..#.ooooo.#..#',
    '.#..#.ooo.#..#.',
    '..#..#.o.#..#..',
    '...#.#####.#...',
    '....#..#..#....',
    '.....#.#.#.....',
    '......###......',
    '.......#.......',
    '.......#.......',
  ];
  const panel = [124, 138, 146], band = [100, 114, 126], pin = [152, 160, 162], lineC = [74, 86, 102], fillC = [150, 160, 164];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, lx = x % 32, p = Math.floor(x / 32);
    let c;
    if (lx < 20) {
      c = panel;
      const gy = (((y - (p ? 16 : 0)) % 32) + 32) % 32, mx = lx - 3, my = gy - 8;
      const vis = 1 - 0.7 * smoothstep(0.6, 0.85, wear[i]);
      if (mx >= 0 && mx < 15 && my >= 0 && my < 16) {
        const chr = MOTIF[my][mx];
        if (chr === '#') c = lerpC(c, lineC, 0.85 * vis); else if (chr === 'o') c = lerpC(c, fillC, 0.7 * vis);
      }
      // pequeno losango entre os motivos
      const dy = Math.min(gy, 32 - gy), dd = Math.abs(lx - 10) + dy;
      if (dd <= 1) c = lerpC(c, lineC, 0.7 * vis);
    } else {
      c = band;
      if (lx === 20 || lx === 31) c = pin; else if (lx === 25 || lx === 26) c = lerpC(band, lineC, 0.5);
    }
    c = lerpC(c, [168, 142, 104], 0.28 + 0.2 * stain[i]);       // tom sepia
    c = lerpC(c, [190, 180, 160], 0.15 * wear[i]);               // desbotado
    c = mulC(c, 0.94 + 0.1 * streak[i]);                         // escorridos verticais
    c = lerpC(c, [110, 88, 60], 0.35 * smoothstep(0.68, 0.8, stain[i]));
    if (stain[i] > 0.66 && stain[i] < 0.69) c = mulC(c, 0.9);    // borda da mancha d'agua
    img.set(x, y, addC(c, (rng.next() - 0.5) * 10));
  }
  return img;
}

function texWoodFloor() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('wood_floor');
  const warp = fbm('wf_warp', W, H, 2, 8, 3, 0.5), fine = fbm('wf_fine', W, H, 16, 32, 2, 0.5), wearN = fbm('wf_wear', W, H, 2, 2, 3, 0.5);
  const planks = [0, 1, 2, 3].map(() => ({
    tone: rng.uni(0.85, 1.12), hue: rng.uni(-8, 8), joint: rng.int(0, 63), half: rng.next() < 0.5,
    off: rng.uni(0, 10), off2: rng.uni(0, 10), knot: rng.next() < 0.6 ? [rng.int(4, 59), rng.uni(4, 11)] : null,
  }));
  const base = [128, 84, 48], dark = [84, 52, 28], light = [150, 102, 62], gap = [28, 18, 12];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, P = planks[Math.floor(y / 16)], ly = y % 16;
    const rx = (((x - P.joint) % 64) + 64) % 64, seg = P.half && rx >= 32 ? 1 : 0, isJoint = rx === 0 || (P.half && rx === 32);
    let gy = ly + (seg ? P.off2 : P.off) + warp[i] * 6 + fine[i] * 0.6, knotCore = false;
    if (P.knot) {
      const dx = wrapD(x - P.knot[0], 64), dy = ly - P.knot[1], d2 = dx * dx / 4 + dy * dy;
      gy += (5 / (1 + d2 * 0.5)) * (dy < 0 ? -1 : 1); if (d2 < 1.5) knotCore = true;
    }
    const ring = gy / 2.7 - Math.floor(gy / 2.7);
    let c = ring < 0.28 ? dark : ring < 0.4 ? lerpC(dark, base, 0.5) : base;
    c = lerpC(c, light, 0.35 * fine[i]);
    c = mulC(c, P.tone); c = [c[0] + P.hue, c[1] + P.hue * 0.5, c[2]];
    c = lerpC(c, [160, 120, 80], 0.15 * smoothstep(0.5, 0.9, wearN[i]));
    if (knotCore) c = [60, 36, 20];
    if (ly === 1) c = mulC(c, 1.1); if (ly === 15) c = mulC(c, 0.8);
    if (ly === 0 || isJoint) c = gap;
    if ((rx === 2 || rx === 62 || (P.half && (rx === 30 || rx === 34))) && (ly === 4 || ly === 12)) c = [40, 34, 30];
    img.set(x, y, addC(c, (rng.next() - 0.5) * 10));
  }
  return img;
}

function texWoodDark() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('wood_dark');
  const warp = fbm('wd_warp', W, H, 2, 4, 4, 0.55), fine = fbm('wd_fine', W, H, 32, 8, 2, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    const v = Math.sin(TAU * (x * 9 / 64) + warp[i] * 6 + fine[i] * 2.2), t = Math.pow(0.5 + 0.5 * v, 3);
    let c = lerpC([58, 34, 22], [36, 20, 13], t);
    c = lerpC(c, [86, 52, 33], 0.4 * smoothstep(0.6, 0.95, fine[i]));
    img.set(x, y, addC(c, (rng.next() - 0.5) * 6));
  }
  for (let k = 0; k < 45; k++) { // poros
    const x = rng.int(0, 63), y = rng.int(0, 63), l = rng.int(2, 4);
    for (let j = 0; j < l; j++) img.mul(x, y + j, 0.7);
  }
  return img;
}

function texPlaster() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('plaster');
  const blot = fbm('pl_blot', W, H, 4, 4, 5, 0.55), stain = fbm('pl_stain', W, H, 2, 2, 4, 0.6);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, s = stain[i];
    let c = mulC([198, 194, 182], 0.92 + 0.14 * blot[i]);
    c = lerpC(c, [150, 150, 146], 0.25 * smoothstep(0.3, 0.0, blot[i]));
    c = lerpC(c, [176, 160, 120], 0.5 * smoothstep(0.6, 0.75, s));
    if (s > 0.6 && s < 0.635) c = lerpC(c, [140, 124, 90], 0.5);
    img.set(x, y, addC(c, (rng.next() - 0.5) * 9));
  }
  for (let k = 0; k < 3; k++) { // rachaduras (random walk com wrap)
    let x = rng.uni(0, 64), y = rng.uni(0, 64), a = rng.uni(0, TAU);
    const len = rng.int(25, 45);
    for (let s = 0; s < len; s++) {
      img.blend(x, y, [124, 118, 108], 0.6);
      a += rng.bi() * 0.5; x += Math.cos(a); y += Math.sin(a);
      if (rng.next() < 0.04) { let bx = x, by = y, ba = a + rng.bi() * 1.5; for (let j = 0; j < 8; j++) { img.blend(bx, by, [140, 134, 124], 0.45); ba += rng.bi() * 0.5; bx += Math.cos(ba); by += Math.sin(ba); } }
    }
  }
  for (let k = 0; k < 60; k++) img.mul(rng.int(0, 63), rng.int(0, 63), rng.next() < 0.7 ? 0.85 : 1.08);
  return img;
}

function texBrick() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('brick_red');
  const surf = fbm('br_surf', W, H, 8, 8, 3, 0.5), big = fbm('br_big', W, H, 2, 2, 3, 0.5);
  const cols = [[150, 62, 44], [136, 54, 40], [160, 74, 52], [124, 50, 38], [146, 68, 48], [132, 60, 46]];
  const bricks = [];
  for (let r = 0; r < 8; r++) { bricks.push([]); for (let b = 0; b < 4; b++) bricks[r].push({ col: rng.pick(cols), br: rng.uni(0.88, 1.1), chip: rng.next() < 0.3 ? rng.int(0, 3) : -1 }); }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, r = Math.floor(y / 8), off = (r % 2) * 8, xx = (x + off) % 64, bx = Math.floor(xx / 16), lx = xx % 16, ly = y % 8;
    let c;
    if (lx === 15 || ly === 7) {
      c = mulC([148, 138, 122], 0.85 + 0.25 * surf[i]);
      if (ly === 7 && lx !== 15) c = mulC(c, 0.85);
    } else {
      const B = bricks[r][bx];
      c = mulC(B.col, B.br * (0.85 + 0.3 * surf[i]));
      if (ly === 0) c = mulC(c, 1.12); if (lx === 0) c = mulC(c, 1.06); if (ly === 6) c = mulC(c, 0.82); if (lx === 14) c = mulC(c, 0.88);
      if (rng.next() < 0.06) c = mulC(c, 0.7); else if (rng.next() < 0.03) c = lerpC(c, [190, 120, 90], 0.4);
      const cx = B.chip === 0 || B.chip === 2 ? lx : 14 - lx, cy = B.chip < 2 ? ly : 6 - ly;
      if (B.chip >= 0 && cx + cy < 2) c = mulC([148, 138, 122], 0.8);
    }
    c = mulC(c, 0.9 + 0.15 * big[i]);
    img.set(x, y, addC(c, (rng.next() - 0.5) * 8));
  }
  return img;
}

function texScales(targetLum) {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('scales_green'), R = 10;
  const big = fbm('sc_big', W, H, 2, 2, 3, 0.5);
  const tint = []; for (let k = 0; k < 32; k++) tint.push([rng.uni(0.85, 1.12), rng.uni(-10, 14)]);
  const dark = [28, 40, 18], mid = [80, 108, 42], light = [140, 158, 72];
  const findIn = (x, y, ry) => {
    const cy = ry * 8 - 2, off = (((ry % 2) + 2) % 2) * 8; let best = null;
    for (let k = -1; k <= 1; k++) {
      const c = Math.round((x - off - 8) / 16) + k, cx = c * 16 + off + 8, dx = x - cx, dy = y - cy, d = Math.hypot(dx, dy);
      if (!best || d < best.d) best = { dx, dy, d, id: (((ry % 8) + 8) % 8) * 4 + (((c % 4) + 4) % 4) };
    }
    return best;
  };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, ry0 = Math.floor(y / 8);
    let f = null, ryF = 0;
    for (let ry = ry0 - 2; ry <= ry0 + 2 && !f; ry++) { const b = findIn(x, y, ry); if (b.d < R) { f = b; ryF = ry; } } // fileira de cima por cima
    let c = dark;
    if (f) {
      const u = f.d / R;
      if (u > 0.86) c = dark;
      else {
        const sh = 0.78 - 0.35 * (f.dy / R) - 0.15 * (f.dx / R) - 0.25 * u * u;
        c = lerpC(mid, light, clamp01(sh));
        if (Math.abs(f.dx) < 1 && f.dy > -3) c = mulC(c, 1.08); // quilha
        const [tm, th] = tint[f.id]; c = [c[0] * tm + th * 0.6, c[1] * tm + th * 0.3, c[2] * tm - th * 0.2];
        const up = findIn(x, y, ryF - 1); if (up.d - R < 1.6) c = mulC(c, 0.72); // sombra da escama de cima
      }
    }
    c = mulC(c, 0.9 + 0.15 * big[i]);
    if (rng.next() < 0.02) c = lerpC(c, [176, 186, 96], 0.6); // brilho de muco
    img.set(x, y, addC(c, (rng.next() - 0.5) * 8));
  }
  const f = targetLum / img.meanLum();
  for (let k = 0; k < img.rgb.length; k++) img.rgb[k] *= f;
  return img;
}

function texCardboard() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('cardboard');
  const fib = fbm('cb_fib', W, H, 4, 16, 3, 0.5), blot = fbm('cb_blot', W, H, 2, 2, 4, 0.55);
  const eT = noiseSampler('cb_et', 8, 1), eB = noiseSampler('cb_eb', 8, 1);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = mulC([170, 134, 90], (0.9 + 0.12 * fib[i]) * (1 + 0.035 * Math.sin(TAU * x * 8 / 64)));
    c = lerpC(c, [138, 102, 62], 0.5 * smoothstep(0.68, 0.85, blot[i]));
    const top = 25 + Math.round(eT(x * 8 / 64, 0) * 2), bot = 38 + Math.round(eB(x * 8 / 64, 0) * 2);
    if (y >= top && y <= bot) {
      c = lerpC(c, [198, 166, 104], 0.62);
      if (y === top + 2) c = mulC(c, 1.12);
      if (y === top || y === bot) c = mulC(c, 0.85);
    }
    img.set(x, y, addC(c, (rng.next() - 0.5) * 9));
  }
  for (let k = 0; k < 5; k++) { // rugas na fita
    const x0 = rng.int(0, 63), y0 = rng.int(29, 34), l = rng.int(3, 6), s = rng.next() < 0.5 ? 1 : -1;
    for (let j = 0; j < l; j++) { img.mul(x0 + j, y0 + s * Math.floor(j / 2), 1.12); img.mul(x0 + j, y0 + 1 + s * Math.floor(j / 2), 0.9); }
  }
  for (let k = 0; k < 6; k++) { // arranhoes
    const x0 = rng.int(0, 63), y0 = rng.int(0, 63), l = rng.int(4, 10), a = rng.uni(0, TAU);
    line(x0, y0, x0 + Math.cos(a) * l, y0 + Math.sin(a) * l, (x, y) => img.mul(x, y, 1.1));
  }
  return img;
}

function texPaperAged() {
  const W = 128, H = 128, img = new Img(W, H), rng = new Rng('paper_aged');
  const blot = fbm('pa_blot', W, H, 4, 4, 5, 0.55), fib = fbm('pa_fib', W, H, 32, 64, 2, 0.5), edge = fbm('pa_edge', W, H, 8, 8, 3, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = addC(mulC([222, 204, 160], 0.94 + 0.08 * blot[i]), (fib[i] - 0.5) * 8);
    const d = Math.min(x, y, W - 1 - x, H - 1 - y) + (edge[i] - 0.5) * 8;
    c = lerpC(c, [170, 140, 92], 0.6 * smoothstep(14, 0, d));
    if (d < 1.5) c = lerpC(c, [120, 90, 56], 0.5);
    if (x === 64) c = mulC(c, 1.05); if (x === 65) c = mulC(c, 0.93); // dobras
    if (y === 60) c = mulC(c, 1.05); if (y === 61) c = mulC(c, 0.93);
    img.set(x, y, addC(c, (rng.next() - 0.5) * 6));
  }
  for (let k = 0; k < 28; k++) { // foxing
    const cx = rng.uni(4, 124), cy = rng.uni(4, 124), r = rng.uni(0.7, 2.8), a = rng.uni(0.3, 0.7);
    for (let y = Math.floor(cy - r * 1.5); y <= cy + r * 1.5; y++) for (let x = Math.floor(cx - r * 1.5); x <= cx + r * 1.5; x++) {
      const dd = Math.hypot(x - cx, y - cy); if (dd < r * 1.5 && x >= 0 && y >= 0 && x < W && y < H) img.blend(x, y, [156, 108, 62], a * clamp01(1.2 - dd / (r * 1.5)));
    }
  }
  const rcx = 84, rcy = 92, rr = 19; // marca de xicara
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dd = Math.hypot((x - rcx) * 1.1, y - rcy);
    if (Math.abs(dd - rr) < 1.2) img.blend(x, y, [150, 110, 70], 0.35 * (0.6 + 0.4 * edge[y * W + x]));
    else if (dd < rr) img.blend(x, y, [200, 170, 120], 0.12);
  }
  return img;
}

function texPaperDiary() {
  const W = 128, H = 128, img = new Img(W, H), rng = new Rng('paper_diary');
  const blot = fbm('pd_blot', W, H, 4, 4, 4, 0.55), wear = fbm('pd_wear', W, H, 8, 8, 3, 0.5), edge = fbm('pd_edge', W, H, 8, 8, 3, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = mulC([232, 222, 194], 0.95 + 0.07 * blot[i]);
    if (y >= 22 && (y - 22) % 8 === 0) c = lerpC(c, [136, 156, 176], wear[i] > 0.7 ? 0.25 : 0.5); // pautas
    if (x === 18) c = lerpC(c, [200, 92, 88], 0.45); else if (x === 19) c = lerpC(c, [200, 92, 88], 0.15); // margem
    const d = Math.min(x, y, W - 1 - x, H - 1 - y) + (edge[i] - 0.5) * 6;
    c = lerpC(c, [200, 180, 140], 0.4 * smoothstep(8, 0, d));
    img.set(x, y, addC(c, (rng.next() - 0.5) * 6));
  }
  for (let k = 0; k < 10; k++) {
    const cx = rng.uni(4, 124), cy = rng.uni(4, 124), r = rng.uni(0.6, 2);
    for (let y = Math.floor(cy - 3); y <= cy + 3; y++) for (let x = Math.floor(cx - 3); x <= cx + 3; x++) {
      const dd = Math.hypot(x - cx, y - cy); if (dd < r * 1.5 && x >= 0 && y >= 0 && x < W && y < H) img.blend(x, y, [170, 128, 80], 0.35 * (1 - dd / (r * 1.5)));
    }
  }
  return img;
}

function texClay() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('clay');
  const blot = fbm('cl_blot', W, H, 4, 4, 4, 0.55), fine = fbm('cl_fine', W, H, 16, 16, 2, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    img.set(x, y, addC(mulC([178, 98, 62], 0.88 + 0.2 * blot[i]), (fine[i] - 0.5) * 12 + (rng.next() - 0.5) * 7));
  }
  for (let k = 0; k < 6; k++) { // marcas de ferramenta
    const cx = rng.uni(0, 64), cy = rng.uni(0, 64), r = rng.uni(4, 9), a0 = rng.uni(0, TAU);
    for (let s = 0; s < 14; s++) { const a = a0 + s * 0.09; img.blend(cx + Math.cos(a) * r, cy + Math.sin(a) * r, [196, 120, 82], 0.3); }
  }
  for (let k = 0; k < 70; k++) img.blend(rng.int(0, 63), rng.int(0, 63), rng.next() < 0.5 ? [206, 150, 112] : [120, 62, 40], 0.6);
  for (let k = 0; k < 2; k++) {
    let x = rng.uni(0, 64), y = rng.uni(0, 64), a = rng.uni(0, TAU);
    for (let s = 0; s < 14; s++) { img.mul(x, y, 0.8); a += rng.bi() * 0.6; x += Math.cos(a); y += Math.sin(a); }
  }
  return img;
}

function blurGauss(a, W, H, sigma) {
  const r = Math.ceil(sigma * 3), k = []; let s = 0;
  for (let i = -r; i <= r; i++) { const v = Math.exp(-i * i / (2 * sigma * sigma)); k.push(v); s += v; }
  for (let i = 0; i < k.length; i++) k[i] /= s;
  const t = new Float64Array(W * H), o = new Float64Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let v = 0; for (let i = -r; i <= r; i++) v += k[i + r] * a[y * W + clamp(x + i, 0, W - 1)]; t[y * W + x] = v; }
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let v = 0; for (let i = -r; i <= r; i++) v += k[i + r] * t[clamp(y + i, 0, H - 1) * W + x]; o[y * W + x] = v; }
  return o;
}
function texBasRelief() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('bas_relief'), Hm = new Float64Array(W * H);
  const put = (x, y, v) => { if (x >= 0 && x < W && y >= 0 && y < H) Hm[y * W + x] = Math.max(Hm[y * W + x], v); };
  const seg = (x0, y0, x1, y1, r, v) => {
    for (let y = Math.floor(Math.min(y0, y1) - r); y <= Math.max(y0, y1) + r; y++) for (let x = Math.floor(Math.min(x0, x1) - r); x <= Math.max(x0, x1) + r; x++) {
      const dx = x1 - x0, dy = y1 - y0, L2 = dx * dx + dy * dy || 1, t = clamp01(((x - x0) * dx + (y - y0) * dy) / L2);
      const d = Math.hypot(x - (x0 + dx * t), y - (y0 + dy * t)); if (d < r) put(x, y, v * (1 - (d / r) * (d / r) * 0.5));
    }
  };
  const ell = (cx, cy, rx, ry, v) => {
    for (let y = Math.floor(cy - ry); y <= cy + ry; y++) for (let x = Math.floor(cx - rx); x <= cx + rx; x++) {
      const u = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2; if (u < 1) put(x, y, v * Math.sqrt(1 - u));
    }
  };
  const tri = (a, b, c, v) => {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const s = (p, q) => (q[0] - p[0]) * (y - p[1]) - (q[1] - p[1]) * (x - p[0]);
      const s1 = s(a, b), s2 = s(b, c), s3 = s(c, a);
      if ((s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0)) put(x, y, v);
    }
  };
  // arquitetura "ciclopica" ao fundo: linhas em angulos estranhos
  seg(7, 58, 10, 9, 1.6, 0.32); seg(10, 9, 22, 6, 1.4, 0.32); seg(57, 58, 53, 11, 1.6, 0.32); seg(53, 11, 42, 8, 1.4, 0.32);
  seg(13, 51, 51, 46, 1.2, 0.28); seg(12, 31, 20, 27, 1.0, 0.24); seg(44, 23, 55, 29, 1.0, 0.24); seg(24, 7, 41, 5, 1.0, 0.22);
  seg(15, 40, 13, 52, 1.0, 0.22); seg(50, 36, 52, 50, 1.0, 0.22);
  // asas (atras da figura)
  tri([25, 28], [9, 13], [12, 33], 0.34); tri([39, 28], [56, 15], [53, 34], 0.34);
  seg(25, 28, 9, 13, 1.1, 0.42); seg(25, 28, 8, 22, 0.9, 0.4); seg(25, 28, 12, 33, 0.9, 0.4);
  seg(39, 28, 56, 15, 1.1, 0.42); seg(39, 28, 57, 24, 0.9, 0.4); seg(39, 28, 53, 34, 0.9, 0.4);
  // corpo curvado e cabeca polposa
  ell(32, 42, 9, 11, 0.55); ell(32, 24, 7.5, 8.5, 0.85); ell(29, 20, 3.2, 3, 0.92); ell(35.5, 21, 3, 3.2, 0.9);
  // "tentaculos" saindo de baixo da cabeca
  for (let k = 0; k < 6; k++) {
    let x = 27 + k * 2, y = 29; const ph = rng.uni(0, TAU), sway = rng.uni(1.2, 2.4);
    for (let s = 0; s < 8; s++) { const nx = x + Math.sin(s * 0.8 + ph) * sway * 0.6, ny = y + 2; seg(x, y, nx, ny, 1.25 - s * 0.06, 0.72 - s * 0.03); x = nx; y = ny; }
  }
  for (const [ex, ey] of [[29.5, 23], [34.5, 23]]) for (let y = 21; y <= 25; y++) for (let x = 27; x <= 37; x++) {
    const d = Math.hypot(x - ex, y - ey); if (d < 1.4) Hm[y * W + x] -= 0.12;
  }
  // erosao, depois desfoque proposital (so insinua, nunca revela)
  const er = fbm('br_eros', W, H, 4, 4, 4, 0.55);
  for (let i = 0; i < W * H; i++) Hm[i] += (er[i] - 0.5) * 0.24 + (rng.next() < 0.03 ? -0.15 : 0);
  let Hb = blurGauss(Hm, W, H, 1.25);
  // moldura em relevo
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const e = Math.min(x, y, W - 1 - x, H - 1 - y);
    if (e < 4) Hb[y * W + x] = 0.95 - (e === 3 ? 0.25 : 0) + (er[y * W + x] - 0.5) * 0.1;
  }
  Hb = blurGauss(Hb, W, H, 0.6);
  const AO = blurGauss(Hb, W, H, 3);
  const Lx = -0.55, Ly = -0.65, Lz = 0.52;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, h = (xx, yy) => Hb[clamp(yy, 0, H - 1) * W + clamp(xx, 0, W - 1)];
    const gx = (h(x + 1, y) - h(x - 1, y)) * 4, gy = (h(x, y + 1) - h(x, y - 1)) * 4, nl = Math.hypot(gx, gy, 1);
    const shade = (-gx * Lx - gy * Ly + Lz) / nl;
    let c = mulC([166, 124, 92], 0.8 + 0.5 * (shade - Lz) + 0.08 * Hb[i]);
    c = mulC(c, 1 - 0.25 * clamp01((AO[i] - Hb[i]) * 2));
    img.set(x, y, addC(c, (rng.next() - 0.5) * 8));
  }
  return img;
}

function stoneBase() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('stone_green');
  const mott = fbm('sg_mott', W, H, 4, 4, 5, 0.55), cell = worley('sg_cell', W, H, 8), moss = fbm('sg_moss', W, H, 2, 2, 4, 0.6);
  const seamN = noiseSampler('sg_seam', 8, 1), seamN2 = noiseSampler('sg_seam2', 8, 1);
  const joints = (y) => {
    const s1 = 21 + seamN(0, 0) * 3; // aproximacao para escolher a fileira
    if (y >= s1 && y < 53) { const t = y - 21; return [10 + 0.4 * t, 42 - 0.3 * t]; }
    const t = (((y - 53) % 64) + 64) % 64; return [26 + 0.5 * t, 58 - 0.2 * t];
  };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = mulC([36, 46, 38], 0.75 + 0.5 * mott[i]);
    c = mulC(c, 0.85 + 0.15 * smoothstep(0, 0.35, cell[i]));
    c = lerpC(c, [44, 62, 36], smoothstep(0.6, 0.8, moss[i]));
    const sy1 = 21 + seamN(x * 8 / 64, 0) * 3, sy2 = 53 + seamN2(x * 8 / 64, 0) * 3;
    for (const sy of [sy1, sy2]) { const d = y - sy; if (Math.abs(d) < 0.7) c = [14, 18, 15]; else if (d >= 0.7 && d < 1.7) c = mulC(c, 1.2); }
    for (const jx of joints(y)) { const d = wrapD(x - jx, 64); if (Math.abs(d) < 0.6) c = [14, 18, 15]; else if (d >= 0.6 && d < 1.6) c = mulC(c, 1.18); }
    img.set(x, y, addC(c, (rng.next() - 0.5) * 7));
  }
  for (let k = 0; k < 9; k++) { // escorridos de limo
    const x0 = rng.int(0, 63), y0 = rng.int(0, 63), len = rng.int(18, 50), w = rng.next() < 0.4 ? 2 : 1, ph = rng.uni(0, TAU);
    for (let s = 0; s < len; s++) {
      const x = x0 + Math.round(Math.sin(s * 0.3 + ph) * 0.8), y = y0 + s, a = 0.75 * Math.pow(1 - s / len, 0.6);
      for (let j = 0; j < w; j++) img.blend(x + j, y, [62, 96, 52], a);
      if (rng.next() < 0.1) img.blend(x, y, [112, 150, 90], 0.7);
    }
    img.blend(x0, y0 + len, [80, 118, 66], 0.7); img.blend(x0 + 1, y0 + len, [70, 104, 58], 0.5);
  }
  return img;
}
function texStoneCarved() {
  const img = stoneBase(), rng = new Rng('stone_green_carved'), lat = [3, 8, 13];
  for (let gy = 0; gy < 4; gy++) for (let gx = 0; gx < 4; gx++) {
    if (rng.next() < 0.3) continue;
    const ox = gx * 16 + (gy % 2) * 8, oy = gy * 16, pts = [], groove = new Set();
    for (const a of lat) for (const b of lat) pts.push([ox + a, oy + b]);
    const key = (x, y) => ((((y % 64) + 64) % 64) * 64 + (((x % 64) + 64) % 64));
    const ns = rng.int(2, 4);
    for (let s = 0; s < ns; s++) {
      const p = rng.pick(pts); let q = rng.pick(pts); if (q === p) q = pts[(pts.indexOf(p) + 4) % 9];
      line(p[0], p[1], q[0], q[1], (x, y) => groove.add(key(x, y)));
    }
    if (rng.next() < 0.35) { const cx = ox + 8, cy = oy + rng.pick([5, 8, 11]); for (let a = 0; a < 24; a++) groove.add(key(Math.round(cx + 3 * Math.cos(a * TAU / 24)), Math.round(cy + 3 * Math.sin(a * TAU / 24)))); }
    if (rng.next() < 0.4) { const p = rng.pick(pts); groove.add(key(p[0], p[1])); groove.add(key(p[0] + 1, p[1])); }
    for (const k of groove) {
      const x = k % 64, y = Math.floor(k / 64);
      img.mul(x, y, 0.42);
      if (!groove.has(key(x + 1, y + 1))) img.mul(x + 1, y + 1, 1.25);
      if (!groove.has(key(x - 1, y - 1))) img.mul(x - 1, y - 1, 0.8);
      if (rng.next() < 0.15) img.blend(x, y, [40, 66, 34], 0.5);
    }
  }
  return img;
}

function texMarble() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('marble');
  const t1 = fbm('mb_t', W, H, 4, 4, 5, 0.5), t2 = fbm('mb_t2', W, H, 2, 2, 4, 0.55), dirt = fbm('mb_d', W, H, 2, 2, 4, 0.6);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    const v1 = Math.pow(1 - Math.abs(Math.sin(TAU * (x / 64 + y * 2 / 64) + t1[i] * 6)), 10);
    const v2 = Math.pow(1 - Math.abs(Math.sin(TAU * (x * 3 / 64 - y / 64) + t2[i] * 5)), 22);
    let c = mulC([214, 211, 203], 0.95 + 0.06 * t2[i]);
    c = lerpC(c, [120, 120, 118], 0.75 * v1); c = lerpC(c, [150, 148, 142], 0.5 * v2);
    c = lerpC(c, [168, 158, 140], 0.35 * smoothstep(0.55, 0.85, dirt[i]));
    if (v1 > 0.3) c = lerpC(c, [130, 118, 98], 0.15);
    img.set(x, y, addC(c, (rng.next() - 0.5) * 7));
  }
  return img;
}

function texCloth() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('cloth_dark');
  const dye = fbm('cd_dye', W, H, 4, 4, 3, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x, rib = ((x + y) & 3) < 2;
    img.set(x, y, addC(mulC(rib ? [54, 49, 60] : [38, 34, 43], 0.9 + 0.2 * dye[i]), (rng.next() - 0.5) * 12));
  }
  for (let k = 0; k < 40; k++) img.blend(rng.int(0, 63), rng.int(0, 63), [76, 72, 82], 0.7);
  for (let k = 0; k < 8; k++) {
    const x0 = rng.int(0, 63), y0 = rng.int(0, 63), a = rng.uni(0, TAU), l = rng.int(3, 7);
    line(x0, y0, x0 + Math.cos(a) * l, y0 + Math.sin(a) * l, (x, y) => img.blend(x, y, [80, 76, 86], 0.4));
  }
  return img;
}

function texTin() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('tin');
  const brush = fbm('tn_b', W, H, 2, 32, 3, 0.5), dent = fbm('tn_d', W, H, 2, 2, 3, 0.5), spots = fbm('tn_s', W, H, 4, 4, 4, 0.6);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = mulC([140, 142, 140], 0.85 + 0.15 * brush[i] + 0.12 * (dent[i] - 0.5));
    c = lerpC(c, [108, 106, 98], 0.5 * smoothstep(0.68, 0.85, spots[i]));
    img.set(x, y, addC(c, (rng.next() - 0.5) * 7));
  }
  for (let k = 0; k < 26; k++) {
    const x0 = rng.int(0, 63), y0 = rng.int(0, 63), a = rng.next() < 0.6 ? rng.uni(-0.3, 0.3) : rng.uni(0, TAU), l = rng.int(4, 18);
    const lightS = rng.next() < 0.6;
    line(x0, y0, x0 + Math.cos(a) * l, y0 + Math.sin(a) * l, (x, y) => img.blend(x, y, lightS ? [186, 188, 186] : [92, 94, 94], lightS ? 0.6 : 0.5));
  }
  return img;
}

function texWindowRain() {
  const W = 64, H = 64, img = new Img(W, H), rng = new Rng('window_rain');
  const n1 = fbm('wr_n', W, H, 4, 4, 3, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = lerpC([12, 18, 36], [26, 38, 64], clamp01(0.2 + 0.4 * n1[i] + 0.2 * (1 - y / 63)));
    const dl = Math.hypot(x - 46, y - 14) / 11; if (dl < 1) c = lerpC(c, [44, 58, 86], 0.35 * (1 - dl) * (1 - dl));
    img.set(x, y, addC(c, (rng.next() - 0.5) * 5));
  }
  for (let k = 0; k < 12; k++) { // escorridos
    let x = rng.int(0, 63); const y0 = rng.int(-10, 40), len = rng.int(15, 45);
    for (let s = 0; s < len; s++) { const y = y0 + s; if (y < 0 || y > 63) continue; if (rng.next() < 0.12) x += rng.next() < 0.5 ? -1 : 1; img.blend(x, y, [52, 70, 102], 0.55 * (0.4 + 0.6 * s / len)); }
    const yb = y0 + len; if (yb >= 0 && yb < 63) { img.set(x, yb, [140, 162, 196]); img.set(x + 1, yb, [54, 72, 104]); img.set(x, yb + 1, [54, 72, 104]); img.set(x + 1, yb + 1, [10, 14, 26]); }
  }
  for (let k = 0; k < 45; k++) { // gotas
    const x = rng.int(0, 62), y = rng.int(0, 62);
    if (rng.next() < 0.5) img.set(x, y, [70, 92, 128]);
    else { img.set(x, y, [140, 162, 196]); img.set(x + 1, y, [54, 72, 104]); img.set(x, y + 1, [54, 72, 104]); img.set(x + 1, y + 1, [10, 14, 26]); }
  }
  return img;
}

function texBrass() {
  const W = 32, H = 32, img = new Img(W, H), rng = new Rng('metal_brass');
  const tarn = fbm('ms_t', W, H, 2, 2, 4, 0.55), brush = fbm('ms_b', W, H, 2, 16, 2, 0.5);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    let c = mulC([160, 126, 58], 0.85 + 0.2 * brush[i]);
    c = lerpC(c, [90, 76, 40], 0.7 * smoothstep(0.45, 0.8, tarn[i]));
    if (tarn[i] < 0.3 && rng.next() < 0.06) c = [214, 184, 104];
    img.set(x, y, addC(c, (rng.next() - 0.5) * 8));
  }
  for (let k = 0; k < 12; k++) img.blend(rng.int(0, 31), rng.int(0, 31), [88, 112, 76], 0.7);
  return img;
}

function texGlyph() {
  const W = 32, H = 32, img = new Img(W, H, true), rng = new Rng('glyph_symbol');
  const stamp = (x, y, a) => { if (x >= 0 && x < W && y >= 0 && y < H) img.a[y * W + x] = Math.max(img.a[y * W + x], a); };
  const scratch = (x0, y0, x1, y1, a = 0.95) => {
    const steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2);
    for (let s = 0; s <= steps; s++) {
      const t = s / steps, x = x0 + (x1 - x0) * t + rng.bi() * 0.35, y = y0 + (y1 - y0) * t + rng.bi() * 0.35;
      if (rng.next() < 0.06) continue;
      const xi = Math.round(x), yi = Math.round(y);
      stamp(xi, yi, a * rng.uni(0.75, 1));
      if (rng.next() < 0.25) stamp(xi + (rng.next() < 0.5 ? 1 : 0), yi + (rng.next() < 0.5 ? 1 : 0), a * 0.45);
    }
  };
  const arc = (cx, cy, r, a0, a1, a = 0.95) => { const st = Math.ceil(Math.abs(a1 - a0) * r / 1.5); for (let s = 0; s < st; s++) { const t0 = a0 + (a1 - a0) * s / st, t1 = a0 + (a1 - a0) * (s + 1) / st; scratch(cx + r * Math.cos(t0), cy + r * Math.sin(t0), cx + r * Math.cos(t1), cy + r * Math.sin(t1), a); } };
  arc(16, 16.5, 11.5, 0.35, 5.6);                 // anel quebrado
  arc(16, 16.5, 8.5, 3.6, 5.9, 0.8);              // arco interno parcial
  scratch(16, 5, 15.5, 27);                       // espinha
  scratch(16, 11, 10.5, 6.5); scratch(16, 11, 21.5, 6); scratch(15.8, 19, 9.5, 23.5); scratch(15.8, 19, 22, 24);
  scratch(8.5, 16, 23.5, 13.5);                   // travessa inclinada
  scratch(8.9, 16.5, 23.8, 14.1, 0.6);            // risco duplo
  scratch(12.5, 15.5, 16, 12.5); scratch(16, 12.5, 19.5, 15); scratch(19.5, 15, 16, 18); scratch(16, 18, 12.5, 15.5); // "olho"
  stamp(16, 15, 1); stamp(15, 15, 0.8);
  for (let k = 0; k < 5; k++) { const x = rng.uni(3, 28), y = rng.uni(3, 28), a = rng.uni(0, TAU), l = rng.uni(2, 5); scratch(x, y, x + Math.cos(a) * l, y + Math.sin(a) * l, 0.5); }
  for (let i = 0; i < W * H; i++) {
    const c = rng.next() < 0.5 ? [40, 26, 20] : [64, 40, 30];
    img.rgb[i * 3] = c[0]; img.rgb[i * 3 + 1] = c[1]; img.rgb[i * 3 + 2] = c[2];
    img.a[i] = Math.min(0.95, img.a[i]);
  }
  return img;
}

function texTentacleShadow() {
  const W = 64, H = 64, img = new Img(W, H, true);
  const tents = [
    { bx: 10, w: 8, len: 50, curl: -1, tilt: 0.12, ph: 0.3 }, { bx: 25, w: 10, len: 64, curl: 1, tilt: -0.05, ph: 1.7 },
    { bx: 40, w: 9, len: 58, curl: -1, tilt: 0.06, ph: 2.9 }, { bx: 54, w: 7, len: 44, curl: 1, tilt: -0.15, ph: 4.2 },
  ];
  const pts = [];
  for (const T of tents) {
    let x = T.bx, y = 67, hd = -Math.PI / 2 + T.tilt; const M = 160, ds = T.len / M;
    for (let s = 0; s <= M; s++) {
      const u = s / M;
      pts.push([x, y, (T.w / 2) * Math.pow(1 - u, 0.8) + 0.5]);
      // ondula suavemente e so enrola na ponta
      hd += (0.022 * Math.sin(u * Math.PI * 2.2 + T.ph) + T.curl * 0.42 * Math.pow(smoothstep(0.62, 1, u), 1.2)) * ds;
      x += Math.cos(hd) * ds; y += Math.sin(hd) * ds;
    }
  }
  const soft = 1.8;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let a = 0;
    for (const [px, py, r] of pts) { const d = Math.hypot(x + 0.5 - px, y + 0.5 - py); if (d < r + soft) a = Math.max(a, clamp01((r - d) / soft + 0.5)); }
    const i = y * W + x; img.a[i] = a; img.rgb[i * 3] = 6; img.rgb[i * 3 + 1] = 4; img.rgb[i * 3 + 2] = 8;
  }
  return img;
}

function texCloud() {
  const W = 64, H = 64, img = new Img(W, H, true), n = fbm('cp_n', W, H, 4, 4, 4, 0.55);
  const blobs = [[32, 36, 21], [18, 38, 14], [46, 37, 15], [26, 26, 14], [40, 25, 13], [33, 18, 10]];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x; let shape = 0;
    for (const [bx, by, br] of blobs) shape = Math.max(shape, 1 - Math.hypot(x - bx, y - by) / br);
    const r0 = Math.hypot(x - 32, y - 32) / 31, fall = clamp01(1 - Math.pow(r0, 4));
    const dens = clamp01(shape * 1.3 + (n[i] - 0.5) * 0.6) * fall;
    img.a[i] = (x === 0 || y === 0 || x === W - 1 || y === H - 1) ? 0 : smoothstep(0.05, 0.6, dens);
    const c = lerpC([158, 158, 166], [218, 218, 224], clamp01(0.5 + (36 - y) / 30 + (n[i] - 0.5) * 0.5));
    img.rgb[i * 3] = c[0]; img.rgb[i * 3 + 1] = c[1]; img.rgb[i * 3 + 2] = c[2];
  }
  return img;
}

function texSmoke() {
  const W = 32, H = 32, img = new Img(W, H, true), S = 16, n = fbm('sd_n', S, S, 2, 2, 3, 0.5);
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const v = n[y * S + x], d = Math.hypot(x + 0.5 - 8, y + 0.5 - 8) / 7.6;
    const edge = x === 0 || y === 0 || x === S - 1 || y === S - 1;
    const a = d >= 1 || edge ? 0 : clamp(Math.max(0, 1 - Math.pow(d, 1.6)) * 1.5 + (v - 0.5) * 0.7, 0, 0.94);
    const c = lerpC([30, 28, 27], [54, 50, 46], v);
    for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) { const i = (y * 2 + j) * W + x * 2 + k; img.a[i] = a; img.rgb[i * 3] = c[0]; img.rgb[i * 3 + 1] = c[1]; img.rgb[i * 3 + 2] = c[2]; }
  }
  return img;
}

// ============================================================== main
function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const brick = texBrick();
  const brickLum = brick.meanLum();
  const JOBS = [
    ['wallpaper_boston.png', texWallpaper, 24, 7],
    ['wood_floor.png', texWoodFloor, 24, 7],
    ['wood_dark.png', texWoodDark, 20, 6],
    ['plaster.png', texPlaster, 20, 7],
    ['brick_red.png', () => brick, 24, 7],
    ['scales_green.png', () => texScales(brickLum), 24, 7],
    ['cardboard.png', texCardboard, 20, 7],
    ['paper_aged.png', texPaperAged, 32, 8],
    ['paper_diary.png', texPaperDiary, 24, 7],
    ['clay.png', texClay, 20, 7],
    ['bas_relief.png', texBasRelief, 20, 8],
    ['stone_green.png', stoneBase, 24, 6],
    ['stone_green_carved.png', texStoneCarved, 24, 6],
    ['marble.png', texMarble, 20, 7],
    ['cloth_dark.png', texCloth, 16, 6],
    ['tin.png', texTin, 20, 7],
    ['window_rain.png', texWindowRain, 20, 6],
    ['metal_brass.png', texBrass, 16, 7],
    ['glyph_symbol.png', texGlyph, 8, 0],
    ['tentacle_shadow.png', texTentacleShadow, 4, 0],
    ['cloud_puff.png', texCloud, 16, 6],
    ['smoke_dark.png', texSmoke, 12, 5],
  ];
  for (const [name, fn, ncol, dither] of JOBS) {
    const img = fn();
    const q = quantize(img, ncol, dither);
    fs.writeFileSync(path.join(OUT_DIR, name), encodePNG(img.w, img.h, q.ch, q.data));
    console.log(`${name.padEnd(24)} ${img.w}x${img.h} ${q.ch === 4 ? 'RGBA' : 'RGB '} paleta=${q.pal.length} cores`);
  }
  console.log('OK -> ' + OUT_DIR);
}
main();
