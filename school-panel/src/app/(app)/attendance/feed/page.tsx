'use client';

import { BellRing, Radio } from 'lucide-react';
import { useMemo, useState } from 'react';

import { PageHeader } from '@/components/common/page-header';
import { FilterSelect, Toolbar } from '@/components/common/toolbar';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import type { AttendanceEventKind } from '@/data/contracts';
import { FeedEventsTab } from '@/features/attendance/components/feed-events-tab';
import { LiveIndicator } from '@/features/attendance/components/live-indicator';
import { NotificationsTab } from '@/features/attendance/components/notifications-tab';
import { useAttendanceClassOptions } from '@/features/attendance/hooks';
import { useI18n } from '@/i18n';

const KINDS: readonly AttendanceEventKind[] = ['IN', 'OUT'];

export default function AttendanceFeedPage() {
  const { t } = useI18n();
  const classes = useAttendanceClassOptions();
  const [tab, setTab] = useState('events');
  const [classId, setClassId] = useState<string>();
  const [kind, setKind] = useState<AttendanceEventKind>();
  const selectedClassName = useMemo(() => classes.data?.find((c) => c.id === classId)?.name, [classes.data, classId]);
  const classOptions = (classes.data ?? []).map((c) => ({ value: c.id, label: c.name }));

  return (
    <>
      <PageHeader title={t('attendance.feed.title')} subtitle={t('attendance.feed.subtitle')} badge={<LiveIndicator />} />
      <Tabs value={tab} onValueChange={setTab}>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <TabsList>
            <TabsTrigger value="events">
              <Radio />
              {t('attendance.feed.tabEvents')}
            </TabsTrigger>
            <TabsTrigger value="notifications">
              <BellRing />
              {t('attendance.feed.tabNotifications')}
            </TabsTrigger>
          </TabsList>
          <Toolbar className="mb-0">
            {classOptions.length > 1 && (
              <FilterSelect value={classId} onChange={setClassId} options={classOptions} allLabel={`${t('common.class')}: ${t('common.all')}`} className="sm:w-40" />
            )}
            {tab === 'events' && (
              <FilterSelect
                value={kind}
                onChange={(v) => setKind(v as AttendanceEventKind | undefined)}
                options={KINDS.map((k) => ({ value: k, label: t(`attendance.feed.kind.${k}`) }))}
                allLabel={t('attendance.feed.kindAll')}
              />
            )}
          </Toolbar>
        </div>
        <TabsContent value="events">
          <FeedEventsTab key={`${classId ?? ''}:${kind ?? ''}`} options={{ classId, kind }} />
        </TabsContent>
        <TabsContent value="notifications">
          <NotificationsTab key={classId ?? 'all'} classFilter={selectedClassName} />
        </TabsContent>
      </Tabs>
    </>
  );
}
