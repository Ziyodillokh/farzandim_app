'use client';

import { ArrowUpRight, CalendarClock, CheckCircle2, Eye, EyeOff, History, MessageCircle, NotebookPen, Reply, ShieldAlert } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import type { CareRequestDetail } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { TILE } from '@/features/dashboard/lib/tile';
import { cn } from '@/lib/utils';
import { useAddRequestNote } from '../hooks';

type Item = { key: string; at: string; icon: ReactNode; tone: string; title: string; text?: string; internal?: boolean };

const PROTOCOL_PREFIX = 'Himoya protokoli';
const NOTE_MAX = 1000;

/**
 * Murojaat tarixi: qabul qilindi → ochildi (kim) → birinchi javob → o'rinbosarga o'tdi → yopildi, suhbat va ichki
 * eslatmalar. Ichki eslatma BOLAGA KO'RINMAYDI — yozish oynasi va yozuvlar «Bola ko'rmaydi» nishoni bilan ajratilgan.
 */
export function RequestTimeline({ request }: { request: CareRequestDetail }) {
  const { t, formatDate } = useI18n();
  const addNote = useAddRequestNote();
  const [draft, setDraft] = useState('');

  const milestones: Item[] = [
    { key: 'created', at: request.createdAt, icon: <MessageCircle />, tone: 'bg-primary/10 text-primary', title: t('care.request.timelineCreated') },
    ...(request.openedAt
      ? [
          {
            key: 'opened',
            at: request.openedAt,
            icon: <Eye />,
            tone: 'bg-sky-500/10 text-sky-600 dark:text-sky-300',
            title: request.openedBy ? t('care.request.timelineOpened', { name: request.openedBy.name }) : t('care.request.timelineOpenedUnknown'),
          },
        ]
      : []),
    ...(request.repliedAt
      ? [{ key: 'replied', at: request.repliedAt, icon: <Reply />, tone: 'bg-primary/10 text-primary', title: t('care.request.timelineReplied') }]
      : []),
    ...(request.escalatedAt
      ? [
          {
            key: 'escalated',
            at: request.escalatedAt,
            icon: <ArrowUpRight />,
            tone: 'bg-warning/10 text-warning',
            title: t('care.request.timelineEscalated', { name: request.assignedTo?.name ?? '—' }),
          },
        ]
      : []),
    ...(request.meetingAt
      ? [{ key: 'meeting', at: request.meetingAt, icon: <CalendarClock />, tone: 'bg-info/10 text-info', title: t('care.request.timelineMeeting') }]
      : []),
    ...(request.resolvedAt
      ? [{ key: 'resolved', at: request.resolvedAt, icon: <CheckCircle2 />, tone: 'bg-success/10 text-success', title: t('care.request.timelineResolved') }]
      : []),
  ];
  const notes: Item[] = request.notes.map((n, i) => {
    const protocol = n.text.startsWith(PROTOCOL_PREFIX);
    return {
      key: `note-${i}`,
      at: n.at,
      icon: protocol ? <ShieldAlert /> : <NotebookPen />,
      tone: protocol ? 'bg-destructive/10 text-destructive' : 'bg-muted text-muted-foreground',
      title: n.byName,
      text: n.text,
      internal: true,
    };
  });
  const items = [...milestones, ...notes].sort((a, b) => Date.parse(a.at) - Date.parse(b.at));

  const submit = () => {
    const text = draft.trim();
    if (!text) return;
    addNote.mutate({ id: request.id, text }, { onSuccess: () => setDraft('') });
  };

  return (
    <SectionCard title={t('care.request.timeline')} icon={<History />}>
      <ol className="relative space-y-5 before:absolute before:bottom-2 before:left-4 before:top-2 before:w-px before:bg-border/70">
        {items.map((item) => (
          <li key={item.key} className="relative flex gap-3 animate-fade-in" data-timeline={item.internal ? 'note' : item.key}>
            <span className={cn('relative z-10 flex h-8 w-8 shrink-0 items-center justify-center rounded-full ring-4 ring-background [&_svg]:size-4', item.tone)}>
              {item.icon}
            </span>
            <div className="min-w-0 flex-1 pt-1">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                <p className="flex flex-wrap items-center gap-2 text-sm font-medium">
                  {item.title}
                  {item.internal && (
                    <Badge variant="secondary" size="sm">
                      <EyeOff className="h-3 w-3" aria-hidden />
                      {t('care.request.internal.badge')}
                    </Badge>
                  )}
                </p>
                <time className="text-xs tabular-nums text-muted-foreground" dateTime={item.at}>
                  {formatDate(item.at, 'd MMM, HH:mm')}
                </time>
              </div>
              {item.text && <p className={cn(TILE, 'mt-1.5 whitespace-pre-line border-dashed px-3 py-2 text-sm text-foreground/85')}>{item.text}</p>}
            </div>
          </li>
        ))}
      </ol>

      <div className="mt-6 space-y-2 rounded-2xl border border-dashed border-border bg-muted/40 p-4" data-testid="note-composer">
        <div className="flex flex-wrap items-center gap-2">
          <Label htmlFor="care-note" className="text-sm font-semibold">
            {t('care.request.internal.title')}
          </Label>
          <Badge variant="secondary" size="sm">
            <EyeOff className="h-3 w-3" aria-hidden />
            {t('care.request.internal.badge')}
          </Badge>
        </div>
        <p id="care-note-hint" className="text-xs text-muted-foreground">
          {t('care.request.internal.hint')}
        </p>
        <Textarea
          id="care-note"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={t('care.request.notePlaceholder')}
          rows={3}
          maxLength={NOTE_MAX}
          aria-describedby="care-note-hint"
        />
        <div className="flex justify-end">
          <Button variant="outline" onClick={submit} loading={addNote.isPending} disabled={!draft.trim()} data-testid="note-add">
            <NotebookPen />
            {t('care.request.addNote')}
          </Button>
        </div>
      </div>
    </SectionCard>
  );
}
