'use client';

import { GraduationCap, Search, Send } from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { useI18n } from '@/i18n';
import { useBulkInvite, usePendingInvites } from '../hooks';

export type BulkInviteDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  classId?: string;
  className?: string;
  search?: string;
};

/** Joriy filtr bo'yicha taklif qilinmagan barcha ota-onalarga taklif. */
export function BulkInviteDialog({ open, onOpenChange, classId, className, search }: BulkInviteDialogProps) {
  const { t, formatNumber } = useI18n();
  const filter = { classId, search: search?.trim() || undefined };
  const pending = usePendingInvites(filter, open);
  const bulk = useBulkInvite();
  const count = pending.data ?? 0;

  const send = async () => {
    try {
      await bulk.mutateAsync(filter);
      onOpenChange(false);
    } catch {
      // toast — hooks ichida
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{t('parents.bulk.title')}</DialogTitle>
          <DialogDescription>
            {pending.isLoading
              ? t('common.loading')
              : count > 0
                ? t('parents.bulk.text', { count: formatNumber(count) })
                : t('parents.bulk.none')}
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-2 rounded-xl border bg-muted/40 p-4">
          <p className="text-2xs font-semibold uppercase tracking-wide text-muted-foreground">{t('parents.bulk.scope')}</p>
          <div className="flex flex-wrap gap-2">
            <Badge variant="outline" className="gap-1.5">
              <GraduationCap className="h-3 w-3" />
              {className ? t('parents.bulk.scopeClass', { name: className }) : t('parents.bulk.scopeAll')}
            </Badge>
            {filter.search && (
              <Badge variant="outline" className="gap-1.5">
                <Search className="h-3 w-3" />
                {t('parents.bulk.scopeSearch', { query: filter.search })}
              </Badge>
            )}
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button onClick={() => void send()} disabled={count === 0 || pending.isLoading} loading={bulk.isPending}>
            {!bulk.isPending && <Send />}
            {t('parents.bulk.confirm', { count: formatNumber(count) })}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
