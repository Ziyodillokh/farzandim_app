import { QueryClient } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';

import type { CredentialsView } from '@/data/contracts';
import { accessKeys, markNotLinked } from '../keys';

describe('markNotLinked', () => {
  it('karta keshi «ulanmagan» holatiga o\'tadi (GET `null` qaytarsa ham ulanmagan o\'quvchini ajratib bo\'lmaydi)', () => {
    const client = new QueryClient();
    client.setQueryData<CredentialsView>(accessKeys.credentials('stu-1'), { linked: true, credentials: null });
    client.setQueryData<CredentialsView>(accessKeys.credentials('stu-2'), { linked: true, credentials: null });

    markNotLinked(client, 'stu-1');

    expect(client.getQueryData(accessKeys.credentials('stu-1'))).toEqual({ linked: false, credentials: null });
    // Boshqa o'quvchiga tegmaydi.
    expect(client.getQueryData(accessKeys.credentials('stu-2'))).toEqual({ linked: true, credentials: null });
  });

  it('kesh bo\'sh bo\'lsa ham holat yoziladi', () => {
    const client = new QueryClient();
    markNotLinked(client, 'stu-9');
    expect(client.getQueryData(accessKeys.credentials('stu-9'))).toEqual({ linked: false, credentials: null });
  });

  it('kalitlar: hammasi `access` ostida (bitta invalidatsiya hammasini yangilaydi)', () => {
    for (const key of [accessKeys.credentials('s'), accessKeys.recovery('s'), accessKeys.inviteCode('s')]) {
      expect(key.slice(0, accessKeys.all.length)).toEqual([...accessKeys.all]);
      expect(key).toContain('s');
    }
  });
});
