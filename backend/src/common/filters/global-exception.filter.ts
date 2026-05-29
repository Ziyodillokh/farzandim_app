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
    } else if (this.isPrismaNotFound(exception)) {
      // Prisma P2025 — record not found
      status = HttpStatus.NOT_FOUND;
      message = 'Resource not found';
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

  private isPrismaNotFound(exception: unknown): boolean {
    if (
      exception &&
      typeof exception === 'object' &&
      'code' in exception &&
      (exception as { code: string }).code === 'P2025'
    ) {
      return true;
    }
    return false;
  }
}
