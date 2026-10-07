'use strict';
/*
 * gen_draft_audio.js
 * ---------------------------------------------------------------------------
 * Gera os sons PROVISORIOS ("draft") de "CtHlUhU iS cAlLiNg YoU".
 * Tudo aqui e sintetizado proceduralmente (ruido filtrado, sintese de
 * formantes, osciladores, reverb simples) apenas para o jogo ter audio
 * durante o desenvolvimento. Estes arquivos sao PLACEHOLDERS e devem ser
 * SUBSTITUIDOS por gravacoes / sound design de verdade, mantendo exatamente
 * os mesmos nomes de arquivo (o codigo Godot referencia pelos nomes).
 *
 * Formato: WAV PCM 16-bit, mono, 22050 Hz (estetica lo-fi de PS1).
 * Arquivos *_loop.wav recebem um chunk RIFF "smpl" com um loop para frente
 * cobrindo o arquivo inteiro (inicio = 0, fim = ultima amostra); o
 * importador de WAV do Godot detecta esse loop automaticamente.
 *
 * Deterministico (PRNG mulberry32 com semente por arquivo) e usa apenas
 * modulos nativos do Node.js (sem npm). Para rodar, na raiz do projeto:
 *
 *     node tools/gen_draft_audio.js
 *
 * Saida: assets/audio/draft/
 * ---------------------------------------------------------------------------
 */

const fs = require('fs');
const path = require('path');

const SR = 22050;
const TAU = Math.PI * 2;
const OUT_DIR = path.resolve(__dirname, '..', 'assets', 'audio', 'draft');

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
}

// ============================================================== buffers
const N = (sec) => Math.round(sec * SR);
const buf = (n) => new Float64Array(n);

function add(dst, src, off = 0, g = 1) {
  const s = Math.max(0, -off), e = Math.min(src.length, dst.length - off);
  for (let i = s; i < e; i++) dst[i + off] += src[i] * g;
  return dst;
}
function addWrap(dst, src, off = 0, g = 1) {
  const L = dst.length; let j = ((off % L) + L) % L;
  for (let i = 0; i < src.length; i++) { dst[j] += src[i] * g; if (++j === L) j = 0; }
  return dst;
}
function gain(x, g) { for (let i = 0; i < x.length; i++) x[i] *= g; return x; }
function concat(...bs) {
  const y = buf(bs.reduce((a, b) => a + b.length, 0)); let o = 0;
  for (const b of bs) { y.set(b, o); o += b.length; }
  return y;
}
// processa um sinal periodico (loop) de forma circular: 3 copias, fica com a ultima
function circular(x, fn) { const L = x.length; const y = fn(concat(x, x, x)); return y.slice(2 * L, 3 * L); }
function peak(x) { let m = 0; for (let i = 0; i < x.length; i++) { const a = Math.abs(x[i]); if (a > m) m = a; } return m; }
function rms(x) { let s = 0; for (let i = 0; i < x.length; i++) s += x[i] * x[i]; return Math.sqrt(s / Math.max(1, x.length)); }
function normPeak(x, p = 1) { const m = peak(x); if (m > 0) gain(x, p / m); return x; }
function normalize(x, db = -1) { return normPeak(x, Math.pow(10, db / 20)); }
function setRms(x, r) { const v = rms(x); if (v > 0) gain(x, r / v); return x; }
function levelPct(x, pct, target) {
  const a = Float64Array.from(x, Math.abs).sort();
  const v = a[Math.min(a.length - 1, Math.floor(pct * a.length))];
  if (v > 0) gain(x, target / v);
  return x;
}
function fadeIn(x, sec) { const n = Math.min(x.length, N(sec)); for (let i = 0; i < n; i++) x[i] *= 0.5 - 0.5 * Math.cos(Math.PI * i / n); return x; }
function fadeOut(x, sec) {
  const n = Math.min(x.length, N(sec)), L = x.length;
  for (let i = 0; i < n; i++) x[L - 1 - i] *= 0.5 - 0.5 * Math.cos(Math.PI * i / n);
  return x;
}
function reverse(x) { return Float64Array.from(x).reverse(); }
function softclip(x, drive = 1.5) { const k = Math.tanh(drive); for (let i = 0; i < x.length; i++) x[i] = Math.tanh(drive * x[i]) / k; return x; }
function crush(x, bits = 12) { const q = Math.pow(2, bits - 1); for (let i = 0; i < x.length; i++) x[i] = Math.round(x[i] * q) / q; return x; }
function arr(n, fn) { const y = buf(n); for (let i = 0; i < n; i++) y[i] = fn(i, i / SR); return y; }

function envPts(pts) {
  return (t) => {
    if (t <= pts[0][0]) return pts[0][1];
    for (let k = 1; k < pts.length; k++) {
      if (t <= pts[k][0]) {
        const [t0, v0] = pts[k - 1], [t1, v1] = pts[k];
        return v0 + (v1 - v0) * (t - t0) / (t1 - t0);
      }
    }
    return pts[pts.length - 1][1];
  };
}
// ruido suave (interpolacao cosseno entre pontos aleatorios), valores em [-1,1]
function slowNoise(rng, n, rate) {
  const step = Math.max(1, Math.round(SR / rate)); const m = Math.ceil(n / step) + 2;
  const pts = buf(m); for (let k = 0; k < m; k++) pts[k] = rng.bi();
  const y = buf(n);
  for (let i = 0; i < n; i++) {
    const p = i / step, k = Math.floor(p), f = p - k, u = 0.5 - 0.5 * Math.cos(Math.PI * f);
    y[i] = pts[k] * (1 - u) + pts[k + 1] * u;
  }
  return y;
}
function smooth(a, tau) {
  const c = Math.exp(-1 / (tau * SR)); let s = a[0];
  for (let i = 0; i < a.length; i++) { s = a[i] + c * (s - a[i]); a[i] = s; }
  return a;
}

