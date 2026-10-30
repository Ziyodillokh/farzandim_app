/** Radar uchi (SVG koordinatalari). */
export type RadarPoint = readonly [number, number];

/**
 * Qo'shni o'qlar orasidagi kesmalar: ikkala uchi ham bor bo'lsa chiziladi —
 * qiymatsiz (`null`) o'q uzilish bo'lib qoladi, markazga (0 ga) tortilmaydi.
 */
export function openPath(vertices: ReadonlyArray<RadarPoint | null>): string {
  if (vertices.length < 2) return '';
  return vertices
    .map((a, i) => {
      const b = vertices[(i + 1) % vertices.length];
      return a && b ? `M${a[0]},${a[1]}L${b[0]},${b[1]}` : '';
    })
    .join('');
}
