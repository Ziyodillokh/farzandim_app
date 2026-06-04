import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../../../common/interfaces/jwt-payload.interface';
import { EnvConfig } from '../../../common/config/env.schema';

@Injectable()
export class ConsumerJwtStrategy extends PassportStrategy(
  Strategy,
  'consumer-jwt',
) {
  constructor(config: ConfigService<EnvConfig, true>) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get('JWT_ACCESS_SECRET', { infer: true }),
      audience: 'farzandim-consumer',
      issuer: 'farzandim-backend',
    });
  }

  /**
   * Passport calls this after signature + expiry verification.
   * Return value is set as `request.user`.
   */
  validate(payload: JwtPayload): JwtPayload {
    return {
      userId: payload.userId,
      role: payload.role,
      tokenVersion: payload.tokenVersion,
      sid: payload.sid,
    };
  }
}
