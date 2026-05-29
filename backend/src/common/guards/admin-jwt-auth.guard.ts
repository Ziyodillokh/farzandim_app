import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class AdminJwtAuthGuard extends AuthGuard('admin-jwt') {
  handleRequest<T>(err: Error | null, user: T): T {
    if (err || !user) {
      throw err || new UnauthorizedException('Invalid or expired admin token');
    }
    return user;
  }
}
