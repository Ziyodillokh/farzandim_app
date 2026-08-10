import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { validate } from './common/config/env.schema';

// Infrastructure / shared modules
import { DatabaseModule } from './common/database/database.module';
import { StorageModule } from './common/storage/storage.module';
import { FcmModule } from './common/fcm/fcm.module';
import { SmsModule } from './common/sms/sms.module';
import { AuditModule } from './common/audit/audit.module';
import { RealtimeModule } from './common/realtime/realtime.module';
import { ConnectionMonitorModule } from './common/connection/connection-monitor.module';

// Consumer feature modules
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ChildrenModule } from './modules/children/children.module';
import { FcmTokensModule } from './modules/fcm-tokens/fcm-tokens.module';
import { LocationModule } from './modules/location/location.module';
import { VoiceMessagesModule } from './modules/voice-messages/voice-messages.module';
import { VideoMessagesModule } from './modules/video-messages/video-messages.module';
import { SchedulesModule } from './modules/schedules/schedules.module';
import { RoutinesModule } from './modules/routines/routines.module';
import { GeoZonesModule } from './modules/geo-zones/geo-zones.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { FeedbackModule } from './modules/feedback/feedback.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { PhotoRequestsModule } from './modules/photo-requests/photo-requests.module';
import { SosAlertsModule } from './modules/sos-alerts/sos-alerts.module';
import { InstalledAppsModule } from './modules/installed-apps/installed-apps.module';
import { AppLimitsModule } from './modules/app-limits/app-limits.module';
import { UnlockRequestsModule } from './modules/unlock-requests/unlock-requests.module';
import { NudgesModule } from './modules/nudges/nudges.module';
import { AppPermissionsModule } from './modules/app-permissions/app-permissions.module';
import { AppUsageModule } from './modules/app-usage/app-usage.module';
import { ChildPairRequestsModule } from './modules/child-pair-requests/child-pair-requests.module';
import { AppVersionModule } from './modules/app-version/app-version.module';
import { SupportModule } from './modules/support/support.module';
import { LeaderboardModule } from './modules/leaderboard/leaderboard.module';
import { ConsumerContentModule } from './modules/consumer-content/consumer-content.module';
import { ConsumerOlympiadsModule } from './modules/consumer-olympiads/consumer-olympiads.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { RetentionModule } from './modules/retention/retention.module';

// Admin feature modules
import { AdminAuthModule } from './admin/admin-auth/admin-auth.module';
import { AdminModeratorsModule } from './admin/admin-moderators/admin-moderators.module';
import { AdminUsersModule } from './admin/admin-users/admin-users.module';
import { AdminDashboardModule } from './admin/admin-dashboard/admin-dashboard.module';
import { AdminMonetizationModule } from './admin/admin-monetization/admin-monetization.module';
import { AdminNotificationsModule } from './admin/admin-notifications/admin-notifications.module';
import { AdminOlympiadsModule } from './admin/admin-olympiads/admin-olympiads.module';
import { AdminAnalyticsModule } from './admin/admin-analytics/admin-analytics.module';
import { AdminContentModule } from './admin/admin-content/admin-content.module';
import { AdminAuditLogModule } from './admin/admin-audit-log/admin-audit-log.module';
import { AdminSecurityModule } from './admin/admin-security/admin-security.module';
import { SecuritySettingsModule } from './common/security/security-settings.module';
import { EntitlementModule } from './common/entitlement/entitlement.module';

// App controller
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate }),
    ScheduleModule.forRoot(),

    // Rate-limit — BARCHA nomli limitlar SHU YERDA, bir marta.
    // ⚠️ ThrottlerModule @Global: agar u bir necha modulda `forRoot()` bilan
    // ro'yxatdan o'tsa, oxirgisi avvalgilarini JIMGINA bekor qiladi (nomli
    // limitlar yo'qoladi va noto'g'ri limit boshqa route'ga qo'llanadi).
    // Aynan shu 2026-08-10 da `checkout` (5/10daq) limitini `child-pair`
    // route'iga tarqatib, Play reviewer'ini bloklab qo'ygan edi.
    //   childPair — 5 xonali oila kodini enumeration qilishga qarshi
    //   checkout  — Uzum IB anti-fraud talabi (karta brute-force)
    ThrottlerModule.forRoot([
      { name: 'childPair', ttl: 600_000, limit: 30 },
      { name: 'checkout', ttl: 600_000, limit: 5 },
    ]),

    // Infrastructure
    DatabaseModule,
    StorageModule,
    SecuritySettingsModule,
    FcmModule,
    SmsModule,
    AuditModule,
    RealtimeModule,
    ConnectionMonitorModule,

    // Consumer modules
    AuthModule,
    UsersModule,
    ChildrenModule,
    FcmTokensModule,
    LocationModule,
    VoiceMessagesModule,
    VideoMessagesModule,
    SchedulesModule,
    RoutinesModule,
    GeoZonesModule,
    NotificationsModule,
    FeedbackModule,
    GamificationModule,
    PhotoRequestsModule,
    SosAlertsModule,
    InstalledAppsModule,
    AppLimitsModule,
    UnlockRequestsModule,
    NudgesModule,
    AppPermissionsModule,
    AppUsageModule,
    ChildPairRequestsModule,
    AppVersionModule,
    SupportModule,
    LeaderboardModule,
    ConsumerContentModule,
    ConsumerOlympiadsModule,
    PaymentsModule,
    RetentionModule,

    // Admin modules
    AdminAuthModule,
    EntitlementModule,
    AdminModeratorsModule,
    AdminUsersModule,
    AdminDashboardModule,
    AdminMonetizationModule,
    AdminNotificationsModule,
    AdminOlympiadsModule,
    AdminAnalyticsModule,
    AdminContentModule,
    AdminAuditLogModule,
    AdminSecurityModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
