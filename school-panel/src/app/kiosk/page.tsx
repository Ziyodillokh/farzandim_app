'use client';

import { AuthGuard, HydrationGate } from '@/auth/guards';
import { KioskView } from '@/features/attendance/components/kiosk/kiosk-view';
import { KioskDemoEntry } from '@/features/engine/kiosk-demo-entry';

export default function KioskPage() {
  return (
    <HydrationGate>
      <KioskDemoEntry>
        <AuthGuard>
          <KioskView />
        </AuthGuard>
      </KioskDemoEntry>
    </HydrationGate>
  );
}
