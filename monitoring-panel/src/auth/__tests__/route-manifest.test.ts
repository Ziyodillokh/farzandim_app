import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { describe, expect, it } from 'vitest';

import { DEMO_ACCOUNTS } from '../demo-accounts';
import { roleHas } from '../permissions';
import { findRoute, NAV_GROUP_ORDER, ROUTES } from '../route-manifest';

describe('marshrutlar manifesti', () => {
  it('ichki sahifa o\'z ruxsati bilan tekshiriladi', () => {
    expect(findRoute('/regions/view')?.perm).toBe('region.view');
    expect(findRoute('/regions/view/')?.perm).toBe('region.view');
    expect(findRoute('/regions')?.perm).toBe('regions.view');
    expect(findRoute('/reports/print')?.perm).toBe('reports.view');
  });

  it('noma\'lum yo\'l — undefined', () => {
    expect(findRoute('/yoq-sahifa')).toBeUndefined();
  });

  it('menyu guruhlari tartibi va yashirin sahifalar', () => {
    expect(NAV_GROUP_ORDER).toEqual(['overview', 'domains', 'tools']);
    const hidden = ROUTES.filter((r) => r.hidden).map((r) => r.path);
    expect(hidden).toEqual(['/regions/view', '/reports/print']);
    expect(ROUTES.filter((r) => !r.hidden).every((r) => r.group)).toBe(true);
  });

  it('e2e regex har yozuvni o\'qiy oladi (bitta qator, path → perm)', () => {
    const text = readFileSync(resolve(__dirname, '../route-manifest.ts'), 'utf8');
    const parsed = [...text.matchAll(/\{\s*path:\s*'([^']+)',\s*perm:\s*'([^']+)'/g)].map((m) => m[1]);
    expect(parsed).toEqual(ROUTES.map((r) => r.path));
  });
});

describe('rollar', () => {
  it('viloyat hisobi hududlar ro\'yxati va solishtirishni ko\'rmaydi, qolgani ochiq', () => {
    expect(roleHas('REGIONAL', 'regions.view')).toBe(false);
    expect(roleHas('REGIONAL', 'regions.compare')).toBe(false);
    for (const perm of ['dashboard.view', 'region.view', 'domains.view', 'schools.view', 'reports.view', 'present.view', 'settings.view'] as const) {
      expect(roleHas('REGIONAL', perm), perm).toBe(true);
    }
  });

  it('respublika hisobi hamma narsani ko\'radi', () => {
    for (const r of ROUTES) expect(roleHas('NATIONAL', r.perm), r.path).toBe(true);
  });

  it('demo hisoblar: bitta respublika va viloyat hisoblari o\'z hududi bilan', () => {
    expect(DEMO_ACCOUNTS.filter((a) => a.role === 'NATIONAL')).toHaveLength(1);
    for (const a of DEMO_ACCOUNTS.filter((x) => x.role === 'REGIONAL')) expect(a.regionId).toMatch(/^UZ-[A-Z]{2}$/);
  });
});
