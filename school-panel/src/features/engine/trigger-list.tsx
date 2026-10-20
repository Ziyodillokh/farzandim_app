'use client';

import { useQueryClient } from '@tanstack/react-query';
import { Brain, Clock, HeartPulse, ListChecks, LogOut, type LucideIcon, Receipt } from 'lucide-react';
import { toast } from 'sonner';

import { useSession } from '@/auth/use-session';
import { Button } from '@/components/ui/button';
import { api } from '@/data/api';
import { availableTriggers, type DemoTrigger, type DemoTriggerResult } from '@/data/mock/services/demo';
import { type TKey, useI18n } from '@/i18n';
import { errorKey } from '@/lib/errors';

const TRIGGERS: ReadonlyArray<{ kind: DemoTrigger; label: TKey; icon: LucideIcon }> = [
  { kind: 'LATE', label: 'demo.triggerLate', icon: Clock },
  { kind: 'EARLY_EXIT', label: 'demo.triggerEarlyExit', icon: LogOut },
  { kind: 'CARE_URGENT', label: 'demo.triggerCareUrgent', icon: HeartPulse },
  { kind: 'VERIFICATION', label: 'demo.triggerVerification', icon: Receipt },
  { kind: 'SURVEY_RESPONSES', label: 'demo.triggerSurveyResponses', icon: ListChecks },
  { kind: 'TEST_COMPLETIONS', label: 'demo.triggerTestCompletions', icon: Brain },
];

/** Taqdimot paytida hodisa chaqirish — faqat joriy rol ko'ra oladiganlari. */
export function TriggerList() {
  const { t } = useI18n();
  const session = useSession();
  const queryClient = useQueryClient();
  const allowed = session ? availableTriggers(session.role) : [];
  const items = TRIGGERS.filter((x) => allowed.includes(x.kind));

  const report = (result: DemoTriggerResult) => {
    if (result.count === null) {
      toast.info(t('demo.triggered'));
      return;
    }
    if (result.count === 0) {
      toast.info(t('demo.nothingNew'));
      return;
    }
    const key = result.kind === 'SURVEY_RESPONSES' ? 'demo.newResponses' : 'demo.newResults';
    toast.success(t(key, { count: result.count }));
  };

  const fire = (kind: DemoTrigger) => {
    try {
      report(api.demo.trigger(kind));
      void queryClient.invalidateQueries();
    } catch (error) {
      toast.error(t(errorKey(error)));
    }
  };

  if (items.length === 0) return <p className="text-sm text-muted-foreground">{t('demo.triggersEmpty')}</p>;

  return (
    <div className="grid gap-2">
      {items.map(({ kind, label, icon: Icon }) => (
        <Button key={kind} variant="outline" className="justify-start" onClick={() => fire(kind)}>
          <Icon className="text-primary" />
          {t(label)}
        </Button>
      ))}
    </div>
  );
}
