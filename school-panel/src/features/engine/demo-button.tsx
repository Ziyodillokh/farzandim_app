'use client';

import { FlaskConical } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { setDemoPanelOpen, useDemoPanelOpen } from './demo-panel-store';

/** Topbardagi ko'rinadigan "Demo" tugmasi — demo panelni ochadi (mobil: faqat ikonka). */
export function DemoButton() {
  const { t } = useI18n();
  const open = useDemoPanelOpen();
  return (
    <Button
      variant="soft"
      size="sm"
      className="h-10 w-10 rounded-xl px-0 sm:w-auto sm:px-3"
      onClick={() => setDemoPanelOpen(true)}
      aria-label={t('demo.button')}
      aria-haspopup="dialog"
      aria-expanded={open}
      title={t('demo.buttonHint')}
    >
      <FlaskConical />
      <span className="hidden sm:inline">{t('demo.button')}</span>
    </Button>
  );
}
