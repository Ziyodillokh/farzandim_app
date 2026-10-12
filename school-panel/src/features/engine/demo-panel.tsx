'use client';

import { useQueryClient } from '@tanstack/react-query';
import { Clock, HeartPulse, LogOut, Receipt, RotateCcw, Sparkles } from 'lucide-react';
import { useEffect, useState } from 'react';
import { toast } from 'sonner';

import { useCan, useSession } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { api } from '@/data/api';
import { availableTriggers, type DemoTrigger } from '@/data/mock/services/demo';
import { useI18n } from '@/i18n';

/** Taqdimot uchun yashirin panel: Ctrl + Shift + D. */
export function DemoPanel() {
  const { t } = useI18n();
  const can = useCan();
  const session = useSession();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'd') {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const fire = (kind: DemoTrigger) => {
    api.demo.trigger(kind);
    void queryClient.invalidateQueries();
    toast.info(t('demo.triggered'));
  };

  const allowed = session ? availableTriggers(session.role) : [];
  const triggers: Array<{ kind: DemoTrigger; label: string; icon: typeof Clock }> = [
    { kind: 'LATE' as const, label: t('demo.triggerLate'), icon: Clock },
    { kind: 'EARLY_EXIT' as const, label: t('demo.triggerEarlyExit'), icon: LogOut },
    { kind: 'CARE_URGENT' as const, label: t('demo.triggerCareUrgent'), icon: HeartPulse },
    { kind: 'VERIFICATION' as const, label: t('demo.triggerVerification'), icon: Receipt },
  ].filter((x) => allowed.includes(x.kind));

  return (
    <>
      <Sheet open={open} onOpenChange={setOpen}>
        <SheetContent className="w-[360px]">
          <SheetHeader>
            <SheetTitle className="flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-primary" />
              {t('demo.panelTitle')}
            </SheetTitle>
            <SheetDescription>{t('demo.panelHint')}</SheetDescription>
          </SheetHeader>
          <div className="mt-6 grid gap-2">
            {triggers.map(({ kind, label, icon: Icon }) => (
              <Button key={kind} variant="outline" className="justify-start" onClick={() => fire(kind)}>
                <Icon />
                {label}
              </Button>
            ))}
          </div>
          {can('demo.reset') && (
            <Button variant="destructive" className="mt-8 w-full" onClick={() => setConfirmReset(true)}>
              <RotateCcw />
              {t('demo.resetTitle')}
            </Button>
          )}
        </SheetContent>
      </Sheet>
      <ConfirmDialog
        open={confirmReset}
        onOpenChange={setConfirmReset}
        title={t('demo.resetTitle')}
        description={t('demo.resetText')}
        destructive
        onConfirm={() => {
          api.demo.reset();
          void queryClient.invalidateQueries();
          setConfirmReset(false);
          toast.success(t('demo.resetDone'));
        }}
      />
    </>
  );
}
