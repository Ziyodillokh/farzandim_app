'use client';

import {
  Brain,
  HeartPulse,
  LogOut,
  type LucideIcon,
  MessageSquareHeart,
  Receipt,
  Send,
  ShieldAlert,
  Siren,
} from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import type { NotificationItem, NotificationKind, NotificationTone } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { cn } from '@/lib/utils';

const ICONS: Record<NotificationKind, LucideIcon> = {
  SAFETY_SIGNAL: ShieldAlert,
  TEST_COMPLETED: Brain,
  EARLY_EXIT_PENDING: LogOut,
  VERIFICATION_OPEN: Receipt,
  CARE_NEW: MessageSquareHeart,
  CARE_URGENT: HeartPulse,
  MESSAGE_SENT: Send,
  EMERGENCY: Siren,
};

const TILE: Record<NotificationTone, string> = {
  destructive: 'bg-destructive/10 text-destructive ring-destructive/15',
  warning: 'bg-warning/10 text-warning ring-warning/15',
  info: 'bg-info/10 text-info ring-info/15',
  success: 'bg-success/10 text-success ring-success/15',
};

type NotificationRowProps = {
  item: NotificationItem;
  unread: boolean;
  onOpen: (item: NotificationItem) => void;
};

/** Bitta bildirishnoma: ohang belgisi, sarlavha, mavzu, nisbiy vaqt, o'qilmagan nuqta. */
export function NotificationRow({ item, unread, onOpen }: NotificationRowProps) {
  const { t, locale, formatRelative } = useI18n();
  const Icon = ICONS[item.kind];
  const title = t(`notifications.kind.${item.kind}`, item.params);
  const subject = item.subject?.[locale] ?? (item.kind === 'SAFETY_SIGNAL' ? t('notifications.safetyHint') : null);

  return (
    <li>
      <button
        type="button"
        onClick={() => onOpen(item)}
        className={cn(
          'group flex w-full items-start gap-3 rounded-xl px-2.5 py-2.5 text-left transition-colors hover:bg-primary/[0.06] focus-visible:bg-primary/[0.06] focus-visible:outline-none dark:hover:bg-white/[0.05]',
          unread && 'bg-primary/[0.035] dark:bg-white/[0.025]',
        )}
      >
        <span className={cn('mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ring-1 ring-inset [&_svg]:size-4', TILE[item.tone])}>
          <Icon aria-hidden />
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex items-center gap-2">
            <Badge variant={item.tone} size="sm" className="shrink-0">
              {t(`notifications.category.${item.kind}`)}
            </Badge>
            <span className="truncate text-2xs text-muted-foreground">{formatRelative(item.at)}</span>
          </span>
          <span className={cn('mt-1 line-clamp-2 block text-[0.84rem] leading-snug', unread ? 'font-semibold text-foreground' : 'font-medium text-foreground/85')}>
            {title}
          </span>
          {subject && <span className="mt-0.5 block truncate text-xs text-muted-foreground">{subject}</span>}
        </span>
        <span className="mt-2 flex w-2 shrink-0 justify-center">
          {unread && <span className="h-2 w-2 rounded-full bg-primary shadow-[0_0_0_3px_hsl(var(--primary)/0.15)]" aria-label={t('notifications.unread')} />}
        </span>
      </button>
    </li>
  );
}