// ============================================================== filtros
// SVF topologia TPT (Zavalishin): estavel com cutoff modulado
class SVF {
  constructor(fc = 1000, q = 0.707) { this.s1 = 0; this.s2 = 0; this.lp = 0; this.bp = 0; this.hp = 0; this.set(fc, q); }
  set(fc, q) {
    const f = Math.min(Math.max(fc, 5), SR * 0.45);
    const g = Math.tan(Math.PI * f / SR), k = 1 / q;
    this.k = k; this.a1 = 1 / (1 + g * (g + k)); this.a2 = g * this.a1; this.a3 = g * this.a2;
  }
  tick(v0) {
    const v3 = v0 - this.s2;
    const v1 = this.a1 * this.s1 + this.a2 * v3;
    const v2 = this.s2 + this.a2 * this.s1 + this.a3 * v3;
    this.s1 = 2 * v1 - this.s1; this.s2 = 2 * v2 - this.s2;
    this.lp = v2; this.bp = v1; this.hp = v0 - this.k * v1 - v2;
    return v1 * this.k; // passa-banda normalizado (0 dB no centro)
  }
}
const MODE = { lp: 0, bp: 1, hp: 2 };
function svf(x, mode, fc, q = 0.707) {
  const m = MODE[mode], dyn = typeof fc === 'function';
  const f = new SVF(dyn ? fc(0) : fc, q); const y = buf(x.length);
  for (let i = 0; i < x.length; i++) {
    if (dyn && (i & 7) === 0) f.set(fc(i), q);
    const b = f.tick(x[i]);
    y[i] = m === 0 ? f.lp : m === 1 ? b : f.hp;
  }
  return y;
}
const lp = (x, fc, q) => svf(x, 'lp', fc, q);
const hp = (x, fc, q) => svf(x, 'hp', fc, q);
const bp = (x, fc, q = 1) => svf(x, 'bp', fc, q);
function resBank(x, modes) { const y = buf(x.length); for (const [f, q, g] of modes) add(y, bp(x, f, q), 0, g); return y; }
function leaky(x, c = 0.996, g = 0.06) { const y = buf(x.length); let s = 0; for (let i = 0; i < x.length; i++) { s = s * c + x[i] * g; y[i] = s; } return y; }
// ruido rosa (Paul Kellet) aplicado como filtro sobre ruido branco
function pinkF(x) {
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0; const y = buf(x.length);
  for (let i = 0; i < x.length; i++) {
    const w = x[i];
    b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.96900 * b2 + w * 0.1538520;
    b3 = 0.86650 * b3 + w * 0.3104856; b4 = 0.55000 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.0168980;
    y[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11; b6 = w * 0.115926;
  }
  return y;
}

// ============================================================== fontes
function white(rng, n) { const y = buf(n); for (let i = 0; i < n; i++) y[i] = rng.bi(); return y; }
function polyblep(t, dt) {
  if (t < dt) { t /= dt; return t + t - t * t - 1; }
  if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
  return 0;
}
function sawOsc(freq, n, ph = 0) {
  const y = buf(n), dyn = typeof freq === 'function';
  for (let i = 0; i < n; i++) {
    const dt = (dyn ? freq(i) : freq) / SR; ph += dt; if (ph >= 1) ph -= Math.floor(ph);
    y[i] = 2 * ph - 1 - polyblep(ph, dt);
  }
  return y;
}
function sineOsc(freq, n, ph = 0) {
  const y = buf(n), dyn = typeof freq === 'function';
  for (let i = 0; i < n; i++) { ph += (dyn ? freq(i) : freq) / SR; y[i] = Math.sin(TAU * ph); }
  return y;
}
function burst(rng, dur, tau) { const n = N(dur), y = buf(n), c = tau * SR; for (let i = 0; i < n; i++) y[i] = rng.bi() * Math.exp(-i / c); return y; }
// modos ressonantes (senoides com decaimento exponencial): metal, pedra
function modal(n, modes, rng) {
  const y = buf(n);
  for (const [f, tau, amp] of modes) {
    const ph = rng ? rng.next() * TAU : 0, w = TAU * f / SR, dec = Math.exp(-1 / (tau * SR)); let a = amp;
    for (let i = 0; i < n && a > 1e-6; i++) { y[i] += a * Math.sin(w * i + ph); a *= dec; }
  }
  return y;
}
// baque grave com queda de pitch
function thump(o) {
  const n = N(o.dur), y = buf(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, f = o.f1 + (o.f0 - o.f1) * Math.exp(-t / o.ptau); ph += f / SR;
    const a = (t < o.att ? 0.5 - 0.5 * Math.cos(Math.PI * t / o.att) : 1) * Math.exp(-Math.max(0, t - o.att) / o.tau);
    y[i] = Math.sin(TAU * ph) * a;
  }
  if (o.click) add(y, lp(burst(o.rng, 0.015, 0.0025), o.clickLP || 1200), 0, o.click);
  return y;
}
// "plink" de gota/bolha: senoide com pitch subindo
function bubble(f0, f1, rise, tau, dur) {
  const n = N(dur), y = buf(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, f = f1 + (f0 - f1) * Math.exp(-t / rise); ph += f / SR;
    y[i] = Math.sin(TAU * ph) * (t < 0.0015 ? t / 0.0015 : 1) * Math.exp(-t / tau);
  }
  return y;
}
// rangido stick-slip: trem de pulsos irregular excitando ressonancias
function creak(rng, o) {
  const n = N(o.dur), e = buf(n); let i = 0;
  const bl = Math.max(2, Math.round((o.burstMs || 1.2) * SR / 1000));
  while (i < n) {
    const t = i / SR, a = o.amp(t);
    if (a > 0.001 && rng.next() > (o.skip || 0)) {
      const amp = a * (0.6 + 0.4 * rng.next());
      for (let k = 0; k < bl && i + k < n; k++) e[i + k] += amp * (k === 0 ? 1 : rng.bi() * 0.5) * Math.exp(-k / (bl / 3));
    }
    const r = Math.max(4, o.rate(t) * (1 + (o.jitter || 0.1) * rng.bi()));
    i += Math.max(1, Math.round(SR / r));
  }
  const y = resBank(e, o.modes);
  if (o.noise) {
    const nz = white(rng, n); for (let k = 0; k < n; k++) nz[k] *= o.amp(k / SR);
    add(y, bp(nz, o.noiseF || 2500, 0.8), 0, o.noise);
  }
  return y;
}
function woodKnock(rng, modes, dur = 0.15) {
  return resBank(burst(rng, dur, 0.0025), modes.map(([f, q], k) => [f * rng.uni(0.93, 1.07), q, 1 / (k + 1)]));
}

// ============================================================== efeitos
// reverb estilo Schroeder/Freeverb (combs com amortecimento + allpasses)
function reverb(x, o = {}) {
  const { size = 1, fb = 0.8, damp = 0.4, wet = 0.3, dry = 1, lpHz = 0 } = o;
  const n = x.length, sc = size * SR / 44100, w = buf(n);
  for (const d0 of [1116, 1188, 1277, 1356, 1422, 1491]) {
    const d = Math.max(2, Math.round(d0 * sc)), line = buf(d); let p = 0, st = 0;
    for (let i = 0; i < n; i++) {
      const out = line[p]; st = out * (1 - damp) + st * damp; line[p] = x[i] + st * fb;
      if (++p === d) p = 0; w[i] += out;
    }
  }
  for (const d0 of [556, 441, 341, 225]) {
    const d = Math.max(2, Math.round(d0 * sc)), line = buf(d); let p = 0;
    for (let i = 0; i < n; i++) { const bo = line[p], out = bo - w[i]; line[p] = w[i] + bo * 0.5; if (++p === d) p = 0; w[i] = out; }
  }
  const ww = lpHz ? lp(w, lpHz) : w;
  const rx = rms(x), rw = rms(ww), g = rw > 1e-12 ? wet * rx / rw : 0;
  const y = buf(n); for (let i = 0; i < n; i++) y[i] = x[i] * dry + ww[i] * g;
  return y;
}
function echo(x, delay, fb, mix, lpHz = 3000) {
  const d = N(delay), line = buf(d), a = Math.exp(-TAU * lpHz / SR), y = buf(x.length); let p = 0, st = 0;
  for (let i = 0; i < x.length; i++) {
    const out = line[p]; st = out + a * (st - out); line[p] = x[i] + st * fb; if (++p === d) p = 0;
    y[i] = x[i] + out * mix;
  }
  return y;
}
// reamostragem circular (Catmull-Rom); rate < 1 abaixa o pitch
function resampleCirc(x, rate, n, start = 0) {
  const L = x.length, y = buf(n);
  for (let i = 0; i < n; i++) {
    let pos = start + i * rate; pos -= Math.floor(pos / L) * L;
    const k = Math.floor(pos), f = pos - k;
    const xm1 = x[(k - 1 + L) % L], x0 = x[k % L], x1 = x[(k + 1) % L], x2 = x[(k + 2) % L];
    const c1 = 0.5 * (x1 - xm1), c2 = xm1 - 2.5 * x0 + 2 * x1 - 0.5 * x2, c3 = 0.5 * (x2 - xm1) + 1.5 * (x0 - x1);
    y[i] = ((c3 * f + c2) * f + c1) * f + x0;
  }
  return y;
}

// ============================================================== sintese de fala (formantes)
const PH = {
  u: { F: [300, 870, 2240], G: [1, 0.3, 0.12], av: 1 },
  a: { F: [730, 1090, 2440], G: [1, 0.62, 0.25], av: 1 },
  e: { F: [530, 1840, 2480], G: [1, 0.45, 0.22], av: 1 },
  o: { F: [570, 840, 2410], G: [1, 0.45, 0.14], av: 1 },
  m: { F: [250, 1000, 2200], G: [1, 0.05, 0.03], av: 0.55 },
  n: { F: [250, 1400, 2400], G: [1, 0.07, 0.04], av: 0.55 },
  ng: { F: [250, 1150, 2300], G: [1, 0.06, 0.03], av: 0.5 },
  l: { F: [360, 1250, 2700], G: [1, 0.25, 0.1], av: 0.75 },
  r: { F: [460, 1200, 1600], G: [1, 0.35, 0.2], av: 0.75 },
  w: { F: [300, 610, 2200], G: [1, 0.25, 0.08], av: 0.75 },
  y: { F: [280, 2100, 2900], G: [1, 0.35, 0.2], av: 0.75 },
  h: { av: 0, ah: 0.7, af: 0.04, ff: 2000, fq: 0.7 },
  f: { av: 0, ah: 0.05, af: 0.22, ff: 3600, fq: 0.7 },
  th: { av: 0, ah: 0.05, af: 0.15, ff: 5000, fq: 0.6 },
  k: { stop: true, voiced: false, af: 0.5, ff: 1800, fq: 2.5 },
  t: { stop: true, voiced: false, af: 0.45, ff: 4200, fq: 1.5 },
  g: { stop: true, voiced: true, af: 0.3, ff: 1500, fq: 2.5 },
};
// sylls: [{t, d, p (semitons), pe (semitom final), ph: [[fonema|objeto, duracao|null(vogal)]]}]
function compileSpeech(sylls, n) {
  const T = {};
  for (const k of ['F1', 'F2', 'F3', 'G1', 'G2', 'G3', 'AV', 'AH', 'AF', 'FF', 'FQ', 'P']) T[k] = buf(n);
  T.F1.fill(500); T.F2.fill(1500); T.F3.fill(2500); T.G1.fill(1); T.G2.fill(0.4); T.G3.fill(0.2);
  T.FF.fill(3000); T.FQ.fill(1); T.P.fill(NaN);
  let lastF = [500, 1500, 2500], lastG = [1, 0.4, 0.2];
  for (const s of sylls) {
    const phs = s.ph.map(([nm, d]) => ({ def: typeof nm === 'string' ? PH[nm] : nm, d }));
    if (phs.some((q) => !q.def)) throw new Error('fonema desconhecido: ' + JSON.stringify(s.ph));
    const fixed = phs.reduce((acc, q) => acc + (q.d || 0), 0);
    const vdur = Math.max(0.04, s.d - fixed);
    const pe = s.pe == null ? s.p : s.pe;
    let t = s.t;
    phs.forEach((q, k) => {
      const d = q.d == null ? vdur : q.d, def = q.def;
      let F = def.F, G = def.G;
      if (!F) {
        for (let j = k + 1; j < phs.length && !F; j++) if (phs[j].def.F) { F = phs[j].def.F; G = phs[j].def.G; }
        for (let j = k - 1; j >= 0 && !F; j--) if (phs[j].def.F) { F = phs[j].def.F; G = phs[j].def.G; }
        if (!F) { F = lastF; G = lastG; }
      }
      const i0 = Math.max(0, Math.round(t * SR)), i1 = Math.min(n, Math.round((t + d) * SR));
      for (let i = i0; i < i1; i++) {
        const fr = (i - i0) / Math.max(1, i1 - i0), em = def.env ? def.env(fr) : 1;
        T.F1[i] = F[0]; T.F2[i] = F[1]; T.F3[i] = F[2]; T.G1[i] = G[0]; T.G2[i] = G[1]; T.G3[i] = G[2];
        if (def.stop) {
          const b = fr >= 0.6;
          T.AV[i] = !b && def.voiced ? 0.12 : 0;
          T.AF[i] = b ? def.af : 0; T.AH[i] = b && !def.voiced ? 0.2 : 0;
          T.FF[i] = def.ff; T.FQ[i] = def.fq;
        } else {
          T.AV[i] = (def.av || 0) * em; T.AH[i] = (def.ah || 0) * em; T.AF[i] = (def.af || 0) * em;
          if (def.ff) { T.FF[i] = def.ff; T.FQ[i] = def.fq; }
        }
        const ts = i / SR - s.t, sf = ts / s.d;
        T.P[i] = s.p + (pe - s.p) * Math.max(0, Math.min(1, (sf - 0.45) / 0.55)) - 0.4 * Math.exp(-ts / 0.05);
      }
      lastF = F; lastG = G; t += d;
    });
  }
  let last = NaN;
  for (let i = 0; i < n; i++) { if (isNaN(T.P[i])) T.P[i] = last; else last = T.P[i]; }
  let first = 0; for (let i = 0; i < n; i++) if (!isNaN(T.P[i])) { first = T.P[i]; break; }
  for (let i = 0; i < n && isNaN(T.P[i]); i++) T.P[i] = first;
  for (const k of ['F1', 'F2', 'F3', 'G1', 'G2', 'G3']) smooth(T[k], 0.02);
  smooth(T.AV, 0.012); smooth(T.AH, 0.01); smooth(T.AF, 0.003); smooth(T.P, 0.03);
  return T;
}
function renderVoice(rng, T, n, o) {
  const out = buf(n), bw = o.bw || [80, 100, 140], fsc = o.fscale || 1;
  const f1 = new SVF(500, 5), f2 = new SVF(1500, 10), f3 = new SVF(2500, 15), ff = new SVF(3000, 1);
  const tilt = Math.exp(-TAU * (o.tilt || 900) / SR); let ts = 0;
  const drift = slowNoise(rng, n, 0.7);
  let ph = rng.next(); const vph = rng.next() * TAU;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    if ((i & 7) === 0) {
      const w = fsc * (1 + (o.fwob || 0) * Math.sin(TAU * (o.fwobHz || 3) * t));
      const a = T.F1[i] * w, b = T.F2[i] * w, c = T.F3[i] * w;
      f1.set(a, a / bw[0]); f2.set(b, b / bw[1]); f3.set(c, c / bw[2]); ff.set(T.FF[i], T.FQ[i]);
    }
    const semi = T.P[i] + (o.cents || 0) / 100 + drift[i] * (o.driftSemi || 0.08);
    const f0 = o.f0 * Math.pow(2, semi / 12) * (1 + (o.vibDepth || 0.004) * Math.sin(TAU * (o.vibHz || 5) * t + vph));
    const dt = f0 / SR; ph += dt; if (ph >= 1) ph -= 1;
    const saw = 2 * ph - 1 - polyblep(ph, dt);
    ts = saw + tilt * (ts - saw);
    const nz = rng.bi(), av = T.AV[i];
    const exc = o.whisper ? (av + T.AH[i]) * nz * (o.wgain || 3.5)
      : av * ts * 2 + (T.AH[i] + av * (o.breath || 0.03)) * nz;
    const y = T.G1[i] * f1.tick(exc) + T.G2[i] * f2.tick(exc) + T.G3[i] * f3.tick(exc);
    out[i] = y + T.AF[i] * ff.tick(rng.bi());
  }
  return out;
}

