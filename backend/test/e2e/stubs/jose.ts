// `jose` v6 faqat ESM — Jest (CommonJS) uni yuklay olmaydi. E2E testlarda
// ijtimoiy kirish (Apple ID token) tekshirilmaydi, shuning uchun stub.

export type JWTPayload = Record<string, unknown>;

export function createRemoteJWKSet(): () => never {
  return () => {
    throw new Error('jose stub: e2e muhitida ishlatilmaydi');
  };
}

export async function jwtVerify(): Promise<never> {
  throw new Error('jose stub: e2e muhitida ishlatilmaydi');
}
