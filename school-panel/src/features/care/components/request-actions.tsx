'use client';

import { CalendarClock, ShieldAlert, ShieldCheck, SlidersHorizontal } from 'lucide-react';
import { useEffect, useState } from 'react';

import { ConfirmDialog } from '@/components/common/confirm-dialog';
import { FormField } from '@/components/common/form-field';
import { SectionCard } from '@/components/common/section-card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import type { CareRequestStatus } from '@/data/contracts';
import type { CareRequestDetail } from '@/data/mock/services/care';
import { CARE_REQUEST_STATUSES } from '@/data/schemas/care';
import { TILE } from '@/features/dashboard/lib/tile';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';
import { useActivateProtocol, useScheduleMeeting, useUpdateRequestStatus } from '../hooks';

/** "YYYY-MM-DDTHH:MM:SS" → datetime-local qiymati. */
function toLocalInput(value: string | null): string {
  return value ? value.slice(0, 16) : '';
}

/** Psixolog amallari: holat, suhbat vaqti, himoya protokoli. */
export function RequestActions({ request }: { request: CareRequestDetail }) {
  const { t } = useI18n();
  const updateStatus = useUpdateRequestStatus();
  const schedule = useScheduleMeeting();
  const protocol = useActivateProtocol();
  const [meetingAt, setMeetingAt] = useState(toLocalInput(request.meetingAt));
  const [confirmOpen, setConfirmOpen] = useState(false);

  useEffect(() => setMeetingAt(toLocalInput(request.meetingAt)), [request.meetingAt]);

  const canProtocol = request.urgency === 'URGENT' && !request.protocolActivated;

  return (
    <SectionCard title={t('care.request.actions')} icon={<SlidersHorizontal />}>
      <div className="space-y-5">
        <FormField label={t('care.request.changeStatus')} hint={!request.meetingAt ? t('care.request.needMeeting') : undefined}>
          <Select
            value={request.status}
            onValueChange={(v) => updateStatus.mutate({ id: request.id, status: v as CareRequestStatus })}
            disabled={updateStatus.isPending}
          >
            <SelectTrigger aria-label={t('care.request.changeStatus')}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {CARE_REQUEST_STATUSES.map((s) => (
                <SelectItem key={s} value={s} disabled={s === 'SCHEDULED' && !request.meetingAt}>
                  {t(`enums.careRequestStatus.${s}`)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </FormField>

        <FormField label={t('care.request.scheduleMeeting')} htmlFor="care-meeting" hint={t('care.request.meetingHint')}>
          <div className="space-y-2">
            <Input id="care-meeting" type="datetime-local" value={meetingAt} onChange={(e) => setMeetingAt(e.target.value)} className="w-full min-w-0" />
            <Button
              variant="outline"
              className="w-full"
              onClick={() => schedule.mutate({ id: request.id, meetingAt })}
              loading={schedule.isPending}
              disabled={!meetingAt || meetingAt === toLocalInput(request.meetingAt)}
            >
              <CalendarClock />
              {t('care.request.meetingSave')}
            </Button>
          </div>
        </FormField>

        {request.urgency === 'URGENT' && (
          <>
            <Separator className="bg-border/60" />
            {canProtocol ? (
              <Button variant="destructive" className="h-auto w-full whitespace-normal py-2.5" onClick={() => setConfirmOpen(true)}>
                <ShieldAlert />
                {t('care.request.protocol.button')}
              </Button>
            ) : (
              <div className="flex items-center gap-2 rounded-xl bg-success/10 px-3 py-2.5 text-sm font-medium text-success ring-1 ring-inset ring-success/20">
                <ShieldCheck className="h-4 w-4" />
                {t('care.request.protocol.activeTitle')}
              </div>
            )}
          </>
        )}
      </div>

      <ConfirmDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title={t('care.request.protocol.title')}
        description={t('care.request.protocol.description')}
        confirmLabel={t('care.request.protocol.confirm')}
        destructive
        loading={protocol.isPending}
        onConfirm={() => protocol.mutate(request.id, { onSuccess: () => setConfirmOpen(false) })}
      >
        <ol className={cn(TILE, 'space-y-2 p-3 text-sm')}>
          {(['step1', 'step2', 'step3', 'step4'] as const).map((step, i) => (
            <li key={step} className="flex gap-2.5">
              <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-destructive/10 text-2xs font-bold text-destructive">{i + 1}</span>
              <span>{t(`care.request.protocol.${step}`)}</span>
            </li>
          ))}
        </ol>
      </ConfirmDialog>
    </SectionCard>
  );
}