// ============================================================== WAV
function writeWav(name, x, loop) {
  const n = x.length, dataBytes = n * 2, smplBytes = loop ? 8 + 60 : 0;
  const total = 12 + 24 + 8 + dataBytes + smplBytes;
  const b = Buffer.alloc(total); let o = 0;
  b.write('RIFF', 0, 'ascii'); b.writeUInt32LE(total - 8, 4); b.write('WAVE', 8, 'ascii'); o = 12;
  b.write('fmt ', o, 'ascii'); b.writeUInt32LE(16, o + 4); b.writeUInt16LE(1, o + 8); b.writeUInt16LE(1, o + 10);
  b.writeUInt32LE(SR, o + 12); b.writeUInt32LE(SR * 2, o + 16); b.writeUInt16LE(2, o + 20); b.writeUInt16LE(16, o + 22); o += 24;
  b.write('data', o, 'ascii'); b.writeUInt32LE(dataBytes, o + 4); o += 8;
  for (let i = 0; i < n; i++) {
    let v = Math.round(x[i] * 32767); if (v > 32767) v = 32767; if (v < -32768) v = -32768;
    b.writeInt16LE(v, o); o += 2;
  }
  if (loop) {
    b.write('smpl', o, 'ascii'); b.writeUInt32LE(60, o + 4); o += 8;
    // manufacturer, product, samplePeriod(ns), MIDIUnityNote, MIDIPitchFraction, SMPTEFormat, SMPTEOffset, numLoops, samplerData
    for (const v of [0, 0, Math.round(1e9 / SR), 60, 0, 0, 0, 1, 0]) { b.writeUInt32LE(v, o); o += 4; }
    // cuePointId, type (0 = forward), start, end (ultima amostra), fraction, playCount (0 = infinito)
    for (const v of [0, 0, 0, n - 1, 0, 0]) { b.writeUInt32LE(v, o); o += 4; }
  }
  fs.writeFileSync(path.join(OUT_DIR, name), b);
}
// cadeia final: DC/sub-sonico fora, normaliza (-1 dBFS), leve bit-crush lo-fi
function finish(x, { db = -1, bits = 12, loop = false, hpHz = 20 } = {}) {
  const y = hpHz ? (loop ? circular(x, (z) => hp(z, hpHz)) : hp(x, hpHz)) : x;
  normalize(y, db);
  if (bits < 16) crush(y, bits);
  return y;
}

// ============================================================== AMBIENTES
function genRain() {
  const rng = new Rng('amb_rain_loop'), L = N(8);
  const gust = (i) => 0.82 + 0.1 * Math.sin(TAU * i / L + 0.3) + 0.06 * Math.sin(TAU * 3 * i / L + 1.1) + 0.03 * Math.sin(TAU * 7 * i / L + 2.0);
  const bed = circular(white(rng, L), (x) => hp(lp(x, 2400, 0.6), 160));
  const roof = circular(white(rng, L), (x) => hp(lp(pinkF(x), 650), 60));
  const hiss = circular(white(rng, L), (x) => bp(x, 6800, 0.7));
  for (let i = 0; i < L; i++) { const g = gust(i); bed[i] *= g; roof[i] *= g; hiss[i] *= g * g; }
  setRms(bed, 0.10); setRms(roof, 0.09); setRms(hiss, 0.03);
  const glass = buf(L);
  for (let k = 0; k < 8 * 75; k++) {
    const pos = Math.floor(rng.next() * L), a = Math.pow(rng.next(), 2.2) * gust(pos);
    const len = N(0.02), b = buf(len), tau = SR * rng.uni(0.0003, 0.0009);
    for (let i = 0; i < len; i++) b[i] = rng.bi() * Math.exp(-i / tau);
    const f = rng.uni(2400, 7000), r = bp(b, f, rng.uni(2, 6));
    if (rng.next() < 0.25) add(r, modal(len, [[f * rng.uni(0.45, 0.7), rng.uni(0.002, 0.006), 0.25]], rng));
    addWrap(glass, r, pos, a);
  }
  const taps = buf(L);
  for (let k = 0; k < 8 * 180; k++) {
    const pos = Math.floor(rng.next() * L), a = Math.pow(rng.next(), 3) * gust(pos);
    addWrap(taps, bp(burst(rng, 0.03, rng.uni(0.001, 0.0025)), rng.uni(450, 1500), rng.uni(1.5, 4)), pos, a);
  }
  const plinks = buf(L);
  for (let k = 0; k < 10; k++) { const f = rng.uni(900, 1800); addWrap(plinks, bubble(f, f * 1.6, 0.015, 0.03, 0.12), Math.floor(rng.next() * L), rng.uni(0.3, 0.7)); }
  setRms(glass, 0.05); setRms(taps, 0.05); setRms(plinks, 0.012);
  const mix = buf(L); for (const l of [bed, roof, hiss, glass, taps, plinks]) add(mix, l);
  const y = circular(mix, (x) => lp(reverb(x, { size: 0.8, fb: 0.75, damp: 0.45, wet: 0.18 }), 7500));
  levelPct(y, 0.999, 0.75); softclip(y, 1.0);
  return y;
}

function genCreak(idx) {
  const rng = new Rng('amb_creak_' + idx);
  const dur = idx === 1 ? 1.3 : 1.05;
  const c = creak(rng, idx === 1 ? {
    dur, jitter: 0.045, skip: 0.02, burstMs: 0.6, noise: 0.025, noiseF: 1800,
    rate: (t) => 55 + 70 * Math.sin(Math.PI * t / dur) + 18 * Math.sin(TAU * 3.1 * t),
    amp: envPts([[0, 0], [0.08, 0.7], [0.5, 1], [0.9, 0.8], [1.15, 0.3], [1.3, 0]]),
    modes: [[310, 12, 1], [720, 16, 0.8], [1290, 18, 0.55], [2150, 15, 0.35], [3400, 10, 0.2]],
  } : {
    dur, jitter: 0.05, skip: 0.03, burstMs: 0.6, noise: 0.02, noiseF: 2200,
    rate: (t) => 120 + 90 * Math.sin(TAU * 0.9 * t + 0.5) + 25 * Math.sin(TAU * 5.3 * t),
    amp: envPts([[0, 0], [0.05, 1], [0.33, 0.6], [0.42, 0.05], [0.52, 0.8], [0.85, 0.5], [1.05, 0]]),
    modes: [[420, 14, 1], [880, 16, 0.75], [1560, 18, 0.5], [2600, 14, 0.3]],
  });
  const y = buf(N(dur + 0.6)); add(y, c);
  const z = reverb(y, { size: 0.7, fb: 0.7, damp: 0.5, wet: 0.2 }).slice(0, N(dur + 0.18));
  return fadeOut(z, 0.12);
}

