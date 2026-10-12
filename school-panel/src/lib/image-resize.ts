/**
 * Profil rasmi: markazdan kvadrat kesib, `size` px ga kichraytiradi va WebP
 * (brauzer qo'llamasa — JPEG) data URL qaytaradi. ~15–30 KB — localStorage uchun yetarli.
 */
export const PHOTO_SIZE = 256;
const QUALITY = 0.85;

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('image'));
    img.src = url;
  });
}

export async function resizePhoto(file: File, size = PHOTO_SIZE): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const image = await loadImage(url);
    const side = Math.min(image.width, image.height);
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw new Error('canvas');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(image, (image.width - side) / 2, (image.height - side) / 2, side, side, 0, 0, size, size);
    const webp = canvas.toDataURL('image/webp', QUALITY);
    return webp.startsWith('data:image/webp') ? webp : canvas.toDataURL('image/jpeg', QUALITY);
  } finally {
    URL.revokeObjectURL(url);
  }
}
