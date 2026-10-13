import { getClientIp } from './client-ip';
import { DEFAULT_TRUST_PROXY, resolveTrustProxy } from './trust-proxy';

describe('resolveTrustProxy (F41)', () => {
  it('trusts only the local proxy by default', () => {
    expect(resolveTrustProxy(undefined)).toBe(DEFAULT_TRUST_PROXY);
    expect(resolveTrustProxy('  ')).toBe('loopback');
  });

  it('parses booleans, hop counts and address lists', () => {
    expect(resolveTrustProxy('false')).toBe(false);
    expect(resolveTrustProxy('true')).toBe(true);
    expect(resolveTrustProxy('1')).toBe(1);
    expect(resolveTrustProxy('127.0.0.1,10.0.0.0/8')).toBe('127.0.0.1,10.0.0.0/8');
  });
});

describe('getClientIp (F41)', () => {
  it('uses request.ip and ignores a spoofed X-Forwarded-For header', () => {
    const req = {
      ip: '203.0.113.7',
      headers: { 'x-forwarded-for': '1.2.3.4, 203.0.113.7' },
    };

    expect(getClientIp(req)).toBe('203.0.113.7');
  });

  it('strips the IPv4-mapped IPv6 prefix and falls back to the socket', () => {
    expect(getClientIp({ ip: '::ffff:198.51.100.2' })).toBe('198.51.100.2');
    expect(getClientIp({ socket: { remoteAddress: '127.0.0.1' } })).toBe('127.0.0.1');
    expect(getClientIp(undefined)).toBe('');
  });
});
