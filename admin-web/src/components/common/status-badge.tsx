import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

const CONTENT_STATUS: Record<string, { label: string; variant: 'success' | 'warning' | 'destructive' | 'secondary' }> = {
  approved: { label: 'Tasdiqlangan', variant: 'success' },
  pending: { label: 'Kutilmoqda', variant: 'warning' },
  rejected: { label: 'Rad etilgan', variant: 'destructive' },
  hidden: { label: 'Yashirilgan', variant: 'secondary' },
};

export function ContentStatusBadge({ status }: { status: string }) {
  const cfg = CONTENT_STATUS[status] ?? { label: status, variant: 'secondary' as const };
  return (
    <Badge variant={cfg.variant} size="sm">
      <span
        className={cn(
          'h-1.5 w-1.5 rounded-full',
          cfg.variant === 'success' && 'bg-success',
          cfg.variant === 'warning' && 'bg-warning',
          cfg.variant === 'destructive' && 'bg-destructive',
          cfg.variant === 'secondary' && 'bg-muted-foreground',
        )}
      />
      {cfg.label}
    </Badge>
  );
}

const PAYMENT_STATUS: Record<string, { label: string; variant: 'success' | 'warning' | 'destructive' | 'secondary' | 'info' }> = {
  success: { label: 'Muvaffaqiyatli', variant: 'success' },
  pending: { label: 'Kutilmoqda', variant: 'warning' },
  failed: { label: 'Muvaffaqiyatsiz', variant: 'destructive' },
  cancelled: { label: 'Bekor qilingan', variant: 'secondary' },
  refunded: { label: 'Qaytarilgan', variant: 'info' },
};

export function PaymentStatusBadge({ status }: { status: string }) {
  const cfg = PAYMENT_STATUS[status] ?? { label: status, variant: 'secondary' as const };
  return <Badge variant={cfg.variant} size="sm">{cfg.label}</Badge>;
}
