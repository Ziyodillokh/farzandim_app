'use client';

import { useQuery } from '@tanstack/react-query';
import { Clock, Search, UserRound } from 'lucide-react';
import { useEffect, useState } from 'react';

import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Skeleton } from '@/components/ui/skeleton';
import { Textarea } from '@/components/ui/textarea';
import { api } from '@/data/api';
import type { StudentRow } from '@/data/mock/services/students';
import { useClockNow } from '@/features/engine/use-clock';
import { useI18n } from '@/i18n';
import { useDebounced } from '@/lib/use-debounced';
import { cn, initials } from '@/lib/utils';
import { useCreateException } from '../hooks';
import { EXCEPTION_PRESETS, presetUntil, SEG_OFF, SEG_ON, SEG_TRACK, TILE, TONE_TILE, type ExceptionPreset } from '../lib';

const SEARCH_LIMIT = 8;
type Picked = Pick<StudentRow, 'id' | 'lastName' | 'firstName' | 'className' | 'studentCode'>;

function StudentPicker({ open, picked, onPick }: { open: boolean; picked: Picked | null; onPick: (s: Picked | null) => void }) {
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const search = useDebounced(query);
  const results = useQuery({
    queryKey: ['schoolMode', 'studentSearch', search],
    queryFn: () => api.students.list({ search, limit: SEARCH_LIMIT, sortBy: 'name' }),
    enabled: open && !picked,
  });

  if (picked) {
    return (
      <div className={cn('flex items-center gap-3 rounded-xl p-3 ring-1 ring-inset', TONE_TILE.primary)}>
        <Avatar className="h-10 w-10">
          <AvatarFallback className="bg-primary/10 text-sm font-semibold text-primary">{initials(`${picked.lastName} ${picked.firstName}`)}</AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium">
            {picked.lastName} {picked.firstName}
          </p>
          <p className="text-xs text-muted-foreground">
            {picked.className} · {picked.studentCode}
          </p>
        </div>
        <Button type="button" variant="ghost" size="sm" onClick={() => onPick(null)}>
          {t('schoolMode.exceptions.dialog.change')}
        </Button>
      </div>
    );
  }

  const items = results.data?.items ?? [];
  return (
    <div className="space-y-2">
      <Input icon={<Search />} value={query} onChange={(e) => setQuery(e.target.value)} placeholder={t('schoolMode.exceptions.dialog.searchStudent')} autoFocus />
      <div className={cn('max-h-56 overflow-y-auto', TILE)}>
        {results.isLoading ? (
          <div className="space-y-2 p-3">
            <Skeleton className="h-8 w-full" />
            <Skeleton className="h-8 w-3/4" />
          </div>
        ) : items.length === 0 ? (
          <p className="px-3 py-6 text-center text-sm text-muted-foreground">{t('schoolMode.exceptions.dialog.noStudents')}</p>
        ) : (
          <ul role="listbox" aria-label={t('schoolMode.exceptions.dialog.student')}>
            {items.map((s) => (
              <li key={s.id}>
                <button type="button" onClick={() => onPick(s)} className="flex w-full items-center gap-3 px-3 py-2 text-left text-sm transition-colors first:rounded-t-xl last:rounded-b-xl hover:bg-primary/[0.06]">
                  <UserRound className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                  <span className="min-w-0 flex-1 truncate font-medium">
                    {s.lastName} {s.firstName}
                  </span>
                  <span className="text-xs tabular-nums text-muted-foreground">
                    {s.className} · {s.studentCode}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

/** Vaqtinchalik istisno berish: o'quvchi, muddat (tayyor variantlar yoki vaqt), sabab (majburiy). */
export function ExceptionDialog({ open, onOpenChange }: { open: boolean; onOpenChange: (open: boolean) => void }) {
  const { t } = useI18n();
  const now = useClockNow(15_000);
  const create = useCreateException();
  const [picked, setPicked] = useState<Picked | null>(null);
  const [preset, setPreset] = useState<ExceptionPreset>('lesson');
  const [custom, setCustom] = useState('');
  const [reason, setReason] = useState('');

  useEffect(() => {
    if (!open) return;
    setPicked(null);
    setPreset('lesson');
    setCustom('');
    setReason('');
  }, [open]);

  const until = presetUntil(preset, now, custom);
  const valid = Boolean(picked) && reason.trim().length > 0 && /^\d{2}:\d{2}$/.test(until);
  const submit = () => {
    if (!picked || !valid) return;
    create.mutate({ studentId: picked.id, until, reason: reason.trim() }, { onSuccess: () => onOpenChange(false) });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{t('schoolMode.exceptions.dialog.title')}</DialogTitle>
          <DialogDescription>{t('schoolMode.exceptions.dialog.description')}</DialogDescription>
        </DialogHeader>
        <div className="grid gap-5">
          <div className="space-y-2">
            <Label>{t('schoolMode.exceptions.dialog.student')}</Label>
            <StudentPicker open={open} picked={picked} onPick={setPicked} />
          </div>
          <div className="space-y-2">
            <Label>{t('schoolMode.exceptions.dialog.duration')}</Label>
            <div className={cn('grid grid-cols-2 gap-1 sm:grid-cols-4', SEG_TRACK)} role="radiogroup">
              {EXCEPTION_PRESETS.map((p) => (
                <button
                  key={p}
                  type="button"
                  role="radio"
                  aria-checked={preset === p}
                  onClick={() => setPreset(p)}
                  className={cn('h-9 rounded-lg px-2 text-sm font-medium transition-all', preset === p ? SEG_ON : SEG_OFF)}
                >
                  {t(`schoolMode.exceptions.dialog.presets.${p}`)}
                </button>
              ))}
            </div>
            {preset === 'custom' && (
              <Input type="time" step={60} value={custom} onChange={(e) => setCustom(e.target.value)} aria-label={t('schoolMode.exceptions.dialog.until')} className="sm:w-40" />
            )}
            {/^\d{2}:\d{2}$/.test(until) && (
              <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <Clock className="h-3.5 w-3.5" aria-hidden />
                {t('schoolMode.exceptions.dialog.preview', { time: until })}
              </p>
            )}
          </div>
          <div className="space-y-2">
            <Label htmlFor="exception-reason">{t('schoolMode.exceptions.dialog.reason')}</Label>
            <Textarea
              id="exception-reason"
              rows={3}
              maxLength={300}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={t('schoolMode.exceptions.dialog.reasonPlaceholder')}
            />
          </div>
        </div>
        <DialogFooter>
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button type="button" onClick={submit} disabled={!valid} loading={create.isPending}>
            {t('schoolMode.exceptions.dialog.submit')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
