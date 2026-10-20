'use client';

import { AuthGuard, HttpSessionGate, HydrationGate } from '@/auth/guards';
import { isHttpMode } from '@/data/source';
import { KioskView } from '@/features/attendance/components/kiosk/kiosk-view';
import { KioskDemoEntry } from '@/features/engine/kiosk-demo-entry';

export default function KioskPage() {
  return (
    <HydrationGate>
      {isHttpMode ? (
        // Haqiqiy rejim: sessiya cookie orqali tiklanadi (demo launcher yo'q).
        <HttpSessionGate>
          <AuthGuard>
            <KioskView />
          </AuthGuard>
        </HttpSessionGate>
      ) : (
        <KioskDemoEntry>
          <AuthGuard>
            <KioskView />
          </AuthGuard>
        </KioskDemoEntry>
      )}
    </HydrationGate>
  );
}
