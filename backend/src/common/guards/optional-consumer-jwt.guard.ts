import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Consumer JWT IXTIYORIY: token to'g'ri bo'lsa `request.user` o'rnatiladi,
 * yo'q yoki yaroqsiz bo'lsa so'rov to'xtatilmaydi (`request.user` bo'sh).
 * Ruxsat qarori handler/service'da qilinadi — masalan bola rasmi proksisi
 * token YOKI imzolangan havola bilan ochiladi (`@Public()` bilan birga).
 */
@Injectable()
export class OptionalConsumerJwtGuard extends AuthGuard('consumer-jwt') {
  handleRequest<T>(_err: Error | null, user: T): T {
    return (user || undefined) as T;
  }
}
