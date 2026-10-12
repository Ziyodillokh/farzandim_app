'use client';

import { useQueryClient } from '@tanstack/react-query';
import { Clock3, Database, ExternalLink, QrCode, RotateCcw, Sparkles, UsersRound, Zap } from 'lucide-react';
import { useEffect, useState, type ReactNode } from 'react';
import { toast } from 'sonner';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { api } from '@/data/api';
import { useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';
import { ClockControls } from './clock-controls';
import { setDemoPanelOpen, toggleDemoPanel, useDemoPanelOpen } from './demo-panel-store';
import { openKioskAsDuty } from './kiosk-launch';
import { RoleSwitcher } from './role-switcher';
import { TriggerList } from './trigger-list';

function PanelSection({ icon, title, hint, children }: { icon: ReactNode; title: string; hint?: string; children: ReactNode }) {
  return (
    <section className="space-y-2.5">
      <div>
        <h3 className="flex items-center gap-2 text-2xs font-semibold uppercase tracking-[0.12em] text-muted-foreground [&_svg]:size-3.5 [&_svg]:text-primary">
          {icon}
          {title}
        </h3>
        {hint && <p className="mt-1 text-xs text-muted-foreground">{hint}</p>}
      </div>
      {children}
    </section>
  );
}

/** Demo panel: rol, soat, hodisalar, kiosk va tiklash. Topbar "Demo" tugmasi yoki Ctrl + Shift + D. */
export function DemoPanel() {
  const { t } = useI18n();
  const can = useCan();
  const queryClient = useQueryClient();
  const open = useDemoPanelOpen();
  const [confirmReset, setConfirmReset] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'd') {
        e.preventDefault();
        toggleDemoPanel();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // Sahifadan chiqilganda (masalan, chiqish) panel ochiq qolmasin.
  useEffect(() => () => setDemoPanelOpen(false), []);

  const launchKiosk = () => {
    if (!openKioskAsDuty()) toast.error(t('demo.kioskBlocked'));
  };

  const reset = () => {
    try {
      api.demo.reset();
      void queryClient.invalidateQueries();
      setConfirmReset(false);
      toast.success(t('demo.resetDone'));
    } catch (error) {
      toast.error(t(errorKey(error)));
    }
  };

  return (
    <>
      <Sheet open={open} onOpenChange={setDemoPanelOpen}>
        <SheetContent className="w-[calc(100%-1rem)] gap-0 p-0 sm:w-[400px] sm:max-w-none">
          <SheetHeader className="px-5 pb-4 pt-5">
            <SheetTitle className="flex items-center gap-2 pr-8">
              <Sparkles className="h-4 w-4 text-primary" />
              {t('demo.panelTitle')}
            </SheetTitle>
            <SheetDescription>{t('demo.panelHint')}</SheetDescription>
          </SheetHeader>
          <div className="flex-1 space-y-6 overflow-y-auto overscroll-contain px-5 py-5">
            <PanelSection icon={<UsersRound />} title={t('demo.sections.roles')} hint={t('demo.rolesHint')}>
              <RoleSwitcher onSwitched={() => setDemoPanelOpen(false)} />
            </PanelSection>
            <PanelSection icon={<Clock3 />} title={t('demo.sections.clock')}>
              <ClockControls />
            </PanelSection>
            <PanelSection icon={<Zap />} title={t('demo.sections.triggers')}>
              <TriggerList />
            </PanelSection>
            <PanelSection icon={<QrCode />} title={t('demo.sections.kiosk')} hint={t('demo.kioskHint')}>
              <Button variant="outline" className="h-auto min-h-10 w-full justify-start whitespace-normal py-2 text-left" onClick={launchKiosk}>
                <QrCode className="text-primary" />
                <span>{t('demo.kioskOpen')}</span>
                <ExternalLink className="ml-auto opacity-60" />
              </Button>
            </PanelSection>
            {can('demo.reset') && (
              <PanelSection icon={<Database />} title={t('demo.sections.data')}>
                <Button variant="destructive" className="w-full" onClick={() => setConfirmReset(true)}>
                  <RotateCcw />
                  {t('demo.resetTitle')}
                </Button>
              </PanelSection>
            )}
          </div>
        </SheetContent>
      </Sheet>
      <ConfirmDialog
        open={confirmReset}
        onOpenChange={setConfirmReset}
        title={t('demo.resetTitle')}
        description={t('demo.resetText')}
        confirmLabel={t('demo.resetTitle')}
        destructive
        onConfirm={reset}
      />
    </>
  );
}
