export interface JwtPayload {
  userId: string;
  role: 'PARENT' | 'CHILD';
  tokenVersion?: number;
  /** UserSession id — "Faol sessiyalar" uchun (eski tokenlarda yo'q). */
  sid?: string;
}

export interface AdminJwtPayload {
  sub: string;
  email: string;
  role: string;
  tokenVersion?: number;
}
