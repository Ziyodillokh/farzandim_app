import type { PsychTest, TemplateId } from '@/data/contracts';
import { TEMPLATE_IDS, TEMPLATE_SPECS } from './specs';

/**
 * Tayyor test shablonlari. P1 — vaqtinchalik: faqat spetsifikatsiya (savollarsiz);
 * savollar kontenti agent A tomonidan alohida fayllarda qo'shiladi.
 */
function fromSpec(id: TemplateId): PsychTest {
  const spec = TEMPLATE_SPECS[id];
  return {
    id,
    title: spec.title,
    description: { uz: '', ru: '' },
    instructions: { uz: '', ru: '' },
    kind: spec.kind,
    source: 'TEMPLATE',
    grades: spec.grades,
    timeLimitMin: spec.timeLimitMin,
    scales: spec.scales,
    items: [],
    scoring: { method: 'PER_SCALE' },
    norms: spec.norms,
    version: 1,
    status: 'PUBLISHED',
    createdBy: null,
    updatedAt: '2026-09-01T09:00:00',
    basedOn: null,
  };
}

export const PSYCH_TEMPLATES: Readonly<Record<TemplateId, PsychTest>> = Object.fromEntries(
  TEMPLATE_IDS.map((id) => [id, fromSpec(id)]),
) as Record<TemplateId, PsychTest>;
