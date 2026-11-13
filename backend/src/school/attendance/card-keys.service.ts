// NTAG 424 DNA kartalar uchun maktab bosh kaliti (16 bayt): `schools.card_key` da
// SchoolCryptoService bilan shifrlangan. Kartaning kalitlari undan hosila qilinadi
// (`card-sun.ts`); bosh kalit panel API'si orqali hech qachon qaytarilmaydi —
// kartani sozlash faqat operator skripti bilan (`scripts/school/card-keys.ts`).
// Kalit yaratilmagan maktab zavod kalitlari (nol) bilan sozlangan kartalarni qabul
// qiladi — faqat sinov uchun: bunday kodni har kim yasay oladi.

import { Injectable } from '@nestjs/common';
import { SchoolCardKind } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../common/database/prisma.service';
import { SchoolCryptoService } from '../common/school-crypto.service';
import { invalid } from '../common/school-errors';
import { msg } from '../common/school-zod';
import { deriveMetaKey, deriveTagKey, normalizeUid, parseSunParams, SUN_FILE_KEY_NO, verifySun } from './card-sun';

const KEY_BYTES = 16;
const FACTORY_KEY = Buffer.alloc(KEY_BYTES);

/** O'qilgan karta: UID, turi va (NTAG 424 DNA bo'lsa) tegishlar hisoblagichi. */
export interface CardIdentity {
  uid: string;
  kind: SchoolCardKind;
  counter: number | null;
}

@Injectable()
export class CardKeyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly crypto: SchoolCryptoService,
  ) {}

  /** Maktab bosh kaliti; hali yaratilmagan bo'lsa — `null`. */
  async find(schoolId: string): Promise<Buffer | null> {
    const school = await this.prisma.school.findUnique({ where: { id: schoolId }, select: { cardKey: true } });
    return school?.cardKey ? Buffer.from(this.crypto.decrypt(school.cardKey), 'hex') : null;
  }

  /** Bor kalit yoki yangisi (parallel chaqiruvda ham bitta kalit qoladi). */
  async ensure(schoolId: string): Promise<Buffer> {
    const existing = await this.find(schoolId);
    if (existing) return existing;
    const fresh = this.crypto.encrypt(randomBytes(KEY_BYTES).toString('hex'));
    await this.prisma.school.updateMany({ where: { id: schoolId, cardKey: null }, data: { cardKey: fresh } });
    const stored = await this.find(schoolId);
    if (!stored) throw new Error(`card key missing for school ${schoolId}`);
    return stored;
  }

  /**
   * Kartani aniqlash: manzilda imzolangan kod bo'lsa — tekshirilgan UID va hisoblagich (SUN);
   * kod buzilgan / boshqa kalit bilan — `null`; kod bo'lmasa — seriya raqami (UID).
   */
  async identify(schoolId: string, data: { uid?: string; url?: string }): Promise<CardIdentity | null> {
    const params = data.url ? parseSunParams(data.url) : null;
    if (params) {
      const master = (await this.find(schoolId)) ?? FACTORY_KEY;
      const tap = verifySun(params, deriveMetaKey(master), (uid) => deriveTagKey(master, uid, SUN_FILE_KEY_NO));
      return tap ? { uid: tap.uid, kind: 'SUN', counter: tap.counter } : null;
    }
    const uid = data.uid ? normalizeUid(data.uid) : null;
    if (!uid) throw invalid(`uid: ${msg.cardUid}`);
    return { uid, kind: 'UID', counter: null };
  }
}
