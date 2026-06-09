import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client, TokenPayload } from 'google-auth-library';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';
import { EnvConfig } from '../../../common/config/env.schema';

/** Google ID token tekshiruvidan keladigan minimal foydalanuvchi ma'lumotlari. */
export interface VerifiedSocialUser {
  /** Provider'dagi stabil yagona ID (Google `sub` yoki Apple `sub`). */
  sub: string;
  /** Email — odatda bor (Google'da har doim, Apple'da birinchi loginda). */
  email?: string;
  /** Email tasdiqlanganmi (Google `email_verified`, Apple `email_verified`). */
  emailVerified?: boolean;
  /** To'liq ism — Google bersa. Apple alohida endpoint orqali yuboradi. */
  name?: string;
  /** Profil rasmi — faqat Google. */
  picture?: string;
}

/**
 * Google va Apple ID token'larini tekshiradi (signature + audience + expiry).
 *
 * Frontend Google/Apple SDK'lardan **ID token** olib backend'ga yuboradi.
 * Backend bu yerda token'ni tasdiqlaydi va user ma'lumotini qaytaradi —
 * keyin `AuthService` upsert qiladi va JWT chiqaradi.
 */
@Injectable()
export class SocialAuthService {
  private readonly logger = new Logger(SocialAuthService.name);

  /** Google'ning rasmiy OAuth client'i — JWKS'ni kechiradi. */
  private readonly googleClient = new OAuth2Client();

  /** Apple'ning rasmiy JWKS endpoint'i (kalitlar shu yerdan keladi). */
  private readonly appleJwks = createRemoteJWKSet(
    new URL('https://appleid.apple.com/auth/keys'),
  );

  constructor(private readonly config: ConfigService<EnvConfig, true>) {}

  /** Vergul-ajratilgan GOOGLE_CLIENT_IDS'ni massivga aylantiradi. */
  private googleAudiences(): string[] {
    const raw = this.config.get('GOOGLE_CLIENT_IDS', { infer: true });
    if (!raw) return [];
    return raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  /** Apple uchun ruxsat etilgan audiences — bundle ID + service ID. */
  private appleAudiences(): string[] {
    const bundleId = this.config.get('APPLE_BUNDLE_ID', { infer: true });
    const serviceId = this.config.get('APPLE_SERVICE_ID', { infer: true });
    return [bundleId, serviceId].filter((v): v is string => Boolean(v));
  }

  /** Google sozlanganmi (kamida bitta client ID bor). */
  isGoogleEnabled(): boolean {
    return this.googleAudiences().length > 0;
  }

  /** Apple sozlanganmi (kamida bitta audience bor). */
  isAppleEnabled(): boolean {
    return this.appleAudiences().length > 0;
  }

  /**
   * Google ID token'ni tekshiradi.
   * - JWT signature (Google JWKS)
   * - issuer = accounts.google.com yoki https://accounts.google.com
   * - audience = sozlangan client ID'lardan biri
   * - exp/iat
   */
  async verifyGoogleIdToken(idToken: string): Promise<VerifiedSocialUser> {
    const audiences = this.googleAudiences();
    if (audiences.length === 0) {
      throw new UnauthorizedException('Google Sign In sozlanmagan');
    }

    let ticket: { getPayload: () => TokenPayload | undefined };
    try {
      ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: audiences,
      });
    } catch (err) {
      this.logger.warn({ err }, 'Google ID token verification failed');
      throw new UnauthorizedException('Google token yaroqsiz');
    }

    const payload = ticket.getPayload();
    if (!payload || !payload.sub) {
      throw new UnauthorizedException('Google token bo\'sh');
    }

    return {
      sub: payload.sub,
      email: payload.email?.toLowerCase(),
      emailVerified: payload.email_verified === true,
      name: payload.name,
      picture: payload.picture,
    };
  }

  /**
   * Apple ID token'ni tekshiradi.
   * - issuer = https://appleid.apple.com
   * - audience = sozlangan bundle/service ID
   * - signature = Apple JWKS
   *
   * Eslatma: Apple `name`'ni faqat birinchi roziligida yuboradi — uni Flutter
   * tomonida ushlab backend'ga alohida yuborish kerak.
   */
  async verifyAppleIdToken(idToken: string): Promise<VerifiedSocialUser> {
    const audiences = this.appleAudiences();
    if (audiences.length === 0) {
      throw new UnauthorizedException('Apple Sign In sozlanmagan');
    }

    let payload: JWTPayload;
    try {
      const { payload: p } = await jwtVerify(idToken, this.appleJwks, {
        issuer: 'https://appleid.apple.com',
        audience: audiences,
      });
      payload = p;
    } catch (err) {
      this.logger.warn({ err }, 'Apple ID token verification failed');
      throw new UnauthorizedException('Apple token yaroqsiz');
    }

    const sub = typeof payload.sub === 'string' ? payload.sub : null;
    if (!sub) {
      throw new UnauthorizedException('Apple token sub yo\'q');
    }

    const email = typeof payload.email === 'string' ? payload.email : undefined;
    // Apple `email_verified` string ("true") yoki boolean bo'lishi mumkin.
    const ev = (payload as Record<string, unknown>).email_verified;
    const emailVerified = ev === true || ev === 'true';

    return {
      sub,
      email: email?.toLowerCase(),
      emailVerified,
    };
  }
}
