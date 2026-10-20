'use client';

import type {
  AttendanceStatus,
  CareRequestStatus,
  CareUrgency,
  DeviceModeStatus,
  EarlyExitStatus,
  MessageStatus,
  ParentLinkStatus,
  VerificationStatus,
} from '@/data/contracts';
import { Badge, type BadgeProps } from '@/components/ui/badge';
import { useI18n } from '@/i18n';

type Variant = NonNullable<BadgeProps['variant']>;

const ATTENDANCE: Record<AttendanceStatus, Variant> = {
  PRESENT: 'success',
  LATE: 'warning',
  ABSENT: 'destructive',
  LEFT_EARLY: 'info',
  EXCUSED: 'secondary',
};
const LINK: Record<ParentLinkStatus, Variant> = { LINKED: 'success', INVITED: 'warning', NOT_INVITED: 'secondary' };
const DEVICE: Record<DeviceModeStatus, Variant> = { APPLIED: 'success', NO_PERMISSION: 'warning', NO_PHONE: 'secondary', OFFLINE: 'destructive' };
const EXIT: Record<EarlyExitStatus, Variant> = { PENDING: 'warning', APPROVED: 'success', REJECTED: 'destructive' };
const MESSAGE: Record<MessageStatus, Variant> = { DRAFT: 'secondary', SCHEDULED: 'info', SENT: 'success' };
const VERIFICATION: Record<VerificationStatus, Variant> = { OPEN: 'warning', ANSWERED: 'success', CLOSED: 'secondary' };
const CARE: Record<CareRequestStatus, Variant> = { NEW: 'destructive', IN_PROGRESS: 'warning', SCHEDULED: 'info', RESOLVED: 'success' };

function Dot() {
  return <span className="h-1.5 w-1.5 rounded-full bg-current" aria-hidden />;
}

export function AttendanceBadge({ status, size }: { status: AttendanceStatus | null; size?: BadgeProps['size'] }) {
  const { t } = useI18n();
  if (!status) return <Badge variant="outline" size={size} className="text-muted-foreground">—</Badge>;
  return (
    <Badge variant={ATTENDANCE[status]} size={size}>
      <Dot />
      {t(`enums.attendanceStatus.${status}`)}
    </Badge>
  );
}

export function LinkBadge({ status }: { status: ParentLinkStatus }) {
  const { t } = useI18n();
  return <Badge variant={LINK[status]}><Dot />{t(`enums.linkStatus.${status}`)}</Badge>;
}

export function DeviceModeBadge({ status }: { status: DeviceModeStatus }) {
  const { t } = useI18n();
  return <Badge variant={DEVICE[status]}><Dot />{t(`enums.deviceModeStatus.${status}`)}</Badge>;
}

export function EarlyExitBadge({ status }: { status: EarlyExitStatus }) {
  const { t } = useI18n();
  return <Badge variant={EXIT[status]}>{t(`enums.earlyExitStatus.${status}`)}</Badge>;
}

export function MessageStatusBadge({ status }: { status: MessageStatus }) {
  const { t } = useI18n();
  return <Badge variant={MESSAGE[status]}>{t(`enums.messageStatus.${status}`)}</Badge>;
}

export function VerificationBadge({ status }: { status: VerificationStatus }) {
  const { t } = useI18n();
  return <Badge variant={VERIFICATION[status]}>{t(`enums.verificationStatus.${status}`)}</Badge>;
}

export function CareStatusBadge({ status }: { status: CareRequestStatus }) {
  const { t } = useI18n();
  return <Badge variant={CARE[status]}>{t(`enums.careRequestStatus.${status}`)}</Badge>;
}

export function UrgencyBadge({ urgency }: { urgency: CareUrgency }) {
  const { t } = useI18n();
  if (urgency === 'NORMAL') return null;
  return (
    <Badge variant="destructive" className="animate-pulse">
      {t('enums.careUrgency.URGENT')}
    </Badge>
  );
}
