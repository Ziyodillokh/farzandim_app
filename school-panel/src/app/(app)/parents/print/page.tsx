'use client';

import { Suspense } from 'react';

import { InviteSheets } from '@/features/parents/components/invite-sheets';

export default function ParentInviteSheetsPage() {
  return (
    <Suspense>
      <InviteSheets />
    </Suspense>
  );
}
