import { withPlatformDefaults } from './app-version.service';

describe('withPlatformDefaults (F42)', () => {
  const base = {
    android: { latest: '1.0.7', minSupported: '1.0.0' },
    ios: { latest: '1.0.0', minSupported: '1.0.0' },
    releaseNotes: 'Android 16',
    isForceUpdate: true,
  };

  it('copies the top-level values into platforms that do not override them', () => {
    const out = withPlatformDefaults(base);

    expect(out.android.isForceUpdate).toBe(true);
    expect(out.android.releaseNotes).toBe('Android 16');
    expect(out.ios.isForceUpdate).toBe(true);
  });

  it('keeps per-platform overrides and the legacy top-level fields', () => {
    const out = withPlatformDefaults({
      ...base,
      ios: { ...base.ios, isForceUpdate: false, releaseNotes: 'iOS' },
    });

    expect(out.ios.isForceUpdate).toBe(false);
    expect(out.ios.releaseNotes).toBe('iOS');
    expect(out.android.isForceUpdate).toBe(true);
    expect(out.isForceUpdate).toBe(true);
    expect(out.releaseNotes).toBe('Android 16');
  });

  it('does not mutate the input', () => {
    const input = JSON.parse(JSON.stringify(base));

    withPlatformDefaults(input);

    expect(input).toEqual(base);
  });
});
