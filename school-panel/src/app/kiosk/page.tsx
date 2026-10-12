'use client';

import { AuthGuard, HydrationGate } from '@/auth/guards';
import { KioskView } from '@/features/attendance/components/kiosk/kiosk-view';

export default function KioskPage() {
  return (
    <HydrationGate>
      <AuthGuard>
        <KioskView />
      </AuthGuard>
    </HydrationGate>
  );
}
