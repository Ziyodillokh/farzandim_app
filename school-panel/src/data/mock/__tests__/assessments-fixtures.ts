import type { PsychTestInput } from '@/data/schemas/assessments';

/** Psixologik testlar testlari uchun umumiy ma'lumotlar. */
export const L = (s: string) => ({ uz: s, ru: s });

export function sampleInput(overrides: Partial<PsychTestInput> = {}): PsychTestInput {
  return {
    title: L('Sinov testi'),
    description: L('Tavsif'),
    instructions: L('Ko\'rsatma'),
    kind: 'CUSTOM',
    grades: [5, 6, 7, 8],
    timeLimitMin: 10,
    scales: [{ key: 'total', label: L('Umumiy'), domain: 'REASONING', polarity: 'HIGHER_BETTER', display: 'STANDARD' }],
    items: [1, 2, 3, 4].map((n) => ({
      id: `q${n}`,
      type: 'SINGLE' as const,
      scale: 'total',
      text: L(`Savol ${n}`),
      options: [
        { key: 'a', text: L('A') },
        { key: 'b', text: L('B') },
      ],
      correct: n % 2 ? 'a' : 'b',
    })),
    scoring: { method: 'SUM' },
    norms: { total: [{ band: 'A13_14', mean: 2, sd: 1 }] },
    ...overrides,
  };
}

