import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConsumerContentService } from './consumer-content.service';
import { BUCKETS } from '../../common/storage/storage.constants';

/**
 * @Public media-proxy (`GET /api/content/media/:segment/:file`) bildirishnoma
 * rasmlarini ham beradi: `notif` → farzandim-content-thumbnails/notifications/.
 */
describe('Content media proxy — segmentlar', () => {
  const getObjectStream = jest.fn().mockResolvedValue({ stream: null, contentType: 'image/jpeg' });
  const service = new ConsumerContentService({} as never, { getObjectStream } as never, {} as never);

  beforeEach(() => getObjectStream.mockClear());

  it("'notif' → contentThumbnails bucket, notifications/ papkasi", async () => {
    await service.getMediaStream('notif', 'abc-123.jpg');
    expect(getObjectStream).toHaveBeenCalledWith(
      BUCKETS.contentThumbnails,
      'notifications/abc-123.jpg',
      undefined,
    );
  });

  it("mavjud 'thumb' segmenti o'zgarmagan", async () => {
    await service.getMediaStream('thumb', 'x.png');
    expect(getObjectStream).toHaveBeenCalledWith(BUCKETS.contentThumbnails, 'thumbnails/x.png', undefined);
  });

  it("'notif' bilan yo'l aylanib o'tish rad etiladi", async () => {
    await expect(service.getMediaStream('notif', '../secret.jpg')).rejects.toBeInstanceOf(BadRequestException);
    expect(getObjectStream).not.toHaveBeenCalled();
  });

  it("noma'lum segment — 404", async () => {
    await expect(service.getMediaStream('avatars', 'x.jpg')).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each(['constructor', '__proto__', 'toString'])("prototip kaliti '%s' — 404, storage chaqirilmaydi", async (seg) => {
    await expect(service.getMediaStream(seg, 'a.jpg')).rejects.toBeInstanceOf(NotFoundException);
    expect(getObjectStream).not.toHaveBeenCalled();
  });

  it("MinIO'da fayl yo'q (NoSuchKey) — 500 emas, 404 'Media file not found'", async () => {
    getObjectStream.mockRejectedValueOnce(Object.assign(new Error('The specified key does not exist.'), { name: 'NoSuchKey' }));
    await expect(service.getMediaStream('notif', 'yoq.jpg')).rejects.toThrow(new NotFoundException('Media file not found'));
  });

  it('boshqa storage xatolari yutib yuborilmaydi', async () => {
    getObjectStream.mockRejectedValueOnce(new Error('connect ECONNREFUSED'));
    await expect(service.getMediaStream('notif', 'a.jpg')).rejects.toThrow('ECONNREFUSED');
  });
});
