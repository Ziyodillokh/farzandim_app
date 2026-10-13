import {
  buildSignedChildAvatarUrl,
  signChildAvatar,
  verifyChildAvatarSignature,
} from './child-avatar-signature';

describe('child avatar signed URLs (F17)', () => {
  const SECRET = 'x'.repeat(64);
  const NOW = 1_800_000_100; // soat chegarasida emas

  it('verifies a signature for the same child before it expires', () => {
    const exp = NOW + 60;
    const sig = signChildAvatar('child-1', exp, SECRET);

    expect(verifyChildAvatarSignature('child-1', String(exp), sig, SECRET, NOW)).toBe(true);
  });

  it('rejects other children, expired links, wrong secrets and garbage', () => {
    const exp = NOW + 60;
    const sig = signChildAvatar('child-1', exp, SECRET);

    expect(verifyChildAvatarSignature('child-2', String(exp), sig, SECRET, NOW)).toBe(false);
    expect(verifyChildAvatarSignature('child-1', String(exp), sig, SECRET, exp + 1)).toBe(false);
    expect(verifyChildAvatarSignature('child-1', String(exp), sig, 'y'.repeat(64), NOW)).toBe(false);
    expect(verifyChildAvatarSignature('child-1', 'abc', sig, SECRET, NOW)).toBe(false);
    expect(verifyChildAvatarSignature('child-1', undefined, undefined, SECRET, NOW)).toBe(false);
  });

  it('builds a stable hourly URL that verifies', () => {
    const a = buildSignedChildAvatarUrl('https://x.uz', 'child-1', SECRET, 3600, NOW);
    const b = buildSignedChildAvatarUrl('https://x.uz', 'child-1', SECRET, 3600, NOW + 5);
    const url = new URL(a);

    expect(a).toBe(b);
    expect(url.pathname).toBe('/api/children/child-1/avatar/image');
    expect(
      verifyChildAvatarSignature(
        'child-1',
        url.searchParams.get('exp') ?? undefined,
        url.searchParams.get('sig') ?? undefined,
        SECRET,
        NOW,
      ),
    ).toBe(true);
  });
});
