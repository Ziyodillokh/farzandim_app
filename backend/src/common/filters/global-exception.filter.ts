import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { FastifyReply } from 'fastify';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<FastifyReply>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | object = 'Internal server error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exResponse = exception.getResponse();
      message =
        typeof exResponse === 'string'
          ? exResponse
          : (exResponse as object);
    } else if (prismaCode(exception) === 'P2025') {
      // Prisma P2025 — record not found
      status = HttpStatus.NOT_FOUND;
      message = 'Resource not found';
    } else if (prismaCode(exception) === 'P2002') {
      // Unique cheklov buzildi (parallel so'rov / takroriy yozuv) — 500 emas.
      status = HttpStatus.CONFLICT;
      message = 'Resource already exists';
      this.logger.warn(`P2002 unique conflict: ${prismaTarget(exception)}`);
    } else if (prismaCode(exception) === 'P2003') {
      // Bog'langan yozuv (foreign key) mavjud emas.
      status = HttpStatus.BAD_REQUEST;
      message = 'Related resource not found';
      this.logger.warn(`P2003 foreign key: ${prismaTarget(exception)}`);
    } else {
      // Unexpected error — log full details
      this.logger.error(
        'Unhandled exception',
        exception instanceof Error ? exception.stack : exception,
      );
    }

    const body =
      typeof message === 'string'
        ? { statusCode: status, message }
        : { statusCode: status, ...(message as Record<string, unknown>) };

    response.status(status).send(body);
  }
}

/** Prisma xatosi kodi (`P2002` …) yoki `undefined`. */
function prismaCode(exception: unknown): string | undefined {
  if (exception && typeof exception === 'object' && 'code' in exception) {
    const code = (exception as { code: unknown }).code;
    return typeof code === 'string' && code.startsWith('P') ? code : undefined;
  }
  return undefined;
}

/** Prisma xatosidagi model / maydon (meta) — logda shaxsiy ma'lumotsiz. */
function prismaTarget(exception: unknown): string {
  const meta = (exception as { meta?: { modelName?: unknown; target?: unknown; field_name?: unknown } }).meta;
  const parts = [meta?.modelName, meta?.target, meta?.field_name].filter((v) => v !== undefined && v !== null);
  return parts.map((v) => (Array.isArray(v) ? v.join(',') : String(v))).join(' ') || 'unknown';
}
