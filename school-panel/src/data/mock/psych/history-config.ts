import type { HistoryWave, IsoDate, PsychHistoryConfig, TemplateId } from '@/data/contracts';
import { previousTerms } from '@/lib/psych/terms';

/**
 * O'tgan 3 chorakdagi skrining "to'lqinlari" — natijalar saqlanmaydi, agent B ularni
 * `hash(o'quvchi, test, to'lqin)` dan deterministik hisoblaydi (localStorage ~0 KB).
 */
export function buildHistoryConfig(anchor: IsoDate, seed: number): PsychHistoryConfig {
  const terms = previousTerms(anchor, 3);
  const waves: HistoryWave[] = terms.map((term, i) => {
    const ids: TemplateId[] = ['tpl-logic', 'tpl-attention', 'tpl-emotion'];
    if (i >= 1) ids.push('tpl-self');
    if (i === terms.length - 1) ids.push('tpl-career');
    if (i === 0) ids.push('tpl-social');
    return { key: term.key, date: term.mid, testIds: ids };
  });
  return { seed, waves };
}
