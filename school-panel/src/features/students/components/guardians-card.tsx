'use client';

import { Link2, Phone, Plus, Send, UserX } from 'lucide-react';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { EmptyState } from '@/components/common/empty-state';
import { SectionCard } from '@/components/common/section-card';
import { LinkBadge } from '@/components/common/status-badges';
import { Button } from '@/components/ui/button';
import type { Guardian } from '@/data/contracts';
import { useI18n } from '@/i18n';
import { useInviteGuardian, useSimulateLink } from '../hooks';
import { GuardianFormDialog } from './guardian-form-dialog';
import { InviteDialog } from './invite-dialog';

export function GuardiansCard({ studentId, guardians }: { studentId: string; guardians: Guardian[] }) {
  const { t } = useI18n();
  const invite = useInviteGuardian();
  const link = useSimulateLink();
  const [shown, setShown] = useState<Guardian | null>(null);
  const [addOpen, setAddOpen] = useState(false);

  return (
    <SectionCard
      title={t('students.detail.guardians')}
      actions={
        <Can perm="guardians.link">
          <Button size="sm" variant="soft" onClick={() => setAddOpen(true)}>
            <Plus />
            {t('students.detail.addGuardian')}
          </Button>
        </Can>
      }
      bodyClassName="p-0"
    >
      {guardians.length === 0 ? (
        <EmptyState icon={<UserX />} title={t('students.detail.noGuardians')} className="py-10" />
      ) : (
        <ul className="divide-y">
          {guardians.map((g) => (
            <li key={g.id} className="flex flex-wrap items-center gap-3 px-5 py-4">
              <div className="min-w-0 flex-1">
                <p className="font-medium">{g.fullName}</p>
                <p className="mt-0.5 flex items-center gap-2 text-sm text-muted-foreground">
                  {t(`enums.relation.${g.relation}`)}
                  <span>·</span>
                  <a href={`tel:${g.phone.replace(/\s/g, '')}`} className="inline-flex items-center gap-1 hover:text-primary">
                    <Phone className="h-3.5 w-3.5" />
                    {g.phone}
                  </a>
                </p>
              </div>
              <LinkBadge status={g.linkStatus} />
              <Can perm="guardians.link">
                {g.linkStatus !== 'LINKED' && (
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      loading={invite.isPending && invite.variables === g.id}
                      onClick={async () => setShown(await invite.mutateAsync(g.id))}
                    >
                      <Send />
                      {g.linkStatus === 'INVITED' ? t('students.detail.resend') : t('students.detail.invite')}
                    </Button>
                    {g.linkStatus === 'INVITED' && (
                      <Button size="sm" variant="ghost" onClick={() => link.mutate(g.id)}>
                        <Link2 />
                        {t('students.detail.simulateLink')}
                      </Button>
                    )}
                  </div>
                )}
              </Can>
            </li>
          ))}
        </ul>
      )}
      <InviteDialog guardian={shown} onOpenChange={(open) => !open && setShown(null)} />
      <GuardianFormDialog studentId={studentId} open={addOpen} onOpenChange={setAddOpen} />
    </SectionCard>
  );
}
