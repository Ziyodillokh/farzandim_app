// NFC karta kodi (NTAG 424 DNA, Secure Unique NFC): har tegishda karta NDEF
// manziliga shifrlangan PICCData (UID + 24 bitli hisoblagich) va SDMMAC
// (AES-CMAC) qo'yadi. Tekshiruv faqat serverda — kalitlar kioskka chiqmaydi.
// Algoritm: NXP AN12196 (AES rejimi); kalit hosilasi NXP sdm-backend
// (`libsdm/derive.py`) bilan bir xil — kartani shu vositalar bilan ham sozlash mumkin.

import { createCipheriv, createDecipheriv, createHmac, timingSafeEqual } from 'node:crypto';

const BLOCK = 16;
const ZERO_IV = Buffer.alloc(BLOCK);
const RB = 0x87;
/** SDMFileRead (MAC) kaliti — kartaning 2-kaliti (UID bo'yicha diversifikatsiya). */
export const SUN_FILE_KEY_NO = 2;

const DIV_PICC_DATA_KEY = Buffer.from('PICCDataKey', 'ascii');
const DIV_SLOT_MASTER_KEY = Buffer.from('SlotMasterKey', 'ascii');
const DIV_BASE_KEY = Buffer.from('DivBaseKey', 'ascii');
const SV2_PREFIX = Buffer.from('3cc300010080', 'hex');

const UID_HEX_LENGTHS = new Set([8, 14, 20]);
const PICC_PARAMS = ['p', 'picc_data', 'e'];
const CMAC_PARAMS = ['c', 'cmac'];

export interface SunParams {
  piccData: Buffer;
  cmac: Buffer;
}

export interface SunTap {
  /** 14 ta katta hex belgi. */
  uid: string;
  counter: number;
}

function aesBlock(key: Buffer, block: Buffer): Buffer {
  const cipher = createCipheriv('aes-128-ecb', key, null).setAutoPadding(false);
  return Buffer.concat([cipher.update(block), cipher.final()]);
}

function shiftLeft(input: Buffer): Buffer {
  const out = Buffer.alloc(BLOCK);
  for (let i = 0; i < BLOCK; i++) {
    out[i] = ((input[i] << 1) | (i + 1 < BLOCK ? input[i + 1] >> 7 : 0)) & 0xff;
  }
  if (input[0] & 0x80) out[BLOCK - 1] ^= RB;
  return out;
}

function xor(a: Buffer, b: Buffer): Buffer {
  return Buffer.from(a.map((v, i) => v ^ b[i]));
}

/** AES-128-CMAC (RFC 4493). */
export function aesCmac(key: Buffer, message: Buffer): Buffer {
  const k1 = shiftLeft(aesBlock(key, Buffer.alloc(BLOCK)));
  const k2 = shiftLeft(k1);
  const blocks = Math.max(1, Math.ceil(message.length / BLOCK));
  const complete = message.length > 0 && message.length % BLOCK === 0;
  const tail = message.subarray((blocks - 1) * BLOCK);
  const last = complete ? xor(tail, k1) : xor(Buffer.concat([tail, Buffer.from([0x80]), Buffer.alloc(BLOCK - tail.length - 1)]), k2);
  let state: Buffer = Buffer.alloc(BLOCK);
  for (let i = 0; i < blocks - 1; i++) state = aesBlock(key, xor(state, message.subarray(i * BLOCK, (i + 1) * BLOCK)));
  return aesBlock(key, xor(state, last));
}

const hmacSha256 = (key: Buffer, message: Buffer) => createHmac('sha256', key).update(message).digest();
const isZeroKey = (key: Buffer) => key.every((b) => b === 0);

/** SDMMetaRead kaliti (PICCData shifri) — maktab bosh kalitidan, UID'siz. */
export function deriveMetaKey(master: Buffer): Buffer {
  if (isZeroKey(master)) return Buffer.alloc(BLOCK);
  return hmacSha256(master, DIV_PICC_DATA_KEY).subarray(0, BLOCK);
}

