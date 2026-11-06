'use client';

import { Eye, MessagesSquare, Send } from 'lucide-react';
import { type KeyboardEvent, useEffect, useRef, useState } from 'react';

import { SectionCard } from '@/components/common/section-card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import type { CareMessage, CareRequestDetail } from '@/data/contracts';
import { CARE_REPLY_MAX } from '@/data/schemas/care';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useReplyToRequest } from '../hooks';

function Bubble({ message }: { message: CareMessage }) {
  const { t, formatDate } = useI18n();
  const staff = message.author === 'STAFF';
  return (
    <li className={cn('flex flex-col gap-1', staff ? 'items-end' : 'items-start')} data-author={message.author} data-testid="thread-message">
      <div className="flex flex-wrap items-baseline gap-x-2 text-xs text-muted-foreground">
        <span className="font-medium text-foreground/80">{staff ? (message.authorName ?? t('enums.role.PSYCHOLOGIST')) : t('care.request.thread.child')}</span>
        <time dateTime={message.createdAt} className="tabular-nums">
          {formatDate(message.createdAt, 'd MMM, HH:mm')}
        </time>
      </div>
      <p
        className={cn(
          'max-w-[85%] whitespace-pre-line break-words rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed ring-1 ring-inset',
          staff ? 'rounded-tr-md bg-primary/10 text-foreground ring-primary/25' : 'rounded-tl-md bg-white/60 text-foreground/90 ring-border/60 dark:bg-white/[0.05]',
        )}
      >
        {message.text}
      </p>
      {staff && (
        <span className="flex items-center gap-1 text-2xs text-muted-foreground">
          <Eye className="h-3 w-3" aria-hidden />
          {t('care.request.thread.sentToChild')}
        </span>
      )}
    </li>
  );
}

/**
 * Bola ↔ psixolog yozishmasi va «Bolaga javob» yozish oynasi. Javob BOLAGA ko'rinadi — ichki eslatmadan
 * (`RequestTimeline`dagi alohida yozish oynasi) ko'rinishi, yorlig'i va nishoni bilan aniq ajratilgan.
 */
export function RequestThread({ request }: { request: CareRequestDetail }) {
  const { t } = useI18n();
  const reply = useReplyToRequest();
  const [draft, setDraft] = useState('');
  const logRef = useRef<HTMLOListElement>(null);
  const replyRef = useRef<HTMLTextAreaElement>(null);
  const closed = request.status === 'RESOLVED';
  const text = draft.trim();
  const count = request.messages.length;

  // Yangi xabar kelsa (yoki sahifa ochilsa) ro'yxat oxiriga o'tadi.
  useEffect(() => {
    const log = logRef.current;
    if (log) log.scrollTop = log.scrollHeight;
  }, [count]);

  const send = () => {
    if (!text || closed || reply.isPending) return;
    reply.mutate(
      { id: request.id, text },
      {
        onSuccess: () => {
          setDraft('');
          // Yuborish tugmasi bajarilayotganda o'chiriladi — fokus yo'qolmasin, keyingi xabarni yozish davom etsin.
          replyRef.current?.focus();
        },
      },
    );
  };
  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      send();
    }
  };

  return (
    <SectionCard title={t('care.request.thread.title')} description={t('care.request.thread.hint')} icon={<MessagesSquare />}>
      <ol
        ref={logRef}
        role="log"
        aria-label={t('care.request.thread.log')}
        tabIndex={0}
        className="max-h-[26rem] space-y-4 overflow-y-auto rounded-xl p-1 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      >
        {request.messages.map((m) => (
          <Bubble key={m.id} message={m} />
        ))}
      </ol>

      <div className="mt-5 rounded-2xl bg-primary/[0.05] p-4 ring-2 ring-inset ring-primary/30" data-testid="reply-composer">
        <div className="mb-2 flex flex-wrap items-center gap-2">
          <Label htmlFor="care-reply" className="text-sm font-semibold">
            {t('care.request.reply.title')}
          </Label>
          <Badge variant="default" size="sm">
            <Eye className="h-3 w-3" aria-hidden />
            {t('care.request.reply.badge')}
          </Badge>
        </div>
        {closed ? (
          <p role="note" className="rounded-xl bg-muted/60 px-3 py-2.5 text-sm text-muted-foreground">
            {t('care.request.reply.closed')}
          </p>
        ) : (
          <>
            <p id="care-reply-hint" className="mb-2 text-xs text-muted-foreground">
              {t('care.request.reply.hint')}
            </p>
            <Textarea
              id="care-reply"
              ref={replyRef}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={onKeyDown}
              placeholder={t('care.request.reply.placeholder')}
              rows={3}
              maxLength={CARE_REPLY_MAX}
              aria-describedby="care-reply-hint care-reply-count"
            />
            <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
              <p id="care-reply-count" className="text-xs tabular-nums text-muted-foreground">
                {t('care.request.reply.counter', { count: draft.length, max: CARE_REPLY_MAX })} · {t('care.request.reply.shortcut')}
              </p>
              <Button onClick={send} loading={reply.isPending} disabled={!text} data-testid="reply-send">
                <Send />
                {t('care.request.reply.send')}
              </Button>
            </div>
          </>
        )}
      </div>
    </SectionCard>
  );
}