function groan(rng, dur, f0, f1, o) {
  const n = N(dur), wob = slowNoise(rng, n, 2.5);
  const s = sawOsc((i) => (f0 + (f1 - f0) * i / n) * (1 + 0.03 * wob[i] + 0.01 * Math.sin(TAU * 4.5 * i / SR)), n);
  const y = lp(add(add(buf(n), bp(s, o.fa, 3)), bp(s, o.fb, 4), 0, 0.6), o.lp);
  for (let i = 0; i < n; i++) y[i] *= Math.pow(Math.sin(Math.PI * i / n), 1.5);
  return y;
}
function genSeaPressure() {
  const rng = new Rng('amb_sea_pressure_loop'), L = N(8);
  const throb = (i) => 0.55 + 0.45 * Math.pow(Math.sin(Math.PI * (((i * 4) / L) % 1)), 4);
  const deep = circular(white(rng, L), (x) => lp(lp(leaky(x, 0.996, 0.05), 120, 0.9), 160));
  const press = circular(white(rng, L), (x) => lp(bp(x, 240, 0.8), 420));
  const tones = buf(L);
  for (let i = 0; i < L; i++) {
    const th = throb(i);
    deep[i] *= th * (0.85 + 0.15 * Math.sin(TAU * i / L + 1.2));
    press[i] *= 0.6 + 0.4 * Math.sin(TAU * 2 * i / L + 0.4);
    // 250 e 376 ciclos por loop = 31.25 Hz e 47 Hz (periodicos no loop)
    tones[i] = (0.6 * Math.sin(TAU * 250 * i / L) + 0.3 * Math.sin(TAU * 376 * i / L + 1.0)) * (0.4 + 0.6 * th);
  }
  setRms(deep, 0.2); setRms(press, 0.04); setRms(tones, 0.05);
  const gro = buf(L);
  addWrap(gro, groan(rng, 3.6, 56, 42, { fa: 140, fb: 300, lp: 420 }), N(2.3), 1);
  addWrap(gro, groan(rng, 2.2, 64, 57, { fa: 170, fb: 360, lp: 450 }), N(6.4), 0.45);
  setRms(gro, 0.05);
  const mix = buf(L); for (const l of [deep, press, tones, gro]) add(mix, l);
  const y = circular(mix, (x) => hp(lp(reverb(x, { size: 1.8, fb: 0.86, damp: 0.7, wet: 0.45 }), 520), 22));
  levelPct(y, 0.9995, 0.85); softclip(y, 1.1);
  return y;
}

function genWind() {
  const rng = new Rng('amb_wind_loop'), L = N(8);
  const P = (c, ph, i) => Math.sin(TAU * c * i / L + ph);
  const gust = (i) => Math.min(1, Math.max(0.15, 0.55 + 0.25 * P(1, 0.4, i) + 0.15 * P(2, 2.1, i) + 0.1 * P(5, 0.9, i)));
  const rush = circular(white(rng, L), (x) => hp(lp(pinkF(x), 900), 80));
  const howl1 = circular(white(rng, L), (x) => svf(x, 'bp', (i) => 380 + 150 * P(1, 0.4, i) + 50 * P(3, 1.7, i), 14));
  const howl2 = circular(white(rng, L), (x) => svf(x, 'bp', (i) => 610 + 220 * P(1, 2.0, i) + 70 * P(4, 0.2, i), 20));
  const whistle = circular(white(rng, L), (x) => svf(x, 'bp', (i) => 1450 + 250 * P(2, 1.3, i), 45));
  const hollow = circular(white(rng, L), (x) => bp(x, 170, 5));
  for (let i = 0; i < L; i++) {
    const g = gust(i);
    rush[i] *= g; howl1[i] *= Math.pow(g, 1.5); howl2[i] *= g * g;
    whistle[i] *= Math.max(0, g - 0.6) * 2.5; hollow[i] *= g;
  }
  setRms(rush, 0.08); setRms(howl1, 0.07); setRms(howl2, 0.05); setRms(whistle, 0.015); setRms(hollow, 0.04);
  const mix = buf(L); for (const l of [rush, howl1, howl2, whistle, hollow]) add(mix, l);
  const y = circular(mix, (x) => lp(reverb(x, { size: 1.5, fb: 0.82, damp: 0.5, wet: 0.35 }), 5000));
  levelPct(y, 0.9995, 0.85); softclip(y, 1.1);
  return y;
}

// ============================================================== MUSICA
function genDrone() {
  const rng = new Rng('mus_drone_low_loop'), L = N(12);
  // [ciclos por loop (k/12 Hz), amp, harmonicos, inclinacao, ciclos do LFO de amplitude]
  const voices = [
    [495, 1.0, 14, 1.25, 1],  // 41.25 Hz
    [498, 0.75, 8, 1.6, 2],   // 41.5 Hz  -> batimento lento de 0.25 Hz
    [524, 0.33, 10, 1.4, 3],  // 43.67 Hz -> segunda menor, aspereza
    [700, 0.17, 6, 1.5, 1],   // 58.33 Hz -> tritono (parcial fraco)
    [991, 0.22, 6, 1.8, 2],   // 82.58 Hz -> oitava desafinada
    [1400, 0.06, 3, 2.0, 3],  // 116.67 Hz -> tritono uma oitava acima
  ];
  const x = buf(L);
  for (const [k, amp, nh, tilt, lc] of voices) {
    const lph = rng.next() * TAU;
    for (let h = 1; h <= nh; h++) {
      const kh = k * h, a = amp / Math.pow(h, tilt), ph = rng.next() * TAU, hc = rng.int(1, 3), hph = rng.next() * TAU;
      for (let i = 0; i < L; i++) {
        const env = (0.7 + 0.3 * Math.sin(TAU * lc * i / L + lph)) * (0.75 + 0.25 * Math.sin(TAU * hc * i / L + hph));
        x[i] += a * env * Math.sin(TAU * ((kh * i) % L) / L + ph);
      }
    }
  }
  const rum = circular(white(rng, L), (z) => lp(lp(leaky(z, 0.995, 0.05), 80), 120));
  setRms(rum, rms(x) * 0.25); add(x, rum);
  const y = circular(x, (z) => {
    const a = svf(z, 'lp', (i) => 260 + 160 * Math.sin(TAU * i / L + 0.6) + 70 * Math.sin(TAU * 3 * i / L + 2.0), 1.1);
    return hp(reverb(a, { size: 1.6, fb: 0.84, damp: 0.6, wet: 0.35 }), 25);
  });
  normPeak(y, 1); softclip(y, 1.4);
  return y;
}

function genSting() {
  const rng = new Rng('mus_sting'), n = N(5), ext = N(6.5);
  const notes = [65.41, 92.5, 98.0, 130.81, 138.59, 185.0, 196.0, 277.18];
  const PK = 1.6;
  const env = (t) => (t < PK ? Math.pow(t / PK, 2.2) : Math.exp(-(t - PK) / 0.9));
  const osc = buf(ext);
  notes.forEach((f, k) => {
    for (const c of [-7, 0, 7]) add(osc, sawOsc(f * Math.pow(2, (c + rng.uni(-2, 2)) / 1200), ext, rng.next()), 0, 1 / (1 + k * 0.15));
  });
  const E = arr(ext, (i, t) => env(t));
  let y = svf(osc, 'lp', (i) => 150 + 2400 * Math.pow(E[i], 1.5), 1.2);
  for (let i = 0; i < ext; i++) y[i] *= E[i];
  setRms(y, 0.15);
  const sw = hp(white(rng, ext), 3000);
  for (let i = 0; i < ext; i++) { const t = i / SR; sw[i] *= t < PK ? Math.pow(t / PK, 4) : Math.exp(-(t - PK) / 0.15); }
  setRms(sw, 0.03); add(y, sw);
  const boom = thump({ rng, dur: 3, f0: 70, f1: 35, ptau: 0.15, tau: 0.8, att: 0.01 });
  add(y, boom, N(PK), 0.5);
  add(y, modal(N(3), [[311, 1.2, 0.05], [497, 0.9, 0.04], [823, 0.7, 0.03], [1187, 0.5, 0.02]], rng), N(PK), 1);
  y = reverb(y, { size: 1.4, fb: 0.84, damp: 0.45, wet: 0.4 }).slice(0, n);
  return fadeOut(y, 0.5);
}

