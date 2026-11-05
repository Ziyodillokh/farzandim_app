// Yozma vazifa rasmlari: format FAQAT baytlardan (magic bytes) aniqlanadi — klientning
// Content-Type / fayl nomiga ishonilmaydi. Ruxsat: JPEG, PNG, WebP. HEIC qabul qilinmaydi —
// undagi EXIF/GPS'ni tozalay olmaymiz (ilova rasmni JPEG qilib yuboradi).

export const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
export const MAX_PHOTOS = 5;

export interface SniffedImage {
  contentType: 'image/jpeg' | 'image/png' | 'image/webp';
  ext: 'jpg' | 'png' | 'webp';
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

export function sniffImage(buf: Buffer): SniffedImage | null {
  if (buf.length >= 4 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return { contentType: 'image/jpeg', ext: 'jpg' };
  }
  if (buf.length > 8 && buf.subarray(0, 8).equals(PNG_SIGNATURE)) {
    return { contentType: 'image/png', ext: 'png' };
  }
  if (buf.length > 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return { contentType: 'image/webp', ext: 'webp' };
  }
  return null;
}

/** Saqlash kaliti: `homework/<maktab>/<topshiriq>/<o'quvchi>/<uuid>.<ext>`. */
export const homeworkPhotoKey = (p: { schoolId: string; assignmentId: string; studentId: string; uuid: string; ext: string }) =>
  `homework/${p.schoolId}/${p.assignmentId}/${p.studentId}/${p.uuid}.${p.ext}`;
