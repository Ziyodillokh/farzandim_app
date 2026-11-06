import {
  CREATED_VIA_LOGIN,
  CREATED_VIA_RECOVERED,
  decideDeviceRole,
  DEVICE_ROLES,
  isLegacyPairedUser,
} from './child-device-role';

describe('decideDeviceRole', () => {
  it('is MAIN only when the child has no current main device', () => {
    expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false })).toBe('MAIN');
  });

  it('is SECONDARY when a legacy paired device is the main', () => {
    expect(decideDeviceRole({ legacyPairedMain: true, activeLoginMain: false })).toBe('SECONDARY');
  });

  it('is SECONDARY when an active login session is the main', () => {
    expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: true })).toBe('SECONDARY');
    expect(decideDeviceRole({ legacyPairedMain: true, activeLoginMain: true })).toBe('SECONDARY');
  });

  describe('hostsControl (the device cannot enforce this child controls)', () => {
    it('defaults to true: absent and true behave like before', () => {
      expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false })).toBe('MAIN');
      expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false, hostsControl: true })).toBe('MAIN');
    });

    it('false never makes a NEW session MAIN', () => {
      expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false, hostsControl: false })).toBe('SECONDARY');
      expect(
        decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false, hostsControl: false, replacesMainOnSameDevice: false }),
      ).toBe('SECONDARY');
    });

    it('false keeps MAIN for the owner re-authenticating on the same device (replacing its own MAIN session)', () => {
      expect(
        decideDeviceRole({ legacyPairedMain: false, activeLoginMain: false, hostsControl: false, replacesMainOnSameDevice: true }),
      ).toBe('MAIN');
    });

    it('never produces a second MAIN: an existing main (legacy paired or login) always wins', () => {
      for (const hostsControl of [true, false, undefined]) {
        for (const replacesMainOnSameDevice of [true, false]) {
          expect(decideDeviceRole({ legacyPairedMain: true, activeLoginMain: false, hostsControl, replacesMainOnSameDevice })).toBe('SECONDARY');
          expect(decideDeviceRole({ legacyPairedMain: false, activeLoginMain: true, hostsControl, replacesMainOnSameDevice })).toBe('SECONDARY');
        }
      }
    });
  });

  it('knows exactly the two contract roles', () => {
    expect([...DEVICE_ROLES]).toEqual(['MAIN', 'SECONDARY']);
  });
});

describe('isLegacyPairedUser', () => {
  it('treats rows without createdVia (all existing rows) as created by legacy pairing', () => {
    expect(isLegacyPairedUser({ createdVia: null })).toBe(true);
  });

  it('does not treat login-created or recovered users as paired main devices', () => {
    expect(isLegacyPairedUser({ createdVia: CREATED_VIA_LOGIN })).toBe(false);
    expect(isLegacyPairedUser({ createdVia: CREATED_VIA_RECOVERED })).toBe(false);
  });
});