// ============================================================== VOZES
let CHANT_CACHE = null;
function buildChant() {
  if (CHANT_CACHE) return CHANT_CACHE;
  const rng = new Rng('vox_chant_loop');
  const beat = 0.6, L = N(16 * beat); // 9.6 s
  const INHALE = { F: [800, 1250, 2550], G: [1, 0.6, 0.3], av: 0, ah: 0.6, af: 0.05, ff: 2500, fq: 0.8, env: (f) => Math.sin(Math.PI * Math.pow(f, 0.6)) };
  // "Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn"  vogais: u u a u u e a a a
  const SYL = [
    { b: 0, n: 1, p: 0, ph: [['f', 0.05], ['ng', 0.07], ['l', 0.04], ['u', null]] },
    { b: 1, n: 1, p: 0, ph: [['m', 0.07], ['g', 0.045], ['l', 0.035], ['u', null]] },
    { b: 2, n: 2, p: 1, ph: [['n', 0.06], ['a', null], ['h', 0.16]] },
    { b: 4, n: 1, p: 0, ph: [['k', 0.06], ['th', 0.06], ['u', null]] },
    { b: 5, n: 1, p: 0, ph: [['l', 0.05], ['h', 0.035], ['u', null]] },
    { b: 6, n: 2, p: 3, pe: 2, ph: [['r', 0.06], ['l', 0.04], ['y', 0.05], ['e', null], ['h', 0.12]] },
    { b: 8, n: 1, p: 0, ph: [['w', 0.07], ['g', 0.045], ['a', null], ['h', 0.05]] },
    { b: 9, n: 1, p: -1, ph: [['n', 0.06], ['a', null], ['g', 0.04], ['l', 0.06]] },
    { b: 10, n: 3, p: 0, pe: -2, ph: [['f', 0.08], ['t', 0.05], ['a', null], ['g', 0.04], ['n', 0.4]] },
    { b: 15.15, n: 0.7, p: 0, ph: [[INHALE, null]] },
  ];
  const voices = [
    { cents: -12, fscale: 0.97, dt: 0.012, amp: 1.0, vibHz: 4.6 },
    { cents: 8, fscale: 1.03, dt: -0.016, amp: 0.9, vibHz: 5.3 },
    { cents: -2, fscale: 1.0, dt: 0.0, amp: 1.0, vibHz: 5.0 },
    { cents: 19, fscale: 1.06, dt: 0.024, amp: 0.8, vibHz: 4.2 },
    { cents: -23, fscale: 0.93, dt: -0.008, amp: 0.85, vibHz: 5.7 },
    { cents: 4, fscale: 0.88, dt: 0.006, amp: 0.55, vibHz: 4.0, oct: 0.5 },
  ];
  const base = 0.04, vsum = buf(L), n = L + N(1.2);
  for (const v of voices) {
    const off = base + v.dt;
    const sylls = SYL.map((s) => ({ t: s.b * beat + off, d: s.n * beat - 0.06, p: s.p, pe: s.pe, ph: s.ph }));
    const T = compileSpeech(sylls, n);
    const y = renderVoice(rng, T, n, {
      f0: 98 * (v.oct || 1), cents: v.cents, fscale: v.fscale, vibHz: v.vibHz, vibDepth: 0.0035,
      breath: 0.04, bw: [70, 90, 130], tilt: 1000, driftSemi: 0.1,
    });
    addWrap(vsum, y, 0, v.amp);
  }
  normPeak(vsum, 1);
  const drum = buf(L);
  for (const [b, a] of [[0, 1], [4, 1], [8, 1], [10, 0.55], [12, 0.9]]) {
    addWrap(drum, thump({ rng, dur: 1.0, f0: 85, f1: 46, ptau: 0.05, tau: 0.22, att: 0.004, click: 0.25, clickLP: 900 }), N(b * beat + base - 0.01), a);
  }
  normPeak(drum, 0.55);
  const mix = add(vsum, drum);
  const y = circular(mix, (x) => hp(reverb(x, { size: 0.9, fb: 0.78, damp: 0.35, wet: 0.4, lpHz: 3500 }), 35));
  normPeak(y, 1); softclip(y, 1.2);
  CHANT_CACHE = y;
  return y;
}
function genChant() { return Float64Array.from(buildChant()); }

function genFhtagn() {
  const rng = new Rng('vox_fhtagn'), n = N(2.5), ext = N(3.2);
  const sylls = [
    { t: 0.10, d: 0.48, p: 0, ph: [['k', 0.06], ['th', 0.09], ['u', null]] },
    { t: 0.58, d: 0.45, p: 0, ph: [['l', 0.06], ['h', 0.06], ['u', null]] },
    { t: 1.12, d: 0.88, p: 0, ph: [['f', 0.12], ['h', 0.04], ['t', 0.06], ['a', null], ['g', 0.05], ['n', 0.22]] },
  ];
  const T = compileSpeech(sylls, ext);
  const y = buf(ext);
  for (const [fs, dl, g, wob] of [[1.0, 0, 1, 0.02], [0.72, 0.035, 0.8, 0.04], [1.28, 0.018, 0.35, 0.03]]) {
    const v = renderVoice(rng, T, ext, { f0: 100, whisper: true, wgain: 3.5, fscale: fs, bw: [140, 170, 240], fwob: wob, fwobHz: 2.7 + fs });
    add(y, v, N(dl), g);
  }
  setRms(y, 0.1);
  const sub = sineOsc((i) => 40 - 7 * i / ext, ext);
  add(sub, sineOsc((i) => 80 - 14 * i / ext, ext), 0, 0.25);
  const se = envPts([[0, 0], [0.4, 0.5], [1.3, 1], [2.0, 0.7], [2.5, 0]]);
  for (let i = 0; i < ext; i++) sub[i] *= se(i / SR);
  setRms(sub, 0.08); add(y, sub);
  const z = reverb(y, { size: 1.2, fb: 0.8, damp: 0.6, wet: 0.35, lpHz: 2500 }).slice(0, n);
  return fadeOut(fadeIn(z, 0.01), 0.2);
}

// ============================================================== SFX
function genHeartbeat() {
  const rng = new Rng('sfx_heartbeat'), n = N(0.55), y = buf(n);
  add(y, thump({ rng, dur: 0.5, f0: 72, f1: 44, ptau: 0.035, tau: 0.075, att: 0.008, click: 0.12, clickLP: 900 }), 0, 1);
  add(y, thump({ rng, dur: 0.3, f0: 80, f1: 50, ptau: 0.03, tau: 0.06, att: 0.006, click: 0.1, clickLP: 1100 }), N(0.25), 0.8);
  softclip(normPeak(y, 1), 1.6);
  return fadeOut(y, 0.04);
}

function genDrip(idx) {
  const rng = new Rng('sfx_drip_' + idx), f = [0, 1150, 1500, 880][idx], n = N(0.4), y = buf(N(0.9));
  add(y, bp(burst(rng, 0.01, 0.0005), f * 2.2, 2), 0, 0.3);
  add(y, bubble(f, f * 1.7, 0.018, 0.035, 0.2), N(0.002), 1);
  add(y, bp(burst(rng, 0.05, 0.004), f * 0.5, 6), 0, 0.15);
  let z = echo(y, 0.075 + idx * 0.008, 0.35, 0.35, 2500);
  z = reverb(z, { size: 0.6, fb: 0.75, damp: 0.3, wet: 0.2 }).slice(0, n);
  return fadeOut(z, 0.08);
}

function genStepWood(idx) {
  const rng = new Rng('sfx_step_wood_' + idx), n = N(0.25), y = buf(N(0.7));
  const contact = (off, a) => {
    add(y, thump({ rng, dur: 0.12, f0: rng.uni(150, 190), f1: rng.uni(85, 110), ptau: 0.012, tau: 0.025, att: 0.001 }), off, 0.9 * a);
    add(y, woodKnock(rng, [[rng.uni(170, 230), 5], [rng.uni(380, 480), 6], [rng.uni(850, 1100), 7], [rng.uni(1900, 2400), 5]], 0.1), off, 1.2 * a);
    const sc = bp(white(rng, N(0.04)), 2500, 0.7); fadeOut(sc, 0.03); add(y, sc, off, 0.05 * a);
  };
  contact(0, 1);
  contact(N(rng.uni(0.055, 0.085)), rng.uni(0.4, 0.55));
  if (idx % 2 === 0) {
    const d = 0.14;
    add(y, creak(rng, { dur: d, rate: (t) => 160 + 80 * t / d, amp: (t) => Math.sin(Math.PI * t / d), jitter: 0.1, burstMs: 0.8, modes: [[rng.uni(700, 900), 14, 1], [rng.uni(1500, 1800), 16, 0.6]] }), N(0.07), 0.25);
  }
  const z = reverb(y, { size: 0.5, fb: 0.7, damp: 0.45, wet: 0.12 }).slice(0, n);
  return fadeOut(z, 0.035);
}

function genStepStone(idx) {
  const rng = new Rng('sfx_step_stone_' + idx), n = N(0.25), y = buf(N(0.7));
  const contact = (off, a) => {
    add(y, hp(burst(rng, 0.01, 0.0006), 1500), off, 0.6 * a);
    add(y, modal(N(0.06), [[rng.uni(1400, 1800), 0.012, 0.35], [rng.uni(2600, 3200), 0.008, 0.25], [rng.uni(4200, 5000), 0.005, 0.15]], rng), off, a);
    add(y, thump({ rng, dur: 0.1, f0: rng.uni(120, 150), f1: rng.uni(70, 90), ptau: 0.01, tau: 0.02, att: 0.001 }), off, 0.8 * a);
    const sl = N(0.09), s = buf(sl);
    for (let i = 0; i < sl; i++) s[i] = rng.bi() * Math.exp(-i / (SR * 0.018)) * (i < 30 ? i / 30 : 1);
    add(y, svf(s, 'bp', (i) => 3800 - 2000 * i / sl, 1.2), off, 0.9 * a);
    const nd = rng.int(3, 7);
    for (let k = 0; k < nd; k++) {
      const f = rng.uni(1800, 4200);
      add(y, bubble(f, f * rng.uni(1.2, 1.6), 0.006, rng.uni(0.004, 0.009), 0.03), off + N(rng.uni(0.01, 0.12)), rng.uni(0.05, 0.2) * a);
    }
  };
  contact(0, 1);
  contact(N(rng.uni(0.05, 0.08)), rng.uni(0.4, 0.6));
  const z = reverb(y, { size: 0.6, fb: 0.72, damp: 0.25, wet: 0.22 }).slice(0, n);
  return fadeOut(z, 0.04);
}

