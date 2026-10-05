/**
 * Bildirishnoma (push) rasmini yuborishdan oldin tayyorlaydi.
 *
 * Android FCM bildirishnoma rasmini faqat ~1 MB gacha ko'rsatadi — kattaroq
 * bo'lsa push RASMSIZ keladi. Admin esa 5 MB gacha telefon suratini
 * yuklashi mumkin. Shuning uchun rasm brauzerda kichraytirilib JPEG'ga
 * o'tkaziladi (kichik JPG/PNG/WebP o'zgarishsiz qoladi).
 */
export const PUSH_IMAGE_MAX_BYTES = 900 * 1024;

/** Ketma-ket urinishlar: [eng uzun tomon (px), JPEG sifati]. */
const ATTEMPTS: ReadonlyArray<readonly [number, number]> = [
  [1440, 0.85],
  [1440, 0.75],
  [1080, 0.75],
  [800, 0.7],
];

const KEEP_AS_IS = new Set(['image/jpeg', 'image/png', 'image/webp']);

export class PushImageError extends Error {}

function loadImage(file: File): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new PushImageError("Rasmni o'qib bo'lmadi — boshqa fayl tanlang"));
    };
    img.src = url;
  });
}

function encodeJpeg(img: HTMLImageElement, maxSide: number, quality: number): Promise<Blob> {
  const scale = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(img.naturalWidth * scale));
  canvas.height = Math.max(1, Math.round(img.naturalHeight * scale));
  const ctx = canvas.getContext('2d');
  if (!ctx) return Promise.reject(new PushImageError('Brauzer rasmni qayta ishlay olmadi'));
  // Shaffof PNG qora bo'lib qolmasin — JPEG'da oq fon.
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new PushImageError("Rasmni siqib bo'lmadi"))),
      'image/jpeg',
      quality,
    );
  });
}

function jpegName(name: string): string {
  const base = name.replace(/\.[^.]+$/, '') || 'rasm';
  return `${base}.jpg`;
}

/**
 * Push uchun mos faylni qaytaradi: hajmi {@link PUSH_IMAGE_MAX_BYTES} dan
 * oshmaydi. Iloji bo'lmasa {@link PushImageError} tashlaydi.
 */
export async function preparePushImage(file: File): Promise<File> {
  if (file.size <= PUSH_IMAGE_MAX_BYTES && KEEP_AS_IS.has(file.type)) return file;

  const img = await loadImage(file);
  for (const [side, quality] of ATTEMPTS) {
    const blob = await encodeJpeg(img, side, quality);
    if (blob.size <= PUSH_IMAGE_MAX_BYTES) {
      return new File([blob], jpegName(file.name), { type: 'image/jpeg' });
    }
  }
  throw new PushImageError("Rasm juda katta — kichikroq rasm tanlang");
}
