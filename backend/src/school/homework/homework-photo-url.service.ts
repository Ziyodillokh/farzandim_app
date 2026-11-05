import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EnvConfig } from '../../common/config/env.schema';
import { buildSignedHomeworkPhotoUrl, verifyHomeworkPhotoSignature } from './homework-signature';

/** Imzolangan rasm havolalari (xodim paneli va bola ilovasi uchun bir xil). */
@Injectable()
export class HomeworkPhotoUrlService {
  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  url(photoId: string): string {
    return buildSignedHomeworkPhotoUrl(
      this.config.get('PUBLIC_BASE_URL', { infer: true }),
      photoId,
      this.config.get('JWT_ACCESS_SECRET', { infer: true }),
    );
  }

  isValid(photoId: string, exp: string | undefined, sig: string | undefined): boolean {
    return verifyHomeworkPhotoSignature(photoId, exp, sig, this.config.get('JWT_ACCESS_SECRET', { infer: true }));
  }
}
