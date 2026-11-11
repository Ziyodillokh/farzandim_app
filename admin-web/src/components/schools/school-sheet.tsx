'use client';

/** Maktab tafsiloti (o'ng panel): sonlar, panel manzili va admin boshqaradigan hisoblar. */

import { useQuery } from '@tanstack/react-query';
import { AlertTriangle, ExternalLink } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { schoolsApi } from '@/lib/api/admin.api';
import type { AdminSchool } from '@/types/api.types';
import type { ShownCredentials } from './credentials-dialog';
import { SchoolAccountRow } from './school-account-row';
import { SchoolAddAccount } from './school-add-account';
import { SCHOOL_PANEL_URL } from './school-form';
import { formatDate } from './school-format';
import { schoolsErrorMessage } from './schools-errors';
import { schoolsKeys } from './schools-keys';

export function SchoolSheet({
  school,
  onOpenChange,
  onCredentials,
}: {
  school: AdminSchool | null;
  onOpenChange: (v: boolean) => void;
  onCredentials: (c: ShownCredentials) => void;
}) {
  return (
    <Sheet open={school !== null} onOpenChange={onOpenChange}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
        {school && <Body initial={school} onCredentials={onCredentials} />}
      </SheetContent>
    </Sheet>
  );
}

function Body({ initial, onCredentials }: { initial: AdminSchool; onCredentials: (c: ShownCredentials) => void }) {
  // Ro'yxatdagi qator darhol ko'rinadi; tiklash / qo'shishdan keyin yangilanadi.
  const detail = useQuery({
    queryKey: schoolsKeys.detail(initial.id),
    queryFn: () => schoolsApi.detail(initial.id),
    initialData: initial,
  });
  const s = detail.data ?? initial;

  const stats: Array<[string, number]> = [
    ["O'quvchilar", s.counts.students],
    ['Sinflar', s.counts.classes],
    ['Xodimlar', s.counts.staff],
    ['Ulangan ota-onalar', s.counts.linkedGuardians],
  ];

  return (
    <>
      <SheetHeader className="pr-12">
        <SheetTitle>{s.name}</SheetTitle>
        <SheetDescription>
          {s.city} · kod <span className="font-mono text-foreground">{s.code}</span> · {s.academicYear} o&apos;quv yili
          · ochilgan {formatDate(s.createdAt)}
        </SheetDescription>
      </SheetHeader>

      <div className="space-y-6 px-6 pb-6">
        <dl className="grid grid-cols-2 gap-3">
          {stats.map(([label, value]) => (
            <div key={label} className="rounded-xl border border-border p-3">
              <dt className="text-xs text-muted-foreground">{label}</dt>
              <dd className="text-xl font-semibold tabular-nums">{value}</dd>
            </div>
          ))}
        </dl>

        <a
          href={SCHOOL_PANEL_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1.5 text-sm font-medium text-primary hover:underline"
        >
          Maktab paneli <ExternalLink className="h-3.5 w-3.5" aria-hidden />
        </a>

        <section className="space-y-3">
          <div>
            <h3 className="font-semibold">Direktor va psixolog hisoblari</h3>
            <p className="text-sm text-muted-foreground">
              Bu hisoblarni faqat admin beradi va tiklaydi. Sinf rahbari, o&apos;qituvchi, navbatchi va
              ma&apos;muriyatni direktor panelda o&apos;zi qo&apos;shadi.
            </p>
          </div>
          {detail.isError && (
            <p role="alert" className="flex items-center gap-2 text-xs text-destructive">
              <AlertTriangle className="h-3.5 w-3.5" aria-hidden /> {schoolsErrorMessage(detail.error)}
            </p>
          )}
          {detail.isFetching && s.accounts.length === 0 ? (
            <Skeleton className="h-24 w-full rounded-xl" />
          ) : (
            <ul className="space-y-3">
              {s.accounts.map((a) => (
                <SchoolAccountRow key={a.id} school={s} account={a} onCredentials={onCredentials} />
              ))}
            </ul>
          )}
          <SchoolAddAccount school={s} onCredentials={onCredentials} />
        </section>
      </div>
    </>
  );
}
