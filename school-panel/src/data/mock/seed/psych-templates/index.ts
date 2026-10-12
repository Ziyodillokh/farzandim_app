/**
 * Original demo content written for Parvoz. Not derived from any published instrument. Demo norms are synthetic.
 *
 * Tayyor test shablonlari: spetsifikatsiya (shkalalar, me'yorlar) + savollar kontenti.
 */
import type { PsychTest, TemplateId } from '@/data/contracts';
import { ATTENTION_MEMORY } from './attention-memory';
import type { TemplateContent } from './build';
import { CAREER } from './career';
import { EMOTION } from './emotion';
import { LOGIC } from './logic';
import { SELF_ESTEEM } from './self-esteem';
import { SOCIAL } from './social';
import { TEMPLATE_IDS, TEMPLATE_SPECS } from './specs';

const CONTENT: Record<TemplateId, TemplateContent> = {
  'tpl-logic': LOGIC,
  'tpl-attention': ATTENTION_MEMORY,
  'tpl-emotion': EMOTION,
  'tpl-self': SELF_ESTEEM,
  'tpl-career': CAREER,
  'tpl-social': SOCIAL,
};

function fromSpec(id: TemplateId): PsychTest {
  const spec = TEMPLATE_SPECS[id];
  const content = CONTENT[id];
  return {
    id,
    title: spec.title,
    description: content.description,
    instructions: content.instructions,
    kind: spec.kind,
    source: 'TEMPLATE',
    grades: spec.grades,
    timeLimitMin: spec.timeLimitMin,
    scales: spec.scales,
    items: content.items,
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
