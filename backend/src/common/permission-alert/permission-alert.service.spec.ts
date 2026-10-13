import { PermissionAlertService } from './permission-alert.service';

/**
 * Bola telefonida muhim ruxsat o'chganda ota-onaga ogohlantirish. iOS'da
 * "Ekran vaqti" (Family Controls) o'chsa ilovalar cheklovi umuman
 * ishlamaydi — ota-ona buni aniq bilishi shart.
 */
describe('PermissionAlertService — Ekran vaqti', () => {
  const CHILD = { id: 'child-1', name: 'Ali', parentId: 'parent-1' };
  const ALL_GRANTED = {
    locationPermission: true,
    notificationPermission: true,
    backgroundAllowed: null,
    accessibilityEnabled: null,
    screenTimePermission: true,
  };

  let fcm: { sendPushToUser: jest.Mock };
  let prisma: { notification: { create: jest.Mock } };
  let service: PermissionAlertService;

  beforeEach(() => {
    fcm = { sendPushToUser: jest.fn().mockResolvedValue(undefined) };
    prisma = { notification: { create: jest.fn() } };
    service = new PermissionAlertService(prisma as never, fcm as never);
  });

  it("Ekran vaqti o'chsa ota-onaga aniq sabab bilan push yuboradi", async () => {
    await service.checkCrossings(CHILD, ALL_GRANTED, {
      screenTimePermission: false,
    });

    expect(fcm.sendPushToUser).toHaveBeenCalledTimes(1);
    const [userId, payload] = fcm.sendPushToUser.mock.calls[0];
    expect(userId).toBe(CHILD.parentId);
    expect(payload.body).toContain('"Ekran vaqti"');
    expect(payload.body).toContain("iPhone'da ilovalar cheklovi");
    expect(payload.data).toMatchObject({
      type: 'permission_changed',
      permissions: 'Ekran vaqti',
    });
    expect(prisma.notification.create).toHaveBeenCalledTimes(1);
  });

  it("holat o'zgarmasa yoki avval noma'lum bo'lsa push yo'q", async () => {
    await service.checkCrossings(CHILD, ALL_GRANTED, {
      screenTimePermission: true,
    });
    await service.checkCrossings(
      CHILD,
      { ...ALL_GRANTED, screenTimePermission: null },
      { screenTimePermission: false },
    );

    expect(fcm.sendPushToUser).not.toHaveBeenCalled();
  });

  it("boshqa ruxsat o'chsa Ekran vaqti izohi qo'shilmaydi", async () => {
    await service.checkCrossings(CHILD, ALL_GRANTED, {
      locationPermission: false,
    });

    const [, payload] = fcm.sendPushToUser.mock.calls[0];
    expect(payload.body).not.toContain('iPhone');
  });
});
