import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { FcmModule } from '../../common/fcm/fcm.module';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { EnvConfig } from '../../common/config/env.schema';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { ConsumerJwtStrategy } from './strategies/consumer-jwt.strategy';
import { TelegramService } from './strategies/telegram.service';
import { SocialAuthService } from './strategies/social-auth.service';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'consumer-jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<EnvConfig, true>) => ({
        secret: config.get('JWT_ACCESS_SECRET', { infer: true }),
        signOptions: {
          audience: 'farzandim-consumer',
          issuer: 'farzandim-backend',
        },
      }),
    }),
    FcmModule,
    RealtimeModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, ConsumerJwtStrategy, TelegramService, SocialAuthService],
  exports: [AuthService, JwtModule, PassportModule],
})
export class AuthModule {}
