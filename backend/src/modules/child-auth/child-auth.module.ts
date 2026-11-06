import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { AuthModule } from '../auth/auth.module';
import { ChildAuthClock } from './child-auth-clock';
import { ChildCredentialsController } from './child-credentials.controller';
import { ChildCredentialsService } from './child-credentials.service';
import { ChildLoginAttempts } from './child-login-attempts';
import { ChildLoginController } from './child-login.controller';
import { ChildLoginService } from './child-login.service';
import { ChildRecoveryController } from './child-recovery.controller';
import { ChildRecoveryService } from './child-recovery.service';
import { ChildSessionsService } from './child-sessions.service';
import { ChildSetupTokens } from './child-setup-token';

/**
 * Kirish (A01–A12), K1: bola login/parol, sessiyalar ("sessiya yopildi"), kirish maʼlumotlarini tiklash.
 * PrismaService va AuditService global. Maktab tomoni (`school/credentials`) servislarni shu moduldan oladi.
 */
@Module({
  imports: [AuthModule, FcmModule, RealtimeModule],
  controllers: [ChildLoginController, ChildRecoveryController, ChildCredentialsController],
  providers: [
    ChildAuthClock,
    ChildSetupTokens,
    ChildLoginAttempts,
    ChildSessionsService,
    ChildLoginService,
    ChildCredentialsService,
    ChildRecoveryService,
  ],
  exports: [ChildCredentialsService, ChildRecoveryService, ChildAuthClock],
})
export class ChildAuthModule {}
