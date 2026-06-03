/**
 * API DTOs matching NestJS backend.
 * Keep in sync with backend Swagger schemas.
 */

export interface ApiError {
  statusCode: number;
  message: string | string[];
  error?: string;
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

// ───── Auth ─────
export interface User {
  id: string;
  name: string | null;
  phone: string | null;
  role: 'PARENT' | 'CHILD';
  avatarUrl: string | null;
  telegramId: string | null;
  language: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface TelegramAuthDto {
  id: number;
  first_name?: string;
  last_name?: string;
  username?: string;
  photo_url?: string;
  auth_date: number;
  hash: string;
}

export interface ChildPairDto {
  familyCode: string;
  deviceInfo?: {
    model?: string;
    os?: string;
    batteryLevel?: number;
    isCharging?: boolean;
  };
}

// ───── Child ─────
export interface Child {
  id: string;
  parentId: string;
  childUserId: string | null;
  name: string;
  age: number | null;
  gender: 'male' | 'female' | null;
  region: string | null;
  photoPath: string | null;
  familyCode: string;
  pairedAt: string | null;
  isConnected: boolean;
  lastSeenAt: string | null;
  batteryLevel: number | null;
  isCharging: boolean | null;
  deviceModel: string | null;
  createdAt: string;
}

// ───── Location ─────
export interface Location {
  id: string;
  childId: string;
  latitude: number;
  longitude: number;
  accuracy: number | null;
  speed: number | null;
  batteryLevel: number | null;
  isCharging: boolean | null;
  createdAt: string;
}

// ───── Messages ─────
export interface VoiceMessage {
  id: string;
  senderId: string;
  receiverId: string;
  storagePath: string;
  durationSeconds: number | null;
  isRead: boolean;
  createdAt: string;
  sender?: { id: string; name: string | null; avatarUrl: string | null };
  receiver?: { id: string; name: string | null; avatarUrl: string | null };
}

// ───── Notifications ─────
export type NotificationType =
  | 'ACHIEVEMENT'
  | 'CONTEST'
  | 'SCHEDULE'
  | 'PARENT_REQUEST'
  | 'VOICE'
  | 'GEO_ZONE'
  | 'SYSTEM';

export interface Notification {
  id: string;
  childId: string;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  isRead: boolean;
  createdAt: string;
}

// ───── Schedules ─────
export interface Schedule {
  id: string;
  childId: string;
  name: string;
  startTime: string;
  endTime: string;
  daysOfWeek: number[];
  action: 'BLOCK' | 'ALLOW';
  isActive: boolean;
}

// ───── Geo Zones ─────
export interface GeoZone {
  id: string;
  childId: string;
  name: string;
  centerLat: number;
  centerLng: number;
  radiusMeters: number;
  alertOnEnter: boolean;
  alertOnExit: boolean;
  isActive: boolean;
}

// ───── Gamification ─────
export interface ChildProfile {
  id: string;
  childId: string;
  xp: number;
  donBalance: number;
  level: number;
  status: string;
  streakDays: number;
  lastActivityDate: string | null;
  achievements: unknown[];
}

// ───── Plans / Subscription ─────
export interface Plan {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  priceUzs: number;
  period: 'free' | 'monthly' | 'yearly';
  entitlementTier: 'free' | 'standard' | 'premium';
  badge: string | null;
  features: string[];
}

export interface Subscription {
  id: string;
  status: 'PENDING' | 'ACTIVE' | 'EXPIRED' | 'CANCELLED';
  planName: string | null;
  entitlementTier: string;
  startedAt: string | null;
  expiresAt: string | null;
}
