export interface JwtPayload {
  userId: string;
  role: 'PARENT' | 'CHILD';
  tokenVersion?: number;
}

export interface AdminJwtPayload {
  sub: string;
  email: string;
  role: string;
  tokenVersion?: number;
}
