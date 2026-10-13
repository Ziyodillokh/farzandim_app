import {
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ChildrenService } from './children.service';
import { signChildAvatar } from '../../common/helpers/child-avatar-signature';

/** F17: bola rasmi proksisi auth'siz ochiq emas. */
describe('ChildrenService.getAvatarObject access', () => {
  const SECRET = 's'.repeat(64);
  const CHILD = {
    id: 'child-1',
    parentId: 'parent-1',
    childUserId: 'child-user-1',
    photoPath: 'child-avatars/child-1.jpg',
  };

  let prisma: { child: { findUnique: jest.Mock } };
  let storage: { getObject: jest.Mock };
  let env: Record<string, string | undefined>;
  let service: ChildrenService;

  beforeEach(() => {
    prisma = { child: { findUnique: jest.fn().mockResolvedValue(CHILD) } };
    storage = {
      getObject: jest.fn().mockResolvedValue({ body: 'bytes', contentType: 'image/jpeg' }),
    };
    // Qat'iy rejim (ochiq rejim standart yoqiq — pastdagi alohida test).
    env = { JWT_ACCESS_SECRET: SECRET, CHILD_AVATAR_PUBLIC_LEGACY: 'false' };
    const config = { get: (key: string) => env[key] };
    service = new ChildrenService(
      prisma as never,
      storage as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      config as never,
      {} as never,
    );
  });

  it('rejects anonymous requests without touching the database', async () => {
    await expect(service.getAvatarObject(CHILD.id, {})).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(prisma.child.findUnique).not.toHaveBeenCalled();
  });

  it('serves the parent and the child themselves', async () => {
    const asParent = await service.getAvatarObject(CHILD.id, {
      viewer: { userId: 'parent-1', role: 'PARENT' },
    });
    const asChild = await service.getAvatarObject(CHILD.id, {
      viewer: { userId: 'child-user-1', role: 'CHILD' },
    });

    expect(asParent.contentType).toBe('image/jpeg');
    expect(asChild.contentType).toBe('image/jpeg');
  });

  it('forbids other signed-in users', async () => {
    await expect(
      service.getAvatarObject(CHILD.id, {
        viewer: { userId: 'stranger', role: 'PARENT' },
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('does not reveal whether an unknown child exists to strangers', async () => {
    prisma.child.findUnique.mockResolvedValue(null);

    await expect(
      service.getAvatarObject('missing', { viewer: { userId: 'x', role: 'PARENT' } }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('serves a valid signed link (admin panel <img>)', async () => {
    const exp = Math.floor(Date.now() / 1000) + 600;
    const sig = signChildAvatar(CHILD.id, exp, SECRET);

    const obj = await service.getAvatarObject(CHILD.id, { exp: String(exp), sig });

    expect(obj.contentType).toBe('image/jpeg');
  });

  it('allows anonymous access when the legacy flag is on', async () => {
    env.CHILD_AVATAR_PUBLIC_LEGACY = 'true';

    const obj = await service.getAvatarObject(CHILD.id, {});

    expect(obj.contentType).toBe('image/jpeg');
  });

  it('keeps released apps working: anonymous access is allowed by default', async () => {
    delete env.CHILD_AVATAR_PUBLIC_LEGACY;

    const obj = await service.getAvatarObject(CHILD.id, {});

    expect(obj.contentType).toBe('image/jpeg');
  });

  it('returns 404 to family members when there is no photo', async () => {
    prisma.child.findUnique.mockResolvedValue({ ...CHILD, photoPath: null });

    await expect(
      service.getAvatarObject(CHILD.id, {
        viewer: { userId: 'parent-1', role: 'PARENT' },
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
