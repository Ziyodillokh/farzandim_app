'use client';

import { AuthGuard, HydrationGate } from '@/auth/guards';
import { ComingSoon } from '@/components/common/coming-soon';

export default function KioskPage() {
  return (
    <HydrationGate>
      <AuthGuard>
        <div className="p-8">
          <ComingSoon titleKey="nav.kiosk" />
        </div>
      </AuthGuard>
    </HydrationGate>
  );
}
