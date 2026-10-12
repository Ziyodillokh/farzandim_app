'use client';

import { CalendarDays, ClipboardList, HeartPulse, LayoutTemplate, PartyPopper, Plane, Shuffle, Wallet, type LucideIcon } from 'lucide-react';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Skeleton } from '@/components/ui/skeleton';
import type { MessageTemplate, TemplateId } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { useTemplates } from '../hooks';

const ICONS: Record<TemplateId, LucideIcon> = {
  meeting: CalendarDays,
  exam: ClipboardList,
  event: PartyPopper,
  holiday: Plane,
  payment: Wallet,
  schedule: Shuffle,
  health: HeartPulse,
};

/** Tayyor shablonlar ro'yxati (popover). */
export function TemplatePicker({ onPick }: { onPick: (template: MessageTemplate) => void }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const templates = useTemplates();

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button type="button" variant="soft" size="sm">
          <LayoutTemplate />
          {t('messages.templates.title')}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-[min(92vw,380px)] p-2">
        <p className="px-2 pb-2 pt-1 text-xs text-muted-foreground">{t('messages.templates.hint')}</p>
        <div className="max-h-80 space-y-1 overflow-y-auto">
          {templates.isLoading && Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-14 w-full rounded-lg" />)}
          {templates.data?.map((tpl) => {
            const Icon = ICONS[tpl.id];
            return (
              <button
                key={tpl.id}
                type="button"
                onClick={() => {
                  onPick(tpl);
                  setOpen(false);
                }}
                className="flex w-full items-start gap-3 rounded-lg px-2.5 py-2 text-left transition-colors hover:bg-accent"
              >
                <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                  <Icon className="h-4 w-4" />
                </span>
                <span className="min-w-0">
                  <span className="block text-sm font-semibold">{t(`messages.templates.items.${tpl.id}`)}</span>
                  <span className="line-clamp-2 text-2xs text-muted-foreground">{tpl.body}</span>
                </span>
              </button>
            );
          })}
        </div>
      </PopoverContent>
    </Popover>
  );
}