function genBreath() {
  const rng = new Rng('sfx_breath_exhausted'), n = N(2.5);
  const IN = { F: [820, 1300, 2600], G: [1, 0.6, 0.35], av: 0, ah: 0.9, af: 0.06, ff: 2600, fq: 0.8, env: (f) => Math.pow(Math.sin(Math.PI * Math.pow(f, 0.65)), 0.8) };
  const OUT = (v) => ({ F: [640, 1180, 2400], G: [1, 0.55, 0.25], av: v, ah: 1.0, af: 0.04, ff: 1800, fq: 0.8, env: (f) => (1 - Math.exp(-f * 18)) * Math.pow(1 - f, 1.4) });
  const sylls = []; let t = 0.02;
  for (let c = 0; c < 5; c++) {
    const di = rng.uni(0.17, 0.2), dout = rng.uni(0.22, 0.26) + c * 0.008;
    sylls.push({ t, d: di, p: 2, ph: [[IN, null]] }); t += di + rng.uni(0.012, 0.022);
    sylls.push({ t, d: dout, p: -1 - c * 0.5, ph: [[OUT(c % 2 ? 0.14 : 0.05), null]] }); t += dout + rng.uni(0.015, 0.03);
  }
  const T = compileSpeech(sylls, n);
  const y = renderVoice(rng, T, n, { f0: 105, bw: [200, 240, 300], breath: 0, tilt: 700, driftSemi: 0.3, vibDepth: 0.01, vibHz: 7 });
  const z = reverb(y, { size: 0.5, fb: 0.7, damp: 0.5, wet: 0.1 });
  return fadeOut(z, 0.06);
}

function genPaper(idx) {
  const rng = new Rng('sfx_paper_' + idx), n = N(0.35);
  const env = idx === 1
    ? envPts([[0, 0], [0.03, 0.8], [0.12, 1], [0.22, 0.6], [0.32, 0.05], [0.35, 0]])
    : envPts([[0, 0], [0.02, 1], [0.1, 0.5], [0.14, 0.15], [0.17, 0.9], [0.26, 0.4], [0.33, 0], [0.35, 0]]);
  const E = arr(n, (i, t) => env(t));
  const sw = bp(hp(white(rng, n), 900), 3500, 0.6); for (let i = 0; i < n; i++) sw[i] *= E[i];
  const ex = buf(n); for (let i = 0; i < n; i++) if (rng.next() < 0.05 * E[i]) ex[i] = rng.bi() * Math.pow(rng.next(), 2);
  const cr = resBank(ex, [[2700, 3, 1], [4200, 4, 0.8], [6100, 3, 0.7], [8200, 2, 0.4]]);
  const body = lp(ex, 700);
  setRms(sw, 0.06); setRms(cr, 0.08); setRms(body, 0.02);
  const y = buf(n); add(y, sw); add(y, cr); add(y, body);
  return fadeOut(y, 0.02);
}

function genUnlock() {
  const rng = new Rng('sfx_unlock'), n = N(0.7), y = buf(N(1.2));
  const sc = white(rng, N(0.16)), stick = slowNoise(rng, sc.length, 90);
  for (let i = 0; i < sc.length; i++) sc[i] *= Math.sin(Math.PI * i / sc.length) * (0.4 + 0.6 * Math.abs(stick[i]));
  add(y, bp(sc, 3800, 2.5), 0, 0.35); add(y, bp(sc, 6200, 3), 0, 0.2);
  for (const tt of [0.03, 0.07, 0.11, 0.145]) {
    add(y, modal(N(0.05), [[rng.uni(3800, 4600), 0.006, 0.4], [rng.uni(6500, 7800), 0.004, 0.25]], rng), N(tt + rng.uni(-0.005, 0.005)), rng.uni(0.4, 0.7));
  }
  const tf = white(rng, N(0.28)); for (let i = 0; i < tf.length; i++) tf[i] *= Math.sqrt(Math.sin(Math.PI * i / tf.length)) * 0.5;
  add(y, bp(tf, 2400, 1.8), N(0.22), 0.25);
  for (const tt of [0.27, 0.34, 0.41]) {
    add(y, modal(N(0.06), [[rng.uni(2200, 2600), 0.01, 0.5], [rng.uni(3900, 4500), 0.007, 0.3], [rng.uni(6000, 6800), 0.004, 0.2]], rng), N(tt), 0.6);
  }
  const clack = modal(N(0.25), [[1150, 0.045, 0.7], [2730, 0.03, 0.5], [4100, 0.018, 0.35], [5350, 0.01, 0.25]], rng);
  add(clack, thump({ rng, dur: 0.12, f0: 320, f1: 190, ptau: 0.01, tau: 0.03, att: 0.0005 }), 0, 0.8);
  add(clack, hp(burst(rng, 0.01, 0.001), 1000), 0, 0.6);
  add(y, clack, N(0.5), 1.0);
  add(y, modal(N(0.08), [[1650, 0.015, 0.4], [3300, 0.01, 0.2]], rng), N(0.535), 0.4);
  const z = reverb(y, { size: 0.5, fb: 0.7, damp: 0.4, wet: 0.15 }).slice(0, n);
  return fadeOut(z, 0.05);
}

function genBoxOpen() {
  const rng = new Rng('sfx_box_open'), n = N(1.0), y = buf(N(1.6));
  add(y, woodKnock(rng, [[260, 5], [610, 6], [1300, 7]]), 0, 0.6);
  add(y, creak(rng, {
    dur: 0.78, jitter: 0.1, skip: 0.03, burstMs: 0.8, noise: 0.05, noiseF: 2200,
    rate: (t) => 70 + 110 * Math.sin(Math.PI * Math.min(1, t / 0.6)) - 30 * t + 15 * Math.sin(TAU * 6 * t),
    amp: envPts([[0, 0], [0.05, 0.8], [0.3, 1], [0.6, 0.7], [0.78, 0]]),
    modes: [[640, 14, 1], [1180, 18, 0.7], [2250, 16, 0.45], [3500, 12, 0.25]],
  }), N(0.06), 1);
  const air = lp(white(rng, N(0.7)), 800);
  for (let i = 0; i < air.length; i++) air[i] *= Math.sin(Math.PI * i / air.length) * 0.08;
  add(y, air, N(0.1));
  add(y, woodKnock(rng, [[220, 5], [520, 6], [1100, 6]]), N(0.87), 0.45);
  const z = reverb(y, { size: 0.6, fb: 0.7, damp: 0.45, wet: 0.15 }).slice(0, n);
  return fadeOut(z, 0.05);
}

function genThumpFar() {
  const rng = new Rng('sfx_thump_far'), n = N(1.5), y = buf(N(2.5));
  const hit = (off, a) => {
    add(y, thump({ rng, dur: 0.8, f0: 90, f1: 48, ptau: 0.04, tau: 0.16, att: 0.003, click: 0.4, clickLP: 600 }), off, a);
    add(y, lp(burst(rng, 0.2, 0.02), 300), off, 0.6 * a);
    add(y, woodKnock(rng, [[140, 4], [310, 5]], 0.2), off, 0.5 * a);
  };
  hit(N(0.02), 1); hit(N(0.21), 0.35); hit(N(0.33), 0.12);
  let z = lp(y, 380);
  z = lp(reverb(z, { size: 1.3, fb: 0.8, damp: 0.6, wet: 0.5 }), 300).slice(0, n);
  return fadeOut(z, 0.4);
}

function crack(rng) {
  const n = N(1.8), y = buf(n);
  add(y, hp(burst(rng, 0.12, 0.007), 350), 0, 1);
  const ns = rng.int(3, 7);
  for (let k = 0; k < ns; k++) add(y, hp(burst(rng, 0.05, 0.003), 800), N(rng.uni(0.005, 0.07)), rng.uni(0.2, 0.6));
  add(y, thump({ rng, dur: 1.2, f0: 75, f1: 38, ptau: 0.06, tau: 0.3, att: 0.002 }), 0, 0.9);
  let t = 0.05;
  while (t < 1.6) {
    const dens = Math.exp(-t / 0.4);
    if (rng.next() < dens) add(y, bp(burst(rng, 0.02, rng.uni(0.0008, 0.002)), rng.uni(900, 4000), 2), N(t), rng.uni(0.05, 0.25) * dens);
    t += rng.uni(0.008, 0.03);
  }
  return y;
}
function genDoorGrind() {
  const rng = new Rng('sfx_door_grind'), n = 264600 /* EXATO 12.0 s */, ext = n + N(3);
  const sw = envPts([[0, 0.12], [1.2, 0.3], [3.0, 0.5], [6.0, 0.78], [9.0, 1.0], [10.6, 1.0], [11.5, 0.5], [12.0, 0.25], [15, 0]]);
  const SW = arr(ext, (i, t) => sw(t));
  const surge = slowNoise(rng, ext, 0.9);
  const rum = lp(lp(leaky(white(rng, ext), 0.997, 0.05), 70, 0.9), 110);
  const sub = sineOsc((i) => 27 + 3 * surge[i], ext);
  for (let i = 0; i < ext; i++) { const e = SW[i] * (0.75 + 0.25 * surge[i]); rum[i] *= e; sub[i] *= e; }
  setRms(rum, 0.2); setRms(sub, 0.12);
  const sl2 = slowNoise(rng, ext, 2.2);
  const at = (a, t) => a[Math.min(ext - 1, Math.max(0, Math.round(t * SR)))];
  const grind = creak(rng, {
    dur: ext / SR, jitter: 0.35, skip: 0.1, burstMs: 6, noise: 0.25, noiseF: 700,
    rate: (t) => 24 + 12 * at(sl2, t),
    amp: (t) => (t < 0.8 ? 0 : Math.max(0, at(SW, t) * (0.65 + 0.35 * at(sl2, t))) * Math.min(1, (t - 0.8) / 1.2)),
    modes: [[95, 3, 1], [175, 4, 0.8], [265, 4, 0.6], [520, 3, 0.5], [1100, 2, 0.35], [2300, 1.5, 0.2]],
  });
  setRms(grind, 0.12);
  const groans = buf(ext);
  for (const [t0, d, r0, r1, a] of [[2.6, 1.6, 58, 72, 0.8], [5.3, 2.1, 66, 52, 1.0], [8.4, 1.8, 48, 62, 0.9]]) {
    add(groans, creak(rng, {
      dur: d, jitter: 0.08, skip: 0.02, burstMs: 4, noise: 0.05, noiseF: 500,
      rate: (t) => r0 + (r1 - r0) * t / d + 4 * Math.sin(TAU * 3 * t),
      amp: (t) => Math.pow(Math.sin(Math.PI * t / d), 1.3),
      modes: [[115, 8, 1], [235, 10, 0.7], [480, 9, 0.4], [960, 6, 0.2]],
    }), N(t0), a);
  }
  setRms(groans, 0.07);
  const cracks = buf(ext);
  for (const [t0, a] of [[2.2, 0.7], [4.6, 0.9], [7.1, 1.0], [8.5, 0.6], [10.2, 0.85]]) add(cracks, crack(rng), N(t0), a);
  const mix = buf(ext); for (const l of [rum, sub, grind, groans]) add(mix, l);
  const RV = { size: 2.2, fb: 0.86, damp: 0.5, wet: 0.45, lpHz: 3000 };
  const y = lp(reverb(mix, RV), 5500).slice(0, n);
  levelPct(y, 0.9995, 0.6); softclip(y, 1.0);
  // estalos processados a parte para nao serem esmagados pelo limitador
  const cr = lp(reverb(cracks, RV), 6000).slice(0, n);
  add(y, normPeak(cr, 0.9));
  return fadeOut(y, 0.35);
}

