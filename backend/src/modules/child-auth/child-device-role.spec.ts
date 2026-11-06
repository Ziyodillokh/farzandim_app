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
