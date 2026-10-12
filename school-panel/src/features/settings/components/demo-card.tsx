'use client';

import { FlaskConical, Keyboard, RotateCcw, ShieldCheck } from 'lucide-react';
import { useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useDemoReset } from '../hooks';
import { TILE } from '../styles';

export function DemoCard() {
  const { t } = useI18n();
  const reset = useDemoReset();
  const [confirm, setConfirm] = useState(false);

  return (
    <SectionCard icon={<FlaskConical />} title={t('settings.demo.title')} description={t('settings.demo.description')}>
      <div className="space-y-4">
        <p className="flex items-start gap-2 text-sm text-muted-foreground">
          <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-success" />
          {t('settings.demo.keeps')}
        </p>
        <Button variant="destructive" className="w-full" onClick={() => setConfirm(true)}>
          <RotateCcw />
          {t('demo.resetTitle')}
        </Button>
        <p className={cn('flex items-center gap-2 px-3 py-2 text-xs text-muted-foreground', TILE)}>
          <Keyboard className="h-3.5 w-3.5 shrink-0" />
          {t('settings.demo.panelHint')}
        </p>
      </div>
      <ConfirmDialog
        open={confirm}
        onOpenChange={setConfirm}
        title={t('demo.resetTitle')}
        description={t('demo.resetText')}
        confirmLabel={t('demo.resetTitle')}
        destructive
        onConfirm={() => {
          if (reset()) setConfirm(false);
        }}
      />
    </SectionCard>
  );
}
