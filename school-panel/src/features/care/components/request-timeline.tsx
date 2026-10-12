'use client';

import { CalendarClock, MessageCircle, NotebookPen, ShieldAlert } from 'lucide-react';
import { useState, type ReactNode } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import type { CareRequestDetail } from '@/data/mock/services/care';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useAddRequestNote } from '../hooks';

type Item = { key: string; at: string; icon: ReactNode; tone: string; title: string; text?: string };

const PROTOCOL_PREFIX = 'Himoya protokoli';

/** Murojaat tarixi va ichki eslatmalar (faqat psixolog). */
export function RequestTimeline({ request }: { request: CareRequestDetail }) {
  const { t, formatDate } = useI18n();
  const addNote = useAddRequestNote();
  const [draft, setDraft] = useState('');

  const items: Item[] = [
    { key: 'created', at: request.createdAt, icon: <MessageCircle />, tone: 'bg-primary/10 text-primary', title: t('care.request.timelineCreated') },
    ...request.notes.map((n, i) => {
      const protocol = n.text.startsWith(PROTOCOL_PREFIX);
      return {
        key: `note-${i}`,
        at: n.at,
        icon: protocol ? <ShieldAlert /> : <NotebookPen />,
        tone: protocol ? 'bg-destructive/10 text-destructive' : 'bg-muted text-muted-foreground',
        title: n.byName,
        text: n.text,
      };
    }),
    ...(request.meetingAt
      ? [{ key: 'meeting', at: request.meetingAt, icon: <CalendarClock />, tone: 'bg-info/10 text-info', title: t('care.request.timelineMeeting') }]
      : []),
  ].sort((a, b) => Date.parse(a.at) - Date.parse(b.at));

  const submit = () => {
    const text = draft.trim();
    if (!text) return;
    addNote.mutate({ id: request.id, text }, { onSuccess: () => setDraft('') });
  };

  return (
    <SectionCard title={t('care.request.timeline')}>
      <ol className="relative space-y-5 before:absolute before:bottom-2 before:left-4 before:top-2 before:w-px before:bg-border">
        {items.map((item) => (
          <li key={item.key} className="relative flex gap-3 animate-fade-in">
            <span className={cn('relative z-10 flex h-8 w-8 shrink-0 items-center justify-center rounded-full ring-4 ring-card [&_svg]:size-4', item.tone)}>
              {item.icon}
            </span>
            <div className="min-w-0 flex-1 pt-1">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                <p className="text-sm font-medium">{item.title}</p>
                <time className="text-xs tabular-nums text-muted-foreground" dateTime={item.at}>
                  {formatDate(item.at, 'd MMM, HH:mm')}
                </time>
              </div>
              {item.text && <p className="mt-1 whitespace-pre-line rounded-lg bg-muted/50 px-3 py-2 text-sm text-foreground/85">{item.text}</p>}
            </div>
          </li>
        ))}
      </ol>

      <div className="mt-6 space-y-2 border-t pt-5">
        <Textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={t('care.request.notePlaceholder')}
          rows={3}
          maxLength={1000}
          aria-label={t('care.request.addNote')}
        />
        <div className="flex justify-end">
          <Button onClick={submit} loading={addNote.isPending} disabled={!draft.trim()}>
            <NotebookPen />
            {t('care.request.addNote')}
          </Button>
        </div>
      </div>
    </SectionCard>
  );
}
