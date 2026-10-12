'use client';

import { Copy, Pencil, Send, Trash2 } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useState, type ReactNode } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { ErrorState } from '@/components/common/error-state';
import { MessageStatusBadge } from '@/components/common/status-badges';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetDescription, SheetFooter, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Skeleton } from '@/components/ui/skeleton';
import type { AnnouncementDetail } from '@/data/mock/services/comms';
import { useI18n } from '@/i18n';
import { useAnnouncement, useDuplicateAnnouncement, useRemoveAnnouncement, useSendNow } from '../hooks';
import { AudienceChips } from './audience-chips';
import { DeliveryStats } from './delivery-stats';
import { MessagePhonePreview } from './message-preview';
import { RecipientsSummary } from './recipients-summary';

type Confirm = 'delete' | 'send' | null;

/** Xabar tafsiloti: statistika, qamrov, telefon maketida ko'rinish va amallar. */
export function AnnouncementSheet({ id, onOpenChange }: { id: string | null; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const query = useAnnouncement(id);
  const a = query.data;

  return (
    <Sheet open={Boolean(id)} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle className="pr-8">{a?.title ?? t('messages.detail.title')}</SheetTitle>
          <SheetDescription className="sr-only">{t('messages.detail.title')}</SheetDescription>
          {a && (
            <div className="flex flex-wrap items-center gap-2 pt-1">
              <MessageStatusBadge status={a.status} />
              <Badge variant={a.priority === 'IMPORTANT' ? 'warning' : 'secondary'}>{t(`enums.messagePriority.${a.priority}`)}</Badge>
            </div>
          )}
        </SheetHeader>
        {query.isError && <ErrorState error={query.error} onRetry={() => void query.refetch()} />}
        {!a && query.isLoading && (
          <div className="space-y-4 p-6">
            <Skeleton className="h-6 w-2/3" />
            <Skeleton className="h-24 w-full" />
            <Skeleton className="h-64 w-full" />
          </div>
        )}
        {a && <DetailBody a={a} />}
        {a && <DetailActions a={a} onClose={() => onOpenChange(false)} />}
      </SheetContent>
    </Sheet>
  );
}

function DetailBody({ a }: { a: AnnouncementDetail }) {
  const { t, formatDate } = useI18n();
  const when = a.sentAt ?? a.scheduledAt;
  return (
    <div className="grid gap-6 p-6 lg:grid-cols-[1fr_auto]">
      <div className="min-w-0 space-y-5">
        <Field label={t('messages.detail.audience')}>
          <AudienceChips kind={a.audience.kind} names={a.audienceNames} max={12} />
        </Field>
        <div className="grid grid-cols-2 gap-4">
          <Field label={t('messages.detail.author')}>
            <p className="text-sm font-medium">{a.authorName}</p>
          </Field>
          <Field label={t('messages.detail.when')}>
            <p className="text-sm font-medium tabular-nums">{when ? formatDate(when, 'd MMMM yyyy, HH:mm') : '—'}</p>
          </Field>
        </div>
        {a.status === 'SENT' && (
          <Field label={t('messages.detail.stats')}>
            <DeliveryStats stats={a.stats} />
            <p className="mt-2 text-2xs text-muted-foreground">{t('messages.detail.readHint')}</p>
          </Field>
        )}
        <Field label={t('messages.detail.reach')}>
          <RecipientsSummary reach={a.reach} />
        </Field>
        <p className="whitespace-pre-line rounded-xl bg-muted/50 p-4 text-sm leading-relaxed">{a.body}</p>
      </div>
      <div className="space-y-2">
        <p className="text-center text-xs font-medium text-muted-foreground">{t('messages.detail.preview')}</p>
        <MessagePhonePreview title={a.title} body={a.body} important={a.priority === 'IMPORTANT'} className="w-[260px]" />
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div>
      <p className="mb-2 text-2xs font-semibold uppercase tracking-wider text-muted-foreground">{label}</p>
      {children}
    </div>
  );
}

function DetailActions({ a, onClose }: { a: AnnouncementDetail; onClose: () => void }) {
  const { t } = useI18n();
  const router = useRouter();
  const [confirm, setConfirm] = useState<Confirm>(null);
  const duplicate = useDuplicateAnnouncement();
  const remove = useRemoveAnnouncement();
  const sendNow = useSendNow();

  const onDuplicate = async () => {
    const copy = await duplicate.mutateAsync(a.id);
    onClose();
    router.push(`/messages/new?id=${copy.id}`);
  };
  const onConfirm = async () => {
    if (confirm === 'delete') await remove.mutateAsync(a.id);
    if (confirm === 'send') await sendNow.mutateAsync(a.id);
    setConfirm(null);
    if (confirm === 'delete') onClose();
  };

  return (
    <SheetFooter className="flex-wrap gap-2 sm:justify-between">
      <Button variant="outline" onClick={() => void onDuplicate().catch(() => undefined)} loading={duplicate.isPending}>
        <Copy />
        {t('messages.actions.duplicate')}
      </Button>
      {a.canManage && (
        <div className="flex flex-wrap gap-2">
          <Button variant="ghost" className="text-destructive hover:text-destructive" onClick={() => setConfirm('delete')}>
            <Trash2 />
            {t('messages.actions.delete')}
          </Button>
          <Button variant="outline" onClick={() => router.push(`/messages/new?id=${a.id}`)}>
            <Pencil />
            {t('messages.actions.edit')}
          </Button>
          <Button onClick={() => setConfirm('send')}>
            <Send />
            {t('messages.actions.sendNow')}
          </Button>
        </div>
      )}
      <ConfirmDialog
        open={confirm !== null}
        onOpenChange={(open) => !open && setConfirm(null)}
        title={t(confirm === 'delete' ? 'messages.actions.deleteTitle' : 'messages.actions.sendNowTitle')}
        description={t(confirm === 'delete' ? 'messages.actions.deleteDescription' : 'messages.actions.sendNowDescription', { title: a.title })}
        confirmLabel={t(confirm === 'delete' ? 'messages.actions.delete' : 'messages.actions.sendNow')}
        destructive={confirm === 'delete'}
        loading={remove.isPending || sendNow.isPending}
        onConfirm={() => void onConfirm().catch(() => setConfirm(null))}
      />
    </SheetFooter>
  );
}
