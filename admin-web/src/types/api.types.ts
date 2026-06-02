/**
 * Farzandim Backend API types
 * Swagger /api/docs-json'dan moslangan.
 */

// ─── Auth ───────────────────────────────────────────────────────
export interface AdminUser {
  id: string;
  email: string;
  name: string;
  phone: string | null;
  role: string;
  moderatorRoleKey: string;
  permissions: string[];
  isFullAccess: boolean;
  status: 'active' | 'blocked';
  lastActivityAt: string | null;
  twoFactorEnabled: boolean;
}

export interface LoginResponse {
  access_token?: string;
  accessToken?: string;
  refresh_token?: string;
  refreshToken?: string;
  user?: AdminUser;
  requires2fa?: boolean;
  challengeId?: string;
  maskedPhone?: string;
}

export interface TwoFactorVerifyResponse {
  access_token: string;
  accessToken: string;
  refresh_token?: string;
  refreshToken?: string;
  user: AdminUser;
  usedBackupCode: boolean;
  remainingBackupCodes: number;
}

export interface TwoFactorStatus {
  enabled: boolean;
  enabledAt: string | null;
  remainingBackupCodes: number;
}

// ─── Generic ────────────────────────────────────────────────────
export interface Paginated<T> {
  items: T[];
  page: number;
  totalPages: number;
  total: number;
}

// ─── Dashboard ──────────────────────────────────────────────────
export interface DashboardSummary {
  todayLogins: number;
  videosUploaded: number;
  audiobooks: number;
  activeContests: number;
  paidPlanBuyers: number;
}

export interface DashboardChart {
  headlineTotal: number;
  changePercent: number;
  labels: string[];
  series: Array<{ name: string; data: number[]; color?: string }>;
}

export interface DashboardData {
  summary: DashboardSummary;
  trends: DashboardSummary;
  charts: {
    usersGrowth: DashboardChart;
    activeUsers: DashboardChart;
  };
}

// ─── Users ──────────────────────────────────────────────────────
export type UserKind = 'parent' | 'child';
export type UserRole = 'PARENT' | 'CHILD';

export interface AdminUserListItem {
  id: string;
  kind: UserKind;
  name: string;
  email: string | null;
  phone: string | null;
  role: UserRole | string;
  status: 'active' | 'blocked';
  planLabel: string;
  lastActivityAt: string | null;
  avatarUrl: string | null;
}

// ─── Moderators ─────────────────────────────────────────────────
export interface Moderator {
  id: string;
  name: string;
  email: string;
  phone: string | null;
  moderatorRoleKey: string;
  permissions: string[];
  status: 'active' | 'blocked';
  lastActivityAt: string | null;
  twoFactorEnabled: boolean;
  createdAt: string;
}

// ─── Content ────────────────────────────────────────────────────
export type ContentStatus = 'pending' | 'approved' | 'rejected' | 'hidden';

export interface Video {
  id: string;
  title: string;
  description: string | null;
  url: string;
  thumbnail: string | null;
  durationSec: number | null;
  ageFrom: number;
  ageTo: number;
  category: string | null;
  categoryId: string | null;
  planRequired: string;
  level: string | null;
  status: ContentStatus;
  featured: boolean;
  views: number;
  likes: number;
  createdAt: string;
}

export interface Audiobook {
  id: string;
  title: string;
  author: string;
  description: string | null;
  audioUrl: string;
  thumbnail: string | null;
  durationSec: number | null;
  partsCount: number;
  ageFrom: number;
  ageTo: number;
  category: string | null;
  planRequired: string;
  status: ContentStatus;
  listens: number;
  createdAt: string;
}

export interface Book {
  id: string;
  title: string;
  author: string;
  description: string | null;
  pdfUrl: string | null;
  coverUrl: string | null;
  pages: number;
  ageFrom: number;
  ageTo: number;
  category: string;
  planRequired: string;
  status: ContentStatus;
  reads: number;
  createdAt: string;
}

export interface ContentCategory {
  id: string;
  kind: 'video' | 'audiobook' | 'book';
  slug: string;
  name: string;
  sortOrder: number;
}

// ─── Monetization ───────────────────────────────────────────────
export interface Plan {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  priceUzs: number;
  period: 'free' | 'monthly' | 'yearly';
  entitlementTier: 'free' | 'basic' | 'standard' | 'premium';
  badge: string | null;
  features: string[];
  isActive: boolean;
  sortOrder: number;
}

export interface Promocode {
  id: string;
  code: string;
  discountPct: number;
  usageLimit: number;
  usedCount: number;
  expiresAt: string | null;
  status: 'active' | 'inactive' | 'archived';
  planId: string | null;
}

export interface Payment {
  id: string;
  userId: string | null;
  planId: string | null;
  planName: string | null;
  amount: number;
  method: 'click' | 'payme' | 'uzum_bank' | 'visa' | 'mastercard';
  status: 'success' | 'pending' | 'failed' | 'refunded' | 'cancelled';
  externalId: string | null;
  createdAt: string;
  paidAt: string | null;
}

// ─── Olympiads ──────────────────────────────────────────────────
export interface Olympiad {
  id: string;
  title: string;
  description: string | null;
  subject: string;
  ageFrom: number;
  ageTo: number;
  type: 'test' | 'creative' | 'mixed';
  difficulty: string;
  startTime: string;
  endTime: string;
  durationMin: number;
  status: 'draft' | 'published' | 'archived';
  createdAt: string;
}

// ─── Notifications ──────────────────────────────────────────────
export interface AdminNotification {
  id: string;
  title: string;
  message: string;
  targetType: 'all' | 'parents' | 'children' | 'premium' | 'age_group';
  imageUrl: string | null;
  deepLink: string | null;
  status: 'sent' | 'scheduled' | 'queued' | 'sending' | 'failed';
  scheduledAt: string | null;
  sentAt: string | null;
  deliveredCount: number;
  openedCount: number;
  clickedCount: number;
  createdAt: string;
}

// ─── Audit Log ──────────────────────────────────────────────────
export interface AuditLogEntry {
  id: string;
  moderatorId: string | null;
  email: string | null;
  action: string;
  resourceType: string | null;
  resourceId: string | null;
  status: 'success' | 'failure';
  ipAddress: string | null;
  userAgent: string | null;
  details: Record<string, unknown> | null;
  createdAt: string;
}

// ─── Errors ─────────────────────────────────────────────────────
export interface ApiError {
  statusCode: number;
  message: string | string[];
  error?: string;
}
