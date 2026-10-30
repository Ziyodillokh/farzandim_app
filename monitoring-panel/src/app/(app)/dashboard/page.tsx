'use client';

import { DashboardView } from '@/features/dashboard/dashboard-view';
import { useUserScope } from '@/features/filters/use-monitoring';

/** Bosh sahifa: respublika foydalanuvchisi — butun mamlakat, viloyat — o'z hududi. */
export default function DashboardPage() {
  const scope = useUserScope();
  return <DashboardView scope={scope} />;
}