/** Kartaning [keyNo]-kaliti — UID bo'yicha diversifikatsiya. */
export function deriveTagKey(master: Buffer, uid: Buffer, keyNo: number): Buffer {
  if (isZeroKey(master)) return Buffer.alloc(BLOCK);
  const slotKey = hmacSha256(master, Buffer.concat([DIV_SLOT_MASTER_KEY, Buffer.from([keyNo])])).subarray(0, BLOCK);
  const divBase = hmacSha256(hmacSha256(master, DIV_BASE_KEY), uid).subarray(0, BLOCK);
  return aesCmac(slotKey, Buffer.concat([Buffer.from([0x01]), divBase]));
}

/** SDMMAC: sessiya kaliti CMAC(fileKey, SV2), keyin bo'sh xabar CMAC'i, toq baytlar. */
export function sunMac(fileKey: Buffer, uidAndCounter: Buffer): Buffer {
  const sv2 = Buffer.concat([SV2_PREFIX, uidAndCounter]);
  const padded = Buffer.concat([sv2, Buffer.alloc((BLOCK - (sv2.length % BLOCK)) % BLOCK)]);
  const full = aesCmac(aesCmac(fileKey, padded), Buffer.alloc(0));
  return Buffer.from(full.filter((_, i) => i % 2 === 1));
}

/**
 * Karta kodini tekshirish: haqiqiy bo'lsa UID va hisoblagich, aks holda `null`
 * (nusxa, boshqa maktab kartasi yoki o'zgartirilgan kod).
 */
export function verifySun(params: SunParams, metaKey: Buffer, fileKeyFor: (uid: Buffer) => Buffer): SunTap | null {
  if (params.piccData.length !== BLOCK || params.cmac.length !== 8) return null;
  const decipher = createDecipheriv('aes-128-cbc', metaKey, ZERO_IV).setAutoPadding(false);
  const plain = Buffer.concat([decipher.update(params.piccData), decipher.final()]);
  const tag = plain[0];
  // UID (7 bayt) va hisoblagich aks ettirilgan bo'lishi shart — hisoblagichsiz kod qayta yuborishdan himoyalanmaydi.
  if ((tag & 0x80) === 0 || (tag & 0x40) === 0 || (tag & 0x0f) !== 7) return null;
  const uid = plain.subarray(1, 8);
  const counterBytes = plain.subarray(8, 11);
  const expected = sunMac(fileKeyFor(uid), Buffer.concat([uid, counterBytes]));
  if (!timingSafeEqual(expected, params.cmac)) return null;
  return { uid: uid.toString('hex').toUpperCase(), counter: counterBytes.readUIntLE(0, 3) };
}

function hexParam(query: URLSearchParams, names: readonly string[], length: number): Buffer | null {
  for (const name of names) {
    const value = query.get(name);
    if (value !== null) return value.length === length && /^[0-9a-f]+$/i.test(value) ? Buffer.from(value, 'hex') : null;
  }
  return null;
}

/** Kartadagi NDEF manzildan kod parametrlari (`p`/`c`, `picc_data`/`cmac`, `e`/`c`). */
export function parseSunParams(url: string): SunParams | null {
  let query: URLSearchParams;
  try {
    query = new URL(url).searchParams;
  } catch {
    return null;
  }
  const piccData = hexParam(query, PICC_PARAMS, BLOCK * 2);
  const cmac = hexParam(query, CMAC_PARAMS, 16);
  return piccData && cmac ? { piccData, cmac } : null;
}

/** Chip seriya raqami: ajratgichlarsiz katta hex (4, 7 yoki 10 bayt), aks holda `null`. */
export function normalizeUid(raw: string): string | null {
  const compact = raw.replace(/[\s:-]/g, '');
  if (!/^[0-9a-f]+$/i.test(compact) || !UID_HEX_LENGTHS.has(compact.length)) return null;
  return compact.toUpperCase();
}
