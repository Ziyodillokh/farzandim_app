// Yozma vazifa rasmlari uchun MinIO (`farzandim-school-homework`) o'rami: yuklash, o'qish
// va BEST-EFFORT o'chirish (bitta obyekt yiqilsa qolganlari davom etadi, faqat log).

import { Injectable, Logger } from '@nestjs/common';
import { BUCKETS } from '../../common/storage/storage.constants';
import { StorageService } from '../../common/storage/storage.service';

@Injectable()
export class HomeworkStorageService {
  private readonly logger = new Logger(HomeworkStorageService.name);

  constructor(private readonly storage: StorageService) {}

  upload(key: string, body: Buffer, contentType: string): Promise<void> {
    return this.storage.upload(BUCKETS.schoolHomework, key, body, contentType);
  }

  read(key: string): Promise<{ body: Buffer; contentType: string }> {
    return this.storage.getObject(BUCKETS.schoolHomework, key);
  }

  async deleteKeys(keys: readonly string[]): Promise<void> {
    if (keys.length === 0) return;
    const results = await Promise.allSettled(keys.map((key) => this.storage.delete(BUCKETS.schoolHomework, key)));
    const failed = results.filter((r) => r.status === 'rejected').length;
    if (failed > 0) this.logger.warn(`vazifa rasmlari: ${failed}/${keys.length} obyekt o'chirilmadi`);
  }
}
