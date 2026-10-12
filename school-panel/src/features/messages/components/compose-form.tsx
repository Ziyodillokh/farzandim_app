'use client';

import { zodResolver } from '@hookform/resolvers/zod';
import { CalendarClock, FileWarning, Save, Send } from 'lucide-react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';

import { useCan } from '@/auth/use-session';
import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { clockNow } from '@/data/mock/clock';
import type { AnnouncementDetail, MessageTemplate } from '@/data/mock/services/comms';
import { announcementInputSchema, type AnnouncementInput } from '@/data/schemas/comms';
import { useI18n } from '@/i18n';
import { useAnnouncement, useAudienceReach, useClassChoices, useSaveDraft, useSendAnnouncement } from '../hooks';
import { AudiencePicker } from './audience-picker';
import { ContentSection, type ScheduleMode, ScheduleSection } from './compose-sections';
import { MessagePhonePreview } from './message-preview';
import { RecipientsSummary } from './recipients-summary';

const DEFAULT_SEND_HOUR = 8;

/** Ertangi kun 08:00 — `datetime-local` formatida. */
function defaultSchedule(): string {
  const d = clockNow();
  d.setDate(d.getDate() + 1);
  d.setHours(DEFAULT_SEND_HOUR, 0, 0, 0);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:00`;
}

function isFuture(value: string): boolean {
  return Boolean(value) && new Date(value).getTime() > clockNow().getTime();
}

/** Yangi xabar yoki `?id=` bo'yicha qoralama / rejalashtirilgan xabarni tahrirlash. */
export function ComposeForm({ id }: { id: string | null }) {
  const { t } = useI18n();
  const existing = useAnnouncement(id);

  if (id && existing.isLoading) {
    return (
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <Skeleton className="h-[520px] rounded-xl" />
        <Skeleton className="h-[560px] rounded-[2.6rem]" />
      </div>
    );
  }
  if (id && (existing.isError || (existing.data && !existing.data.canManage))) {
    return (
      <div className="rounded-xl border bg-card">
        <EmptyState
          icon={<FileWarning />}
          title={t('messages.compose.notFound')}
          action={
            <Button asChild variant="outline">
              <Link href="/messages">{t('messages.compose.back')}</Link>
            </Button>
          }
        />
      </div>
    );
  }
  return <ComposeEditor key={existing.data?.id ?? 'new'} initial={existing.data ?? null} />;
}

function ComposeEditor({ initial }: { initial: AnnouncementDetail | null }) {
  const { t } = useI18n();
  const router = useRouter();
  const can = useCan();
  const canSchool = can('messages.sendSchool');
  const classes = useClassChoices();
  const send = useSendAnnouncement();
  const draft = useSaveDraft();
  const [mode, setMode] = useState<ScheduleMode>(initial?.status === 'SCHEDULED' ? 'later' : 'now');
  const [scheduledAt, setScheduledAt] = useState(initial?.scheduledAt?.slice(0, 16) ?? defaultSchedule());
  const [scheduleInvalid, setScheduleInvalid] = useState(false);
  const [pendingTemplate, setPendingTemplate] = useState<MessageTemplate | null>(null);

  const form = useForm<AnnouncementInput>({
    resolver: zodResolver(announcementInputSchema),
    defaultValues: initial
      ? { title: initial.title, body: initial.body, priority: initial.priority, audience: initial.audience }
      : { title: '', body: '', priority: 'NORMAL', audience: { kind: canSchool ? 'SCHOOL' : 'CLASSES', classIds: [], guardianIds: [] } },
  });

  // Sinf rahbari: yangi xabar standart holda o'z sinfiga.
  useEffect(() => {
    if (initial || canSchool || !classes.data?.length) return;
    if ((form.getValues('audience.classIds') ?? []).length === 0) {
      form.setValue('audience', { kind: 'CLASSES', classIds: classes.data.map((c) => c.id), guardianIds: [] });
    }
  }, [initial, canSchool, classes.data, form]);

  const values = form.watch();
  const audience = { kind: values.audience.kind, classIds: values.audience.classIds ?? [], guardianIds: values.audience.guardianIds ?? [] };
  const reach = useAudienceReach(audience);
  const audienceError = form.formState.errors.audience;
  const audienceMessage = audienceError?.classIds?.message ?? audienceError?.guardianIds?.message ?? audienceError?.message;
  const knownNames = initial?.audience.kind === 'GUARDIANS' ? Object.fromEntries(initial.audience.guardianIds.map((gid, i) => [gid, initial.audienceNames[i] ?? gid])) : undefined;

  const applyTemplate = (tpl: MessageTemplate) => {
    form.setValue('title', tpl.title, { shouldValidate: form.formState.isSubmitted });
    form.setValue('body', tpl.body, { shouldValidate: form.formState.isSubmitted });
    form.setValue('priority', tpl.priority);
    setPendingTemplate(null);
  };
  const onTemplate = (tpl: MessageTemplate) => {
    if (values.title.trim() || values.body.trim()) setPendingTemplate(tpl);
    else applyTemplate(tpl);
  };

  const onSend = form.handleSubmit(async (input) => {
    if (mode === 'later' && !isFuture(scheduledAt)) {
      setScheduleInvalid(true);
      return;
    }
    try {
      await send.mutateAsync({ input, options: { id: initial?.id, scheduledAt: mode === 'later' ? scheduledAt : null } });
      router.push('/messages');
    } catch {
      // Xato toast orqali ko'rsatildi (useCommsMutation.onError).
    }
  });

  const onDraft = form.handleSubmit(async (input) => {
    try {
      await draft.mutateAsync({ input, id: initial?.id });
      router.push('/messages');
    } catch {
      // Xato toast orqali ko'rsatildi.
    }
  });

  return (
    <form onSubmit={(e) => void onSend(e)} noValidate className="animate-fade-in">
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div className="min-w-0 space-y-6">
          <ContentSection form={form} onTemplate={onTemplate} />
          <SectionCard title={t('messages.compose.audience')}>
            <AudiencePicker
              value={audience}
              onChange={(next) => form.setValue('audience', next, { shouldValidate: form.formState.isSubmitted })}
              canSchool={canSchool}
              knownNames={knownNames}
              error={audienceMessage}
            />
          </SectionCard>
          <ScheduleSection
            mode={mode}
            onModeChange={(next) => {
              setMode(next);
              setScheduleInvalid(false);
            }}
            value={scheduledAt}
            onValueChange={(next) => {
              setScheduledAt(next);
              setScheduleInvalid(false);
            }}
            invalid={scheduleInvalid}
          />
        </div>

        <aside className="space-y-4 lg:sticky lg:top-20 lg:self-start">
          <div className="text-center">
            <p className="text-sm font-semibold">{t('messages.preview.title')}</p>
            <p className="text-xs text-muted-foreground">{t('messages.preview.hint')}</p>
          </div>
          <MessagePhonePreview title={values.title} body={values.body} important={values.priority === 'IMPORTANT'} />
          <SectionCard title={t('messages.recipients.title')} bodyClassName="p-4">
            <RecipientsSummary reach={reach.data} loading={reach.isLoading} />
          </SectionCard>
        </aside>
      </div>

      <div className="sticky bottom-0 z-10 -mx-4 mt-6 flex flex-wrap items-center justify-end gap-2 border-t bg-background/85 px-4 py-3 backdrop-blur md:-mx-8 md:px-8">
        <Button type="button" variant="outline" onClick={() => void onDraft()} loading={draft.isPending} disabled={send.isPending}>
          <Save />
          {t('messages.compose.saveDraft')}
        </Button>
        <Button type="submit" loading={send.isPending} disabled={draft.isPending}>
          {mode === 'later' ? <CalendarClock /> : <Send />}
          {mode === 'later' ? t('messages.compose.schedule') : t('messages.compose.send')}
        </Button>
      </div>

      <ConfirmDialog
        open={pendingTemplate !== null}
        onOpenChange={(open) => !open && setPendingTemplate(null)}
        title={t('messages.templates.replaceTitle')}
        description={t('messages.templates.replaceDescription')}
        confirmLabel={t('messages.templates.apply')}
        onConfirm={() => pendingTemplate && applyTemplate(pendingTemplate)}
      />
    </form>
  );
}
