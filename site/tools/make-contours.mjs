// Генерира assets/img/contours.svg: вложени контурни линии, които се събират в една точка.
// Идея: много възможни значения -> едно. Употреба: node tools/make-contours.mjs
import { writeFileSync } from 'node:fs';

const W = 900, H = 900, CX = 450, CY = 450;
const RINGS = 26;

// Детерминиран шум (без Math.random), за да е резултатът един и същ при всяко пускане.
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
const rand = rng(20260);
const harmonics = Array.from({ length: 5 }, (_, i) => ({ k: i + 2, a: 0.16 / (i + 1.2), p: rand() * Math.PI * 2 }));

function ringPath(r, t) {
  const N = 56, pts = [];
  for (let i = 0; i < N; i++) {
    const th = (i / N) * Math.PI * 2;
    let m = 0;
    for (const h of harmonics) m += h.a * Math.sin(h.k * th + h.p + t * 1.6);
    const rr = r * (1 + m * (0.35 + 0.65 * t));   // външните линии са по-неправилни
    pts.push([CX + rr * Math.cos(th) * 1.05, CY + rr * Math.sin(th) * 0.92]);
  }
  // затворена гладка крива (Catmull-Rom -> Bézier)
  let d = `M${pts[0][0].toFixed(1)} ${pts[0][1].toFixed(1)}`;
  for (let i = 0; i < N; i++) {
    const p0 = pts[(i - 1 + N) % N], p1 = pts[i], p2 = pts[(i + 1) % N], p3 = pts[(i + 2) % N];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += `C${c1[0].toFixed(1)} ${c1[1].toFixed(1)} ${c2[0].toFixed(1)} ${c2[1].toFixed(1)} ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`;
  }
  return d + 'Z';
}

let paths = '';
for (let i = 0; i < RINGS; i++) {
  const t = i / (RINGS - 1);
  const r = 26 + t * 400;
  const op = (1 - 0.62 * t).toFixed(2);
  const sw = (2.1 - 0.9 * t).toFixed(2);
  paths += `<path d="${ringPath(r, t)}" stroke-opacity="${op}" stroke-width="${sw}"/>`;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" fill="none" role="img" aria-label="Контурни линии, които се събират в една точка">
<defs>
<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="60" y1="120" x2="840" y2="800">
<stop offset="0" stop-color="#38BDF8"/><stop offset="0.5" stop-color="#6D7CFF"/><stop offset="1" stop-color="#B07CFF"/>
</linearGradient>
<radialGradient id="c"><stop offset="0" stop-color="#fff"/><stop offset="0.35" stop-color="#8FDBFF"/><stop offset="1" stop-color="#38BDF8" stop-opacity="0"/></radialGradient>
</defs>
<g stroke="url(#g)">${paths}</g>
<circle cx="${CX}" cy="${CY}" r="34" fill="url(#c)" opacity="0.9"/>
<circle cx="${CX}" cy="${CY}" r="6" fill="#fff"/>
</svg>
`;
writeFileSync(new URL('../assets/img/contours.svg', import.meta.url), svg);
console.log('contours.svg', svg.length, 'bytes');