function genTremor() {
  const rng = new Rng('sfx_tremor_loop'), L = N(6);
  const P = (c, ph, i) => Math.sin(TAU * c * i / L + ph);
  const inten = (i) => 0.6 + 0.2 * P(1, 0.3, i) + 0.12 * P(2, 1.9, i) + 0.08 * P(5, 0.7, i) + 0.06 * P(9, 2.6, i);
  const rum = circular(white(rng, L), (x) => lp(lp(leaky(x, 0.998, 0.04), 70, 0.9), 90));
  const rat = circular(white(rng, L), (x) => bp(x, 180, 1.5));
  const grit = circular(white(rng, L), (x) => bp(x, 2200, 1));
  const tones = buf(L);
  for (let i = 0; i < L; i++) {
    const e = inten(i);
    rum[i] *= e;
    rat[i] *= Math.pow(0.5 + 0.5 * P(37, 0, i), 2) * e * e; // ~6.2 Hz de chocalho
    grit[i] *= Math.pow(Math.max(0, e - 0.7), 2);
    tones[i] = (Math.sin(TAU * 150 * i / L) + 0.6 * Math.sin(TAU * 200 * i / L + 0.8)) * e; // 25 Hz e 33.3 Hz
  }
  setRms(rum, 0.25); setRms(rat, 0.03); setRms(grit, 0.006); setRms(tones, 0.1);
  const mix = buf(L); for (const l of [rum, rat, grit, tones]) add(mix, l);
  const y = circular(mix, (x) => hp(reverb(x, { size: 1.5, fb: 0.8, damp: 0.7, wet: 0.25 }), 18));
  levelPct(y, 0.9995, 0.85); softclip(y, 1.3);
  return y;
}

function genWetDrag() {
  const rng = new Rng('sfx_wet_drag'), n = N(8), ext = n + N(1.5);
  const pulls = [[0.2, 1.6, 2.6], [2.9, 4.2, 5.3], [5.4, 6.6, 7.7]];
  const pullEnv = (t) => {
    let v = 0;
    for (const [a, p, b] of pulls) if (t > a && t < b) { const u = t < p ? (t - a) / (p - a) : 1 - (t - p) / (b - p); v = Math.max(v, Math.pow(Math.sin(0.5 * Math.PI * u), 1.5)); }
    return v;
  };
  const PE = arr(ext, (i, t) => pullEnv(t));
  const PS = smooth(Float64Array.from(PE), 0.5);
  const fr = slowNoise(rng, ext, 7);
  const sl = svf(white(rng, ext), 'bp', (i) => 500 + 500 * PE[i] + 200 * fr[i], 1.3);
  for (let i = 0; i < ext; i++) sl[i] *= PE[i] * (0.4 + 0.6 * Math.abs(fr[i]));
  const sq = buf(ext); let t = 0.1;
  while (t < 7.6) {
    const pe = pullEnv(t);
    if (rng.next() < 0.25 + 0.75 * pe) {
      const len = N(rng.uni(0.05, 0.16)), nb = buf(len);
      for (let k = 0; k < len; k++) nb[k] = rng.bi() * (k < 60 ? k / 60 : 1) * Math.exp(-k / (len * 0.35));
      const f0 = rng.uni(900, 1800), f1 = rng.uni(180, 400);
      add(sq, svf(nb, 'bp', (k) => f1 + (f0 - f1) * Math.exp(-k / (len * 0.3)), rng.uni(2.5, 5)), N(t), rng.uni(0.4, 1) * (0.3 + 0.7 * pe));
    }
    t += rng.uni(0.06, 0.25);
  }
  const bub = buf(ext); t = 0.1;
  while (t < 7.7) {
    if (rng.next() < 0.3 + 0.7 * pullEnv(t)) { const f = rng.uni(180, 700); add(bub, bubble(f, f * rng.uni(1.5, 2.5), 0.01, rng.uni(0.01, 0.03), 0.08), N(t), rng.uni(0.2, 0.7)); }
    t += rng.uni(0.04, 0.18);
  }
  const gw = slowNoise(rng, ext, 0.6);
  const gs = sawOsc((i) => 38 + 5 * gw[i] + 1.5 * Math.sin(TAU * 0.9 * i / SR), ext);
  const gr = add(add(add(buf(ext), bp(gs, 160, 4)), bp(gs, 300, 5), 0, 0.6), lp(gs, 90), 0, 0.5);
  for (let i = 0; i < ext; i++) gr[i] *= 0.45 + 0.55 * PS[i];
  const sub = lp(lp(leaky(white(rng, ext), 0.997, 0.05), 60), 80);
  for (let i = 0; i < ext; i++) sub[i] *= PS[i];
  setRms(sl, 0.12); setRms(sq, 0.1); setRms(bub, 0.05); setRms(gr, 0.14); setRms(sub, 0.08);
  const mix = buf(ext); for (const l of [sl, sq, bub, gr, sub]) add(mix, l);
  const y = lp(reverb(mix, { size: 1.6, fb: 0.85, damp: 0.55, wet: 0.4 }), 4500).slice(0, n);
  return fadeOut(fadeIn(y, 0.25), 1.0);
}

function genTentacle() {
  const rng = new Rng('sfx_tentacle_move'), n = N(4);
  const mv = envPts([[0, 0], [0.5, 0.6], [0.95, 1], [1.5, 0.75], [2.2, 0.2], [2.8, 0]]);
  const MV = arr(n, (i, t) => mv(t));
  const jig = slowNoise(rng, n, 9);
  const sw = svf(white(rng, n), 'bp', (i) => 220 + 900 * Math.exp(-i / SR / 0.7), 3);
  for (let i = 0; i < n; i++) sw[i] *= MV[i] * (0.6 + 0.4 * Math.abs(jig[i]));
  const bub = buf(n); let t = 0.15;
  while (t < 2.2) {
    if (rng.next() < 0.2 + mv(t)) { const f = rng.uni(150, 600); add(bub, bubble(f, f * rng.uni(1.6, 2.6), 0.012, rng.uni(0.015, 0.04), 0.1), N(t), rng.uni(0.3, 1)); }
    t += rng.uni(0.03, 0.1);
  }
  const ck = creak(rng, {
    dur: 2.2, jitter: 0.15, burstMs: 3, noise: 0.03, noiseF: 400,
    rate: (tt) => 22 + 10 * Math.sin(Math.PI * tt / 2.2) + 4 * Math.sin(TAU * 1.7 * tt),
    amp: (tt) => Math.pow(Math.sin(Math.PI * tt / 2.2), 1.2),
    modes: [[85, 6, 1], [175, 8, 0.8], [350, 9, 0.5], [700, 7, 0.25]],
  });
  const wh = lp(white(rng, n), 250); for (let i = 0; i < n; i++) wh[i] *= MV[i];
  const sub = sineOsc(34, n); const SM = smooth(Float64Array.from(MV), 0.3); for (let i = 0; i < n; i++) sub[i] *= SM[i];
  setRms(sw, 0.1); setRms(bub, 0.05); setRms(ck, 0.08); setRms(wh, 0.06); setRms(sub, 0.06);
  const mix = buf(n); add(mix, sw); add(mix, bub); add(mix, ck, N(0.35)); add(mix, wh); add(mix, sub);
  const y = lp(reverb(mix, { size: 2.2, fb: 0.88, damp: 0.5, wet: 0.55 }), 5000);
  return fadeOut(y, 0.4);
}

