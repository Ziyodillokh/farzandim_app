import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ChildSetupTokens } from './child-setup-token';
import { SETUP_TOKEN_AUDIENCE, SETUP_TOKEN_TTL_SECONDS } from './child-auth.constants';

const ACCESS_SECRET = 'unit-access-secret-'.padEnd(48, 'a');
const REFRESH_SECRET = 'unit-refresh-secret-'.padEnd(48, 'b');

function makeTokens(accessSecret = ACCESS_SECRET) {
  const jwt = new JwtService({});
  const config = { get: jest.fn().mockReturnValue(accessSecret) } as unknown as ConfigService<never, true>;
  return { jwt, tokens: new ChildSetupTokens(jwt, config as never) };
}

describe('ChildSetupTokens', () => {
  it('round-trips the child id and the password fingerprint', () => {
    const { tokens } = makeTokens();

    const claims = tokens.verify(tokens.sign('child-1', '$2a$12$hash-one'));

    expect(claims).toEqual({ childId: 'child-1', fingerprint: tokens.fingerprint('$2a$12$hash-one') });
  });

  it('lives 15 minutes', () => {
    const { tokens, jwt } = makeTokens();

    const decoded = jwt.decode(tokens.sign('child-1', 'hash')) as { exp: number; iat: number; aud: string };

    expect(decoded.exp - decoded.iat).toBe(SETUP_TOKEN_TTL_SECONDS);
    expect(SETUP_TOKEN_TTL_SECONDS).toBe(15 * 60);
    expect(decoded.aud).toBe(SETUP_TOKEN_AUDIENCE);
  });

  it('changes the fingerprint when the password hash changes (this is what makes it single-use)', () => {
    const { tokens } = makeTokens();

    expect(tokens.fingerprint('hash-a')).not.toBe(tokens.fingerprint('hash-b'));
    expect(tokens.fingerprint('hash-a')).toBe(tokens.fingerprint('hash-a'));
    expect(tokens.fingerprint('hash-a')).toHaveLength(32);
  });

  it('never exposes the password hash inside the token', () => {
    const { tokens } = makeTokens();
    const token = tokens.sign('child-1', '$2a$12$abcdefghijklmnopqrstuv');

    const payload = Buffer.from(token.split('.')[1]!, 'base64url').toString('utf8');

    expect(payload).not.toContain('abcdefghijklmnopqrstuv');
    expect(payload).not.toContain('hash');
  });

  it('rejects an expired token', () => {
    const { tokens, jwt } = makeTokens();
    const secret = (tokens as unknown as { secret: string }).secret;
    const expired = jwt.sign(
      { purpose: 'child-setup', cid: 'child-1', fp: 'x' },
      { secret, audience: SETUP_TOKEN_AUDIENCE, issuer: 'farzandim-backend', expiresIn: -10 },
    );

    expect(tokens.verify(expired)).toBeNull();
  });

  it('rejects a token with the wrong purpose, audience, issuer or key', () => {
    const { tokens, jwt } = makeTokens();
    const secret = (tokens as unknown as { secret: string }).secret;
    const base = { purpose: 'child-setup', cid: 'child-1', fp: 'x' };
    const opts = { secret, audience: SETUP_TOKEN_AUDIENCE, issuer: 'farzandim-backend', expiresIn: 60 };

    expect(tokens.verify(jwt.sign({ ...base, purpose: 'other' }, opts))).toBeNull();
    expect(tokens.verify(jwt.sign(base, { ...opts, audience: 'farzandim-consumer' }))).toBeNull();
    expect(tokens.verify(jwt.sign(base, { ...opts, issuer: 'someone-else' }))).toBeNull();
    expect(tokens.verify(jwt.sign(base, { ...opts, secret: ACCESS_SECRET }))).toBeNull();
    expect(tokens.verify(jwt.sign({ purpose: 'child-setup' }, opts))).toBeNull();
    expect(tokens.verify('not-a-token')).toBeNull();
    expect(tokens.verify('')).toBeNull();
  });

  it('is not interchangeable with an access token: an access token is not a setup token and vice versa', () => {
    const { tokens, jwt } = makeTokens();
    const access = jwt.sign(
      { userId: 'u1', role: 'CHILD', tokenVersion: 0 },
      { secret: ACCESS_SECRET, audience: 'farzandim-consumer', issuer: 'farzandim-backend', expiresIn: 60 },
    );
    const refresh = jwt.sign(
      { userId: 'u1', role: 'CHILD', tokenVersion: 0 },
      { secret: REFRESH_SECRET, audience: 'farzandim-consumer', issuer: 'farzandim-backend', expiresIn: 60 },
    );
    const setup = tokens.sign('child-1', 'hash');

    expect(tokens.verify(access)).toBeNull();
    expect(tokens.verify(refresh)).toBeNull();
    // Setup token JWT_ACCESS_SECRET bilan HAM, consumer audience bilan HAM tekshirilganda o'tmaydi (Bearer / WS).
    expect(() =>
      jwt.verify(setup, { secret: ACCESS_SECRET, audience: 'farzandim-consumer', issuer: 'farzandim-backend' }),
    ).toThrow();
    expect(() => jwt.verify(setup, { secret: ACCESS_SECRET })).toThrow();
  });

  it('is bound to the deployment secret: a token from another secret is rejected', () => {
    const other = makeTokens('other-secret-'.padEnd(48, 'z'));
    const mine = makeTokens();

    expect(mine.tokens.verify(other.tokens.sign('child-1', 'hash'))).toBeNull();
  });
});
