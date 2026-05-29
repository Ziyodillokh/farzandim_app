import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService } from '@nestjs/config';
import { EnvConfig } from '../../common/config/env.schema';
import { AdminAuthController } from './admin-auth.controller';
import { AdminAuthService } from './admin-auth.service';
import { AdminJwtStrategy } from './strategies/admin-jwt.strategy';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'admin-jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<EnvConfig, true>) => ({
        secret: config.get('ADMIN_JWT_ACCESS_SECRET', { infer: true }),
        signOptions: {
          audience: 'admin-panel',
          issuer: 'farzandim-backend',
        },
      }),
    }),
  ],
  controllers: [AdminAuthController],
  providers: [AdminAuthService, AdminJwtStrategy],
  exports: [AdminAuthService, JwtModule, PassportModule],
})
export class AdminAuthModule {}
