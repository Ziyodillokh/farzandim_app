/**
 * Mahsulot nomi va "Parvoz" belgisi ostidagi kichik yozuv.
 *
 * VAQTINCHA (2026-11-11, egasi so'radi): "Parvoz" ostidagi "SCHOOL" yozuvi va
 * "Parvoz School" nomi ko'rsatilmaydi — hamma joyda faqat "Parvoz". Qaytarish
 * uchun `PRODUCT_SUB = 'School'` qilinadi (belgi, sahifa sarlavhasi va matnlar
 * birdaniga qaytadi).
 */
export const PRODUCT_SUB: string | undefined = undefined;

export const PRODUCT_NAME = PRODUCT_SUB ? `Parvoz ${PRODUCT_SUB}` : 'Parvoz';
