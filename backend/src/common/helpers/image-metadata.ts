// ─────────────────────────────────────────────────────────────────────
// image-metadata — yuklangan bola rasmlaridan EXIF/GPS'ni olib tashlash
// ─────────────────────────────────────────────────────────────────────
//
// Telefon kamerasi/galereyasi rasmi EXIF ichida GPS koordinata, qurilma
// modeli, sana va h.k. saqlaydi. Android image_picker `maxWidth` bilan
// qayta kodlaganda ham GPS teglarini nusxalaydi. Bola rasmi ota-onaga va
// (avval) reytingdagi begonalarga ko'rsatilgani uchun bu metadata bolaning
// uy manzilini oshkor qilishi mumkin edi (App Store audit F17).
//
// sharp kabi og'ir native kutubxona o'rniga baytlar darajasida ishlaymiz:
//   - JPEG: APP1 (Exif/XMP), APP13 (IPTC) va COM segmentlari olib
//     tashlanadi. Orientation (0x0112) SAQLANADI — aks holda Android
//     rasmlari yonboshlab ko'rinardi (image_picker piksellarni aylantirmaydi).
//   - PNG: eXIf va matn (tEXt/zTXt/iTXt) chunk'lari olib tashlanadi.
//   - WebP: EXIF va XMP chunk'lari olib tashlanadi, VP8X bayroqlari tuzatiladi.
// Fayl taniqli formatda bo'lmasa yoki buzilgan bo'lsa — o'zgarishsiz
// qaytariladi (yuklash buzilmasin; tekshiruv mime-type bo'yicha oldinda).

const JPEG_SOI = 0xd8;
const JPEG_SOS = 0xda;
const JPEG_EOI = 0xd9;
const JPEG_APP0 = 0xe0;
const JPEG_APP1 = 0xe1;
const JPEG_APP13 = 0xed;
const JPEG_COM = 0xfe;
const JPEG_DROPPED_MARKERS = new Set([JPEG_APP1, JPEG_APP13, JPEG_COM]);
const EXIF_HEADER = Buffer.from('Exif\0\0', 'binary');
const TIFF_ORIENTATION_TAG = 0x0112;
const TIFF_TYPE_SHORT = 3;
const ORIENTATION_NORMAL = 1;
const ORIENTATION_MAX = 8;

const PNG_SIGNATURE = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
]);
const PNG_DROPPED_CHUNKS = new Set(['eXIf', 'tEXt', 'zTXt', 'iTXt']);

const WEBP_DROPPED_CHUNKS = new Set(['EXIF', 'XMP ']);
const WEBP_VP8X_EXIF_FLAG = 0x08;
const WEBP_VP8X_XMP_FLAG = 0x04;

/**
 * Rasm baytlaridan joylashuv/qurilma metadata'sini olib tashlaydi.
 * Formatni magic-baytlardan aniqlaydi (klient mime-type'iga ishonmaydi).
 */
export function stripImageMetadata(input: Buffer): Buffer {
  try {
    if (isJpeg(input)) return stripJpeg(input);
    if (isPng(input)) return stripPng(input);
    if (isWebp(input)) return stripWebp(input);
  } catch {
    // Buzilgan fayl — o'zgarishsiz qaytaramiz (yuklash yiqilmasin).
  }
  return input;
}

function isJpeg(b: Buffer): boolean {
  return b.length > 4 && b[0] === 0xff && b[1] === JPEG_SOI;
}

function isPng(b: Buffer): boolean {
  return b.length > 8 && b.subarray(0, 8).equals(PNG_SIGNATURE);
}

function isWebp(b: Buffer): boolean {
  return (
    b.length > 12 &&
    b.toString('ascii', 0, 4) === 'RIFF' &&
    b.toString('ascii', 8, 12) === 'WEBP'
  );
}

/* ------------------------------- JPEG ------------------------------- */

function stripJpeg(input: Buffer): Buffer {
  const kept: Buffer[] = [input.subarray(0, 2)];
  let orientation = ORIENTATION_NORMAL;
  let offset = 2;

  while (offset < input.length) {
    if (input[offset] !== 0xff) return input; // kutilmagan struktura
    const marker = input[offset + 1];
    if (marker === 0xff) {
      offset += 1; // to'ldiruvchi bayt
      continue;
    }
    if (marker === JPEG_SOS || marker === JPEG_EOI) {
      kept.push(input.subarray(offset));
      break;
    }
    if (isStandaloneJpegMarker(marker)) {
      kept.push(input.subarray(offset, offset + 2));
      offset += 2;
      continue;
    }
    const length = input.readUInt16BE(offset + 2);
    const end = offset + 2 + length;
    if (length < 2 || end > input.length) return input;
    const segment = input.subarray(offset, end);
    if (JPEG_DROPPED_MARKERS.has(marker)) {
      if (marker === JPEG_APP1) {
        orientation = readExifOrientation(segment.subarray(4)) ?? orientation;
      }
    } else {
      kept.push(segment);
    }
    offset = end;
  }

  if (orientation === ORIENTATION_NORMAL) return Buffer.concat(kept);
  // JFIF (APP0) bo'lsa — undan keyin, aks holda SOI'dan keyin darhol.
  const afterApp0 = kept.length > 1 && kept[1][1] === JPEG_APP0 ? 2 : 1;
  return Buffer.concat([
    ...kept.slice(0, afterApp0),
    buildOrientationApp1(orientation),
    ...kept.slice(afterApp0),
  ]);
}

