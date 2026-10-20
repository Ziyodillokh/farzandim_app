import { describe, expect, it } from 'vitest';

import type { PsychItem, PsychTest } from '@/data/contracts';
import { psychTestInputSchema } from '@/data/schemas/assessments';
import { maxRaw, minRaw } from '@/lib/psych/scoring';
import { portableTest } from '../services/assessments-import';
import { PSYCH_TEMPLATES } from '../seed/psych-templates';
import { TEMPLATE_IDS, TEMPLATE_SPECS } from '../seed/psych-templates/specs';

const BANNED = ['aqli zaif', 'nuqson', 'kasal', 'депрессия', 'расстройство', 'отстал'];

function texts(test: PsychTest): string[] {
  const out = [test.title.uz, test.title.ru, test.description.uz, test.description.ru, test.instructions.uz, test.instructions.ru];
  for (const item of test.items) {
    out.push(item.text.uz, item.text.ru);
    if (item.type !== 'LIKERT') for (const o of item.options) out.push(o.text.uz, o.text.ru);
    if (item.type === 'SINGLE' && item.stimulus) out.push(item.stimulus.text.uz, item.stimulus.text.ru);
  }
  return out;
}

const countType = (items: readonly PsychItem[], type: PsychItem['type']) => items.filter((i) => i.type === type).length;

describe('Psixologik test shablonlari', () => {
  it.each(TEMPLATE_IDS)('%s: har shkala xom ball oralig\'i spetsifikatsiyaga mos', (id) => {
    const test = PSYCH_TEMPLATES[id];
    const spec = TEMPLATE_SPECS[id];
    for (const scale of spec.scales) {
      const range = spec.ranges[scale.key];
      expect(range, scale.key).toBeDefined();
      expect(maxRaw(test, scale.key), `${id}/${scale.key} max`).toBe(range?.max);
      expect(minRaw(test, scale.key), `${id}/${scale.key} min`).toBe(range?.min);
    }
  });

  it('savol soni va turlari talabga mos', () => {
    const t = PSYCH_TEMPLATES;
    expect(countType(t['tpl-logic'].items, 'SINGLE')).toBe(16);
    expect(t['tpl-attention'].items.filter((i) => i.type === 'SINGLE' && i.scale === 'attention')).toHaveLength(7);
    expect(t['tpl-attention'].items.filter((i) => i.type === 'SINGLE' && i.scale === 'memory' && i.stimulus)).toHaveLength(7);
    expect(countType(t['tpl-emotion'].items, 'LIKERT')).toBe(12);
    expect(t['tpl-emotion'].items.filter((i) => i.type === 'LIKERT' && i.scale === 'mood' && i.reverse)).toHaveLength(2);
    expect(t['tpl-self'].items.filter((i) => i.type === 'LIKERT' && i.reverse)).toHaveLength(4);
    expect(t['tpl-social'].items.filter((i) => i.type === 'LIKERT' && i.reverse)).toHaveLength(2);
    expect(countType(t['tpl-career'].items, 'MULTI')).toBe(12);
  });

  it('kasbiy qiziqish: 12×3 variant, har yo\'nalish aynan 6 marta', () => {
    const counts = new Map<string, number>();
    for (const item of PSYCH_TEMPLATES['tpl-career'].items) {
      if (item.type !== 'MULTI') throw new Error('MULTI expected');
      expect(item.options).toHaveLength(3);
      expect(new Set(item.options.map((o) => o.scale)).size).toBe(3);
      for (const o of item.options) counts.set(o.scale, (counts.get(o.scale) ?? 0) + 1);
    }
    expect(Object.fromEntries(counts)).toEqual({ R: 6, I: 6, A: 6, S: 6, E: 6, C: 6 });
  });

  it.each(TEMPLATE_IDS)('%s: ID\'lar noyob, matnlar to\'liq, to\'g\'ri javob variantlar ichida', (id) => {
    const test = PSYCH_TEMPLATES[id];
    expect(new Set(test.items.map((i) => i.id)).size).toBe(test.items.length);
    const scaleKeys = new Set(test.scales.map((s) => s.key));
    for (const text of texts(test)) expect(text.trim().length).toBeGreaterThan(0);
    expect(test.timeLimitMin).toBe(TEMPLATE_SPECS[id].timeLimitMin);
    for (const item of test.items) {
      if (item.type === 'SINGLE') {
        expect(item.options).toHaveLength(4);
        expect(item.options.map((o) => o.key)).toContain(item.correct);
        expect(new Set(item.options.map((o) => o.key)).size).toBe(item.options.length);
      }
      if (item.type === 'MULTI') for (const o of item.options) expect(scaleKeys.has(o.scale)).toBe(true);
      else expect(scaleKeys.has(item.scale)).toBe(true);
    }
  });

  it.each(TEMPLATE_IDS)('%s: stigmatizatsiya qiluvchi so\'zlar yo\'q', (id) => {
    const all = texts(PSYCH_TEMPLATES[id]).join(' ').toLowerCase();
    for (const word of BANNED) expect(all).not.toContain(word);
  });

  it.each(TEMPLATE_IDS)('%s: eksport shakli import sxemasidan o\'tadi', (id) => {
    const result = psychTestInputSchema.safeParse(portableTest(PSYCH_TEMPLATES[id]));
    expect(result.success, JSON.stringify(result.error?.issues[0])).toBe(true);
  });
});