function genEvil() {
  const rng = new Rng('sfx_evil'), n = 176400 /* EXATO 8.000 s */;
  // (1) pulso sub-grave 34 Hz a 2 Hz (ultimo pulso perto do fim -> termina no maximo)
  const L1 = buf(n), lastOnset = n / SR - 0.06;
  for (let i = 0; i < n; i++) {
    const t = i / SR; let ph = ((t - lastOnset) / 0.5) % 1; if (ph < 0) ph += 1;
    const tp = ph * 0.5;
    const pe = tp < 0.025 ? Math.sin(0.5 * Math.PI * tp / 0.025) : Math.exp(-(tp - 0.025) / 0.13);
    L1[i] = (Math.sin(TAU * 34 * t) + 0.35 * Math.sin(TAU * 68 * t + 0.5) + 0.12 * Math.sin(TAU * 102 * t + 1.3)) * (0.12 + 0.88 * pe);
  }
  // (2) o mesmo canto, invertido e 5 semitons abaixo
  const L2 = hp(resampleCirc(reverse(buildChant()), Math.pow(2, -5 / 12), n, N(1.8)), 45);
  // (3) rugido organico: ruido + pulsos de "vocal fry" ~30 Hz por formantes graves
  const fry = slowNoise(rng, n, 3), exc = buf(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    ph += (30 + 3 * fry[i]) / SR; if (ph >= 1) ph -= 1;
    const am = Math.pow(0.5 - 0.5 * Math.cos(TAU * ph), 2.5);
    exc[i] = rng.bi() * (0.25 + 0.75 * am) + 0.6 * (ph < 0.08 ? 1 - ph / 0.08 : 0);
  }
  const fA = new SVF(400, 4), fB = new SVF(600, 6), fC = new SVF(1300, 8), fD = new SVF(120, 2);
  let roar = buf(n);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    if ((i & 7) === 0) {
      const m = 0.5 + 0.5 * Math.sin(TAU * 0.23 * t), s = 0.55 * (1 + 0.04 * Math.sin(TAU * 1.3 * t));
      const a = (570 + 160 * m) * s, b = (840 + 250 * m) * s, c = (2410 + 30 * m) * s;
      fA.set(a, a / 90); fB.set(b, b / 110); fC.set(c, c / 160);
    }
    roar[i] = fA.tick(exc[i]) + 0.7 * fB.tick(exc[i]) + 0.35 * fC.tick(exc[i]) + 0.8 * fD.tick(exc[i]);
  }
  roar = lp(roar, 1800);
  setRms(L1, 1); setRms(L2, 1); setRms(roar, 1);
  const out = buf(n);
  for (let i = 0; i < n; i++) {
    const u = i / (n - 1);
    out[i] = 0.9 * (0.25 + 0.75 * Math.pow(u, 1.2)) * L1[i]
      + 0.75 * (0.06 + 0.94 * Math.pow(u, 0.9)) * L2[i]
      + 0.8 * (0.02 + 0.98 * Math.pow(u, 1.7)) * roar[i];
  }
  normPeak(out, 1);
  // "gain riding": forca o volume de curto prazo a seguir uma curva sempre crescente
  const win = N(0.15), ps = buf(n + 1), env = buf(n), g = buf(n);
  for (let i = 0; i < n; i++) ps[i + 1] = ps[i] + out[i] * out[i];
  for (let i = 0; i < n; i++) { const a = Math.max(0, i - win), b = Math.min(n, i + win); env[i] = Math.sqrt((ps[b] - ps[a]) / (b - a)); }
  const emax = peak(env);
  for (let i = 0; i < n; i++) {
    const target = emax * (0.06 + 0.94 * Math.pow(i / (n - 1), 1.3));
    g[i] = Math.min(3, Math.max(0.3, target / (env[i] + 1e-6)));
  }
  smooth(g, 0.04);
  for (let i = 0; i < n; i++) out[i] *= g[i];
  normPeak(out, 1);
  for (let i = 0; i < n; i++) out[i] = Math.tanh((1 + 2 * i / (n - 1)) * out[i]); // intensidade crescente
  return out; // SEM fade-out: o corte seco no final e intencional
}

function genUiPage() {
  const rng = new Rng('ui_page'), n = N(0.25);
  const env = (t) => (t < 0.11 ? Math.pow(t / 0.11, 1.6) : Math.exp(-(t - 0.11) / 0.03));
  const sw = svf(white(rng, n), 'bp', (i) => 1200 + 2600 * Math.min(1, i / N(0.12)), 0.8);
  for (let i = 0; i < n; i++) sw[i] *= env(i / SR);
  const ex = buf(n); for (let i = 0; i < n; i++) { if (rng.next() < 0.02 * env(i / SR)) ex[i] = rng.bi() * rng.next(); }
  const cr = resBank(ex, [[3000, 3, 1], [5000, 3, 0.7]]);
  const flap = buf(n); add(flap, lp(burst(rng, 0.08, 0.012), 380), N(0.115));
  setRms(sw, 0.08); setRms(cr, 0.03); setRms(flap, 0.04);
  const y = buf(n); add(y, sw); add(y, cr); add(y, flap);
  return fadeOut(lp(y, 7000), 0.03);
}

function genDiaryWrite() {
  const rng = new Rng('ui_diary_write'), n = N(0.8);
  const strokes = []; let t = 0.02;
  while (t < 0.72) { const d = rng.uni(0.05, 0.11); strokes.push([t, d, rng.uni(0.6, 1), rng.uni(1, 2.5)]); t += d + rng.uni(0.012, 0.04); }
  const E = arr(n, (i, tt) => {
    for (const [s, d, a, w] of strokes) {
      if (tt >= s && tt < s + d) {
        const u = tt - s, at = Math.min(1, u / 0.006), rl = Math.min(1, (s + d - tt) / 0.012);
        return a * at * rl * (0.75 + 0.25 * Math.sin(TAU * w * u / d));
      }
    }
    return 0;
  });
  const hiss = bp(hp(white(rng, n), 1800), 4200, 0.7); for (let i = 0; i < n; i++) hiss[i] *= E[i];
  const ex = buf(n); for (let i = 0; i < n; i++) if (rng.next() < 0.11 * E[i]) ex[i] = rng.bi() * Math.pow(rng.next(), 2);
  const grain = add(bp(ex, 3000, 2.5), bp(ex, 5500, 3), 0, 0.7);
  const body = bp(white(rng, n), 700, 2); for (let i = 0; i < n; i++) body[i] *= E[i];
  setRms(hiss, 0.05); setRms(grain, 0.05); setRms(body, 0.012);
  const y = buf(n); add(y, hiss); add(y, grain); add(y, body);
  const z = reverb(y, { size: 0.4, fb: 0.6, damp: 0.5, wet: 0.08 });
  return fadeOut(z, 0.02);
}

// ============================================================== main
const JOBS = [
  ['amb_rain_loop.wav', genRain, { loop: true }],
  ['amb_creak_1.wav', () => genCreak(1)],
  ['amb_creak_2.wav', () => genCreak(2)],
  ['amb_sea_pressure_loop.wav', genSeaPressure, { loop: true }],
  ['amb_wind_loop.wav', genWind, { loop: true }],
  ['mus_drone_low_loop.wav', genDrone, { loop: true }],
  ['mus_sting.wav', genSting],
  ['vox_chant_loop.wav', genChant, { loop: true }],
  ['vox_fhtagn.wav', genFhtagn],
  ['sfx_heartbeat.wav', genHeartbeat],
  ['sfx_drip_1.wav', () => genDrip(1)],
  ['sfx_drip_2.wav', () => genDrip(2)],
  ['sfx_drip_3.wav', () => genDrip(3)],
  ['sfx_step_wood_1.wav', () => genStepWood(1)],
  ['sfx_step_wood_2.wav', () => genStepWood(2)],
  ['sfx_step_wood_3.wav', () => genStepWood(3)],
  ['sfx_step_wood_4.wav', () => genStepWood(4)],
  ['sfx_step_stone_1.wav', () => genStepStone(1)],
  ['sfx_step_stone_2.wav', () => genStepStone(2)],
  ['sfx_step_stone_3.wav', () => genStepStone(3)],
  ['sfx_step_stone_4.wav', () => genStepStone(4)],
  ['sfx_breath_exhausted.wav', genBreath],
  ['sfx_paper_1.wav', () => genPaper(1)],
  ['sfx_paper_2.wav', () => genPaper(2)],
  ['sfx_unlock.wav', genUnlock],
  ['sfx_box_open.wav', genBoxOpen],
  ['sfx_thump_far.wav', genThumpFar],
  ['sfx_door_grind.wav', genDoorGrind],
  ['sfx_tremor_loop.wav', genTremor, { loop: true }],
  ['sfx_wet_drag.wav', genWetDrag],
  ['sfx_tentacle_move.wav', genTentacle],
  ['sfx_evil.wav', genEvil, { hpHz: 25 }],
  ['ui_page.wav', genUiPage],
  ['ui_diary_write.wav', genDiaryWrite],
];

function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const only = process.argv.slice(2);
  const t0 = Date.now();
  for (const [name, fn, opt = {}] of JOBS) {
    if (only.length && !only.some((s) => name.includes(s))) continue;
    const x = finish(fn(), { loop: !!opt.loop, hpHz: opt.hpHz == null ? 20 : opt.hpHz });
    writeWav(name, x, !!opt.loop);
    console.log(`${name.padEnd(28)} ${(x.length / SR).toFixed(3).padStart(7)} s  ${String(x.length).padStart(7)} amostras${opt.loop ? '  [loop smpl]' : ''}`);
  }
  console.log(`OK (${((Date.now() - t0) / 1000).toFixed(1)} s) -> ${OUT_DIR}`);
}
main();
