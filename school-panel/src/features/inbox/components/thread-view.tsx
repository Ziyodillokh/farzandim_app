'use client';

import { ArrowLeft, Check, CheckCheck, RotateCcw, Send } from 'lucide-react';
import { type KeyboardEvent, useEffect, useRef, useState } from 'react';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { PARENT_REPLY_MAX, type ParentMessage, type ParentThreadDetail } from '@/data/contracts';
import { type TKey, useI18n } from '@/i18n';
import { cn, initials } from '@/lib/utils';
import { useMarkThreadRead, useReplyToThread, useSetThreadStatus } from '../hooks';
import { TopicChip } from './topic-chip';

const QUICK_REPLIES: readonly TKey[] = ['inbox.quick.received', 'inbox.quick.control', 'inbox.quick.meet', 'inbox.quick.tomorrow', 'inbox.quick.thanks'];

function Bubble({ message, guardianName }: { message: ParentMessage; guardianName: string }) {
  const { t, formatDate } = useI18n();
  const staff = message.author === 'STAFF';
  return (
    <li className={cn('flex flex-col gap-1', staff ? 'items-end' : 'items-start')} data-author={message.author} data-testid="inbox-message">
      <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
        <span className="font-medium text-foreground/80">{staff ? t('inbox.you') : guardianName}</span>
        {message.topic && !staff && <TopicChip label={t(`inbox.topics.${message.topic}` as TKey)} />}
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
        {message.body}
      </p>
      {staff && (
        <span className="flex items-center gap-1 text-2xs text-muted-foreground">
          {message.seen ? <CheckCheck className="h-3 w-3 text-primary" aria-hidden /> : <Check className="h-3 w-3" aria-hidden />}
          {t(message.seen ? 'inbox.seen' : 'inbox.sent')}
        </span>
      )}
    </li>
  );
}

/** Ota-ona ↔ xodim yozishmasi: sarlavha, xabarlar, tezkor javoblar va javob oynasi. */
export function ThreadView({ thread, onBack }: { thread: ParentThreadDetail; onBack?: () => void }) {
  const { t } = useI18n();
  const reply = useReplyToThread();
  const status = useSetThreadStatus();
  const markRead = useMarkThreadRead();
  const [draft, setDraft] = useState('');
  const logRef = useRef<HTMLOListElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const text = draft.trim();
  const count = thread.messages.length;
  const resolved = thread.status === 'RESOLVED';
  const relation = t(`inbox.relation.${thread.guardian.relation}` as TKey);
  const { mutate: markThreadRead } = markRead;

  useEffect(() => {
    const log = logRef.current;
    if (log) log.scrollTop = log.scrollHeight;
  }, [count, thread.id]);

  // Ochilganda ota-ona xabarlari o'qilgan bo'ladi (nishon va bildirishnoma yo'qoladi).
  useEffect(() => {
    if (thread.unread > 0) markThreadRead(thread.id);
  }, [thread.id, thread.unread, markThreadRead]);

  useEffect(() => setDraft(''), [thread.id]);

  const send = () => {
    if (!text || reply.isPending) return;
    reply.mutate(
      { id: thread.id, body: text },
      {
        onSuccess: () => {
          setDraft('');
          inputRef.current?.focus();
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
    <section className="flex h-full min-h-0 flex-col" aria-label={t('inbox.log')} data-testid="inbox-thread">
      <header className="flex flex-wrap items-center gap-3 border-b border-border/50 px-4 py-3.5 sm:px-5">
        {onBack && (
          <Button variant="ghost" size="icon-sm" onClick={onBack} aria-label={t('inbox.back')} className="lg:hidden">
            <ArrowLeft />
          </Button>
        )}
        <Avatar className="h-11 w-11">
          <AvatarFallback className="font-semibold">{initials(thread.guardian.fullName)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold">{t('inbox.guardianOf', { name: thread.guardian.fullName, relation })}</p>
          <p className="truncate text-sm text-muted-foreground">{t('inbox.studentLine', { name: thread.student.name, className: thread.student.className })}</p>
        </div>
        <TopicChip label={t(`inbox.status.${thread.status}` as TKey)} tone={resolved ? 'success' : 'warning'} />
        <Button
          variant={resolved ? 'outline' : 'secondary'}
          size="sm"
          loading={status.isPending}
          onClick={() => status.mutate({ id: thread.id, status: resolved ? 'OPEN' : 'RESOLVED' })}
          data-testid="inbox-status"
        >
          {resolved ? <RotateCcw /> : <CheckCheck />}
          {t(resolved ? 'inbox.reopen' : 'inbox.resolve')}
        </Button>
      </header>

      <ol
        ref={logRef}
        role="log"
        aria-label={t('inbox.log')}
        tabIndex={0}
        className="min-h-[14rem] flex-1 space-y-4 overflow-y-auto px-4 py-5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring sm:px-5"
      >
        {thread.messages.map((m) => (
          <Bubble key={m.id} message={m} guardianName={thread.guardian.fullName} />
        ))}
      </ol>

      <div className="border-t border-border/50 bg-primary/[0.03] px-4 py-4 sm:px-5" data-testid="inbox-composer">
        <div className="mb-2.5 flex flex-wrap gap-1.5" role="group" aria-label={t('inbox.quick.title')}>
          {QUICK_REPLIES.map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => {
                setDraft(t(key));
                inputRef.current?.focus();
              }}
              className="rounded-full bg-white/70 px-3 py-1 text-xs font-medium text-foreground/80 ring-1 ring-inset ring-border/70 transition-colors hover:bg-primary/10 hover:text-primary hover:ring-primary/30 dark:bg-white/[0.05]"
            >
              {t(key)}
            </button>
          ))}
        </div>
        <Label htmlFor="inbox-reply" className="sr-only">
          {t('inbox.reply.title')}
        </Label>
        <Textarea
          id="inbox-reply"
          ref={inputRef}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={onKeyDown}
          placeholder={t('inbox.reply.placeholder')}
          rows={3}
          maxLength={PARENT_REPLY_MAX}
          aria-describedby="inbox-reply-hint"
        />
        <div className="mt-2 flex flex-wrap items-center justify-between gap-2">
          <p id="inbox-reply-hint" className="text-xs text-muted-foreground">
            {resolved ? t('inbox.reply.resolvedNote') : t('inbox.reply.hint')} · {t('inbox.reply.shortcut')}
          </p>
          <Button onClick={send} loading={reply.isPending} disabled={!text} data-testid="inbox-send">
            <Send />
            {t('inbox.reply.send')}
          </Button>
        </div>
      </div>
    </section>
  );
}
