import admin from 'firebase-admin';
import { FcmService } from './fcm.service';

jest.mock('firebase-admin', () => {
  const sendEachForMulticast = jest.fn();
  return {
    __esModule: true,
    default: { messaging: () => ({ sendEachForMulticast }) },
  };
});

/**
 * Bola qurilmasini qayta sync qildiruvchi jim push (`restrictions_sync`).
 * iOS'da ilova fonda/yopiq bo'lsa ota-ona o'zgarishi faqat shu push bilan
 * yetib boradi — Apple talablari (push-type, priority) shu yerda pinlanadi.
 */
describe('FcmService — restrictions_sync', () => {
  const CHILD_USER = 'child-user-1';

  let prisma: { fcmToken: { findMany: jest.Mock; deleteMany: jest.Mock } };
  let service: FcmService;
  const sendEachForMulticast = admin.messaging()
    .sendEachForMulticast as jest.Mock;

  beforeEach(() => {
    sendEachForMulticast.mockReset();
    prisma = {
      fcmToken: {
        findMany: jest.fn().mockResolvedValue([{ token: 'ios-token' }]),
        deleteMany: jest.fn(),
      },
    };
    service = new FcmService({ get: () => undefined } as never, prisma as never);
    // firebase-admin init'ni chetlab o'tamiz (service account test'da yo'q).
    (service as unknown as { initialized: boolean }).initialized = true;
  });

  it('childUserId bo\'lmasa hech narsa yubormaydi', async () => {
    await service.pushChildResync(null);

    expect(prisma.fcmToken.findMany).not.toHaveBeenCalled();
  });

  it('sof data push sifatida restrictions_sync yuboradi', async () => {
    sendEachForMulticast.mockResolvedValue({ responses: [{ success: true }] });

    await service.pushChildResync(CHILD_USER);

    const message = sendEachForMulticast.mock.calls[0][0];
    expect(message.notification).toBeUndefined();
    expect(message.data).toEqual({ type: 'restrictions_sync' });
  });

  it('iOS uchun Apple fon push sarlavhalarini qo\'yadi', async () => {
    sendEachForMulticast.mockResolvedValue({ responses: [{ success: true }] });

    await service.pushChildResync(CHILD_USER);

    const { apns } = sendEachForMulticast.mock.calls[0][0];
    expect(apns.headers).toMatchObject({
      'apns-push-type': 'background',
      'apns-priority': '5',
    });
    expect(apns.payload).toEqual({ aps: { 'content-available': 1 } });
  });

  it('push xatosini yutadi (chaqiruvchi yiqilmaydi)', async () => {
    sendEachForMulticast.mockRejectedValue(new Error('FCM down'));

    await expect(service.pushChildResync(CHILD_USER)).resolves.toBeUndefined();
  });
});
