import { hashString, Random } from '@/lib/rng';

/**
 * Demo uchun "daftar sahifasi surati": yacheykali qog'oz, chap chetida qizil chiziq va ko'k siyoh
 * bilan yozilgan matn o'xshashi — deterministik (rasm identifikatoridan). Haqiqiy rejimda bola
 * rasmlari backenddan imzolangan havola bilan keladi; bu faqat mock.
 */

const WIDTH = 600;
const HEIGHT = 800;
const CELL = 32;
const MARGIN_X = 64;
const INK = '#1e3a8a';
const GRID = '#bfd0ea';

/** Bitta "so'z": mayda tebranishli siyoh chizig'i (harflar balandligini taqlid qiladi). */
function word(rng: Random, x: number, y: number, width: number): string {
  const points: string[] = [`M${x.toFixed(1)} ${y.toFixed(1)}`];
  for (let dx = 6; dx <= width; dx += rng.int(5, 9)) {
    const rise = rng.bool(0.28) ? rng.int(9, 15) : rng.int(2, 7);
    points.push(`L${(x + dx - 3).toFixed(1)} ${(y - rise).toFixed(1)}`, `L${(x + dx).toFixed(1)} ${(y + rng.int(-1, 2)).toFixed(1)}`);
  }
  return points.join(' ');
}

const cache = new Map<string, string>();

export function notebookPhotoUrl(photoId: string): string {
  const hit = cache.get(photoId);
  if (hit) return hit;
  const rng = new Random(hashString(photoId));
  const rows = Math.floor((HEIGHT - 2 * CELL) / CELL);
  const parts: string[] = [];
  for (let y = CELL; y < HEIGHT; y += CELL) parts.push(`<line x1="0" y1="${y}" x2="${WIDTH}" y2="${y}" stroke="${GRID}" stroke-width="1"/>`);
  for (let x = CELL; x < WIDTH; x += CELL) parts.push(`<line x1="${x}" y1="0" x2="${x}" y2="${HEIGHT}" stroke="${GRID}" stroke-width="1"/>`);
  parts.push(`<line x1="${MARGIN_X}" y1="0" x2="${MARGIN_X}" y2="${HEIGHT}" stroke="#e11d48" stroke-opacity="0.55" stroke-width="2"/>`);
  const filled = rng.int(Math.floor(rows * 0.45), Math.floor(rows * 0.85));
  for (let row = 0; row < filled; row++) {
    const y = CELL * (row + 2) - 7;
    let x = MARGIN_X + 14 + (row === 0 ? 120 : 0);
    while (x < WIDTH - 48) {
      const w = rng.int(28, 96);
      if (x + w > WIDTH - 36) break;
      parts.push(`<path d="${word(rng, x, y, w)}" fill="none" stroke="${INK}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.88"/>`);
      x += w + rng.int(12, 22);
    }
  }
  const tilt = (rng.float() - 0.5) * 2.4;
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${WIDTH} ${HEIGHT}" width="${WIDTH}" height="${HEIGHT}">` +
    `<defs><radialGradient id="v" cx="50%" cy="45%" r="75%"><stop offset="60%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#1f2937" stop-opacity="0.32"/></radialGradient></defs>` +
    `<rect width="${WIDTH}" height="${HEIGHT}" fill="#33415c"/>` +
    `<g transform="rotate(${tilt.toFixed(2)} ${WIDTH / 2} ${HEIGHT / 2}) scale(0.96) translate(12 16)"><rect width="${WIDTH}" height="${HEIGHT}" fill="#fcfaf3"/>${parts.join('')}</g>` +
    `<rect width="${WIDTH}" height="${HEIGHT}" fill="url(#v)"/></svg>`;
  const url = `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
  cache.set(photoId, url);
  return url;
}
