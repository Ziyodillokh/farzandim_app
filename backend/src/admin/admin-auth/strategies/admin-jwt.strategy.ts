import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AdminJwtPayload } from '../../../common/interfaces/jwt-payload.interface';
import { EnvConfig } from '../../../common/config/env.schema';

@Injectable()
export class AdminJwtStrategy extends PassportStrategy(
  Strategy,
  'admin-jwt',
) {
  constructor(config: ConfigService<EnvConfig, true>) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get('ADMIN_JWT_ACCESS_SECRET', { infer: true }),
      audience: 'admin-panel',
      issuer: 'farzandim-backend',
    });
  }

  validate(payload: AdminJwtPayload): AdminJwtPayload {
    return {
      sub: payload.sub,
      email: payload.email,
      role: payload.role,
      tokenVersion: payload.tokenVersion,
    };
  }
}
