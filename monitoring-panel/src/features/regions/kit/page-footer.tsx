'use client';

import { K_MIN } from '@/data/mock/model/engine';
import { useI18n } from '@/i18n';

/** Sahifa oxiridagi izohlar: maxfiylik, sahifaga xos qatorlar va manbalar (dashboard bilan bir xil ko'rinish). */
export function PageFooter({ notes = [] }: { notes?: readonly string[] }) {
  const { t } = useI18n();
  return (
    <footer className="space-y-1.5 rounded-2xl bg-primary/[0.04] p-4 text-[0.72rem] text-muted-foreground ring-1 ring-inset ring-border/50 dark:bg-white/[0.02]">
      <p>
        <b className="text-foreground">{t('common.privacy.title')}.</b> {t('common.privacy.text', { k: K_MIN })}
      </p>
      {notes.map((n) => (
        <p key={n}>{n}</p>
      ))}
      <p>{t('dashboard.sourcesNote')}</p>
    </footer>
  );
}
