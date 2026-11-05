import { signChildAvatar } from '../../common/helpers/child-avatar-signature';
import { buildSignedHomeworkPhotoUrl, signHomeworkPhoto, verifyHomeworkPhotoSignature } from './homework-signature';

describe('homework photo signed links', () => {
  const SECRET = 'x'.repeat(64);
  const NOW = 1_800_000_100;

  it('verifies the same photo before expiry', () => {
    const exp = NOW + 60;
    const sig = signHomeworkPhoto('photo-1', exp, SECRET);

    expect(verifyHomeworkPhotoSignature('photo-1', String(exp), sig, SECRET, NOW)).toBe(true);
  });

  it('rejects other photos, expired links, wrong secrets and malformed input', () => {
    const exp = NOW + 60;
    const sig = signHomeworkPhoto('photo-1', exp, SECRET);

    expect(verifyHomeworkPhotoSignature('photo-2', String(exp), sig, SECRET, NOW)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', String(exp), sig, SECRET, exp + 1)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', String(exp), sig, 'y'.repeat(64), NOW)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', String(exp + 1), sig, SECRET, NOW)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', 'abc', sig, SECRET, NOW)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', undefined, undefined, SECRET, NOW)).toBe(false);
    expect(verifyHomeworkPhotoSignature('photo-1', String(exp), 'short', SECRET, NOW)).toBe(false);
  });

  it('is domain-separated from child avatar signatures', () => {
    const exp = NOW + 60;

    expect(signHomeworkPhoto('id-1', exp, SECRET)).not.toBe(signChildAvatar('id-1', exp, SECRET));
  });

  it('builds a stable hourly link of 1-2 hours that verifies', () => {
    const a = buildSignedHomeworkPhotoUrl('https://x.uz/', 'photo-1', SECRET, NOW);
    const b = buildSignedHomeworkPhotoUrl('https://x.uz', 'photo-1', SECRET, NOW + 5);
    const url = new URL(a);
    const exp = Number(url.searchParams.get('exp'));

    expect(a).toBe(b);
    expect(url.pathname).toBe('/api/school/homework/photos/photo-1');
    expect(exp - NOW).toBeGreaterThanOrEqual(3600);
    expect(exp - NOW).toBeLessThanOrEqual(7200);
    expect(verifyHomeworkPhotoSignature('photo-1', url.searchParams.get('exp') ?? undefined, url.searchParams.get('sig') ?? undefined, SECRET, NOW)).toBe(true);
  });
});
