import { afterEach, describe, expect, it, vi } from 'vitest';

import { fetchPublicBrand } from '../public-brand';

describe('public brand', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('maktab topilsa — brend; kod URL\'da kodlanadi', async () => {
    const brand = { name: '14-maktab', shortName: '14', logo: null, city: 'Toshkent', academicYear: '2026–2027' };
    const fetchMock = vi.fn(async () => new Response(JSON.stringify(brand), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    expect(await fetchPublicBrand('demo 14')).toEqual(brand);
    expect(String((fetchMock.mock.calls[0] as unknown[])[0])).toContain('/school/public/brand?code=demo%2014');
  });

  it('topilmasa yoki tarmoq yo\'q — null', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 404 })));
    expect(await fetchPublicBrand('x')).toBeNull();
    vi.stubGlobal('fetch', vi.fn(async () => Promise.reject(new TypeError('offline'))));
    expect(await fetchPublicBrand('x')).toBeNull();
  });
});