function isStandaloneJpegMarker(marker: number): boolean {
  return marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7);
}

/** APP1 payload ("Exif\0\0" + TIFF) dan Orientation qiymatini o'qiydi. */
export function readExifOrientation(payload: Buffer): number | null {
  if (payload.length < 14 || !payload.subarray(0, 6).equals(EXIF_HEADER)) {
    return null;
  }
  const tiff = payload.subarray(6);
  const order = tiff.toString('ascii', 0, 2);
  if (order !== 'II' && order !== 'MM') return null;
  const le = order === 'II';
  const u16 = (o: number) => (le ? tiff.readUInt16LE(o) : tiff.readUInt16BE(o));
  const u32 = (o: number) => (le ? tiff.readUInt32LE(o) : tiff.readUInt32BE(o));

  const ifdOffset = u32(4);
  if (ifdOffset + 2 > tiff.length) return null;
  const count = u16(ifdOffset);
  for (let i = 0; i < count; i++) {
    const entry = ifdOffset + 2 + i * 12;
    if (entry + 12 > tiff.length) return null;
    if (u16(entry) !== TIFF_ORIENTATION_TAG) continue;
    if (u16(entry + 2) !== TIFF_TYPE_SHORT) return null;
    const value = u16(entry + 8);
    return value >= ORIENTATION_NORMAL && value <= ORIENTATION_MAX
      ? value
      : null;
  }
  return null;
}

/** Faqat Orientation tegidan iborat minimal APP1 (Exif) segmenti. */
function buildOrientationApp1(orientation: number): Buffer {
  const tiff = Buffer.alloc(26);
  tiff.write('MM', 0, 'ascii');
  tiff.writeUInt16BE(0x002a, 2);
  tiff.writeUInt32BE(8, 4); // IFD0 offset
  tiff.writeUInt16BE(1, 8); // 1 ta yozuv
  tiff.writeUInt16BE(TIFF_ORIENTATION_TAG, 10);
  tiff.writeUInt16BE(TIFF_TYPE_SHORT, 12);
  tiff.writeUInt32BE(1, 14); // count
  tiff.writeUInt16BE(orientation, 18);
  tiff.writeUInt32BE(0, 22); // keyingi IFD yo'q
  const header = Buffer.alloc(4);
  header[0] = 0xff;
  header[1] = JPEG_APP1;
  header.writeUInt16BE(2 + EXIF_HEADER.length + tiff.length, 2);
  return Buffer.concat([header, EXIF_HEADER, tiff]);
}

/* -------------------------------- PNG -------------------------------- */

function stripPng(input: Buffer): Buffer {
  const kept: Buffer[] = [input.subarray(0, 8)];
  let offset = 8;
  while (offset + 12 <= input.length) {
    const length = input.readUInt32BE(offset);
    const type = input.toString('ascii', offset + 4, offset + 8);
    const end = offset + 12 + length;
    if (end > input.length) return input;
    if (!PNG_DROPPED_CHUNKS.has(type)) kept.push(input.subarray(offset, end));
    offset = end;
    if (type === 'IEND') break;
  }
  return Buffer.concat(kept);
}

/* -------------------------------- WebP ------------------------------- */

function stripWebp(input: Buffer): Buffer {
  const kept: Buffer[] = [];
  let offset = 12;
  while (offset + 8 <= input.length) {
    const type = input.toString('ascii', offset, offset + 4);
    const size = input.readUInt32LE(offset + 4);
    const end = offset + 8 + size + (size % 2); // juft chegaraga to'ldirish
    if (end > input.length) return input;
    if (!WEBP_DROPPED_CHUNKS.has(type)) {
      const chunk = Buffer.from(input.subarray(offset, end));
      if (type === 'VP8X' && chunk.length > 8) {
        chunk[8] &= ~(WEBP_VP8X_EXIF_FLAG | WEBP_VP8X_XMP_FLAG) & 0xff;
      }
      kept.push(chunk);
    }
    offset = end;
  }
  const body = Buffer.concat(kept);
  const header = Buffer.alloc(12);
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(body.length + 4, 4);
  header.write('WEBP', 8, 'ascii');
  return Buffer.concat([header, body]);
}
