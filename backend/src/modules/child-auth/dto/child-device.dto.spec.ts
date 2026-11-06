import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { ChildLoginDto, ChildSetupDto } from './child-login.dto';

// Ishlab chiqarishdagi bilan bir xil quvur (configure-app.ts).
const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
const run = <T>(metatype: new () => T, value: unknown) => pipe.transform(value, { type: 'body', metatype }) as Promise<T>;

const device = (extra: Record<string, unknown> = {}) => ({ id: 'install-1', model: 'Redmi', platform: 'android', ...extra });
const login = (dev: Record<string, unknown>) => ({ login: 'aziza.k24', password: 'x', device: dev });
const setup = (dev: Record<string, unknown>) => ({ setupToken: 't', newPassword: 'Kitob2026', device: dev });

describe('device.hostsControl validation (child-login and child-setup)', () => {
  it.each([
    ['child-login', ChildLoginDto, login],
    ['child-setup', ChildSetupDto, setup],
  ] as const)('%s accepts it as true, false and absent, keeping the value as a real boolean', async (_name, type, body) => {
    const absent = await run(type as never, body(device())) as { device: Record<string, unknown> };
    const on = await run(type as never, body(device({ hostsControl: true }))) as { device: Record<string, unknown> };
    const off = await run(type as never, body(device({ hostsControl: false }))) as { device: Record<string, unknown> };

    expect(absent.device.hostsControl).toBeUndefined();
    expect(on.device.hostsControl).toBe(true);
    expect(off.device.hostsControl).toBe(false);
  });

  it.each([
    ['the string "false"', 'false'],
    ['the string "true"', 'true'],
    ['0', 0],
    ['1', 1],
    ['an object', {}],
    ['an array', [false]],
  ])('rejects %s (no implicit conversion: "false" must never become true)', async (_name, value) => {
    await expect(run(ChildLoginDto, login(device({ hostsControl: value })))).rejects.toBeInstanceOf(BadRequestException);
    await expect(run(ChildSetupDto, setup(device({ hostsControl: value })))).rejects.toBeInstanceOf(BadRequestException);
  });

  it('treats null like an absent value (the default applies)', async () => {
    const dto = (await run(ChildLoginDto, login(device({ hostsControl: null })))) as { device: { hostsControl?: boolean | null } };

    expect(dto.device.hostsControl ?? true).toBe(true);
  });

  it('still forbids unknown device fields', async () => {
    await expect(run(ChildLoginDto, login(device({ hostsControl: false, extra: 1 })))).rejects.toBeInstanceOf(BadRequestException);
  });
});
