'use client';

import { KeyRound, Plus, ShieldCheck, UserCheck, UserCog, Users } from 'lucide-react';
import { useState } from 'react';

import { Can } from '@/auth/can';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { RolesTab } from '@/features/staff/components/roles-tab';
import { StaffTab } from '@/features/staff/components/staff-tab';
import { useStaffSummary } from '@/features/staff/hooks';
import { useI18n } from '@/i18n';

type TabKey = 'staff' | 'roles';

export default function StaffPage() {
  const { t, formatNumber } = useI18n();
  const [tab, setTab] = useState<TabKey>('staff');
  const [createOpen, setCreateOpen] = useState(false);
  const summary = useStaffSummary();
  const s = summary.data;

  return (
    <>
      <PageHeader
        title={t('staff.title')}
        subtitle={t('staff.subtitle')}
        actions={
          tab === 'staff' && (
            <Can perm="staff.manage">
              <Button onClick={() => setCreateOpen(true)}>
                <Plus />
                {t('staff.add')}
              </Button>
            </Can>
          )
        }
      />

      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon={<Users />} label={t('staff.stats.total')} value={formatNumber(s?.total ?? 0)} loading={summary.isLoading} />
        <StatCard
          icon={<UserCheck />}
          tone="success"
          label={t('staff.stats.active')}
          value={formatNumber(s?.active ?? 0)}
          hint={s && s.inactive > 0 ? t('staff.stats.inactive', { count: s.inactive }) : undefined}
          loading={summary.isLoading}
        />
        <StatCard
          icon={<UserCog />}
          tone="info"
          label={t('staff.stats.homerooms')}
          value={formatNumber(s?.byRole.HOMEROOM ?? 0)}
          loading={summary.isLoading}
        />
        <StatCard
          icon={<KeyRound />}
          tone="warning"
          label={t('staff.stats.demo')}
          value={formatNumber(s?.demo ?? 0)}
          hint={t('staff.stats.demoHint')}
          loading={summary.isLoading}
        />
      </div>

      <Tabs value={tab} onValueChange={(v) => setTab(v as TabKey)}>
        <TabsList>
          <TabsTrigger value="staff">
            <Users />
            {t('staff.tabs.staff')}
          </TabsTrigger>
          <TabsTrigger value="roles">
            <ShieldCheck />
            {t('staff.tabs.roles')}
          </TabsTrigger>
        </TabsList>
        <TabsContent value="staff" className="animate-fade-in">
          <StaffTab createOpen={createOpen} onCreateOpenChange={setCreateOpen} />
        </TabsContent>
        <TabsContent value="roles" className="animate-fade-in">
          <RolesTab />
        </TabsContent>
      </Tabs>
    </>
  );
}
