import { beforeEach, describe, expect, it } from 'vitest';

import { getTables } from '../db';
import { guardiansService } from '../services/students';
import { freshDb, loginAs } from './helpers';

describe('guardians.unlink', () => {
  beforeEach(() => {
    freshDb();
  });

  it('ulangan ota-ona — NOT_INVITED, audit; qayta uzish — CONFLICT', async () => {
    loginAs('DIRECTOR');
    const linked = getTables().guardians.find((g) => g.linkStatus === 'LINKED');
    expect(linked).toBeDefined();
    const result = await guardiansService.unlink(linked!.id);
    expect(result).toMatchObject({ linkStatus: 'NOT_INVITED', linkedAt: null, inviteCode: null });
    expect(getTables().audit.some((a) => a.action === 'guardian.unlinked' && a.params?.variant === 'staff')).toBe(true);
    await expect(guardiansService.unlink(linked!.id)).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('psixolog (guardians.link yo\'q) — FORBIDDEN', async () => {
    loginAs('PSYCHOLOGIST');
    const linked = getTables().guardians.find((g) => g.linkStatus === 'LINKED');
    await expect(guardiansService.unlink(linked!.id)).rejects.toMatchObject({ code: 'FORBIDDEN' });
  });
});
