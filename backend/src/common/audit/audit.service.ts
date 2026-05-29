import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Write an entry to the AuditLog table.
   * Silently catches errors so audit failures never break the main operation.
   */
  async log(
    userId: string | null,
    resourceType: string,
    action: string,
    resourceId: string,
    data?: unknown,
    request?: { ip?: string; headers?: Record<string, string | string[] | undefined> },
  ): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId,
          action: `${resourceType.toUpperCase()}_${action}`,
          resourceType,
          resourceId,
          data: data === undefined ? undefined : (data as object),
          ipAddress: request?.ip ?? null,
          userAgent:
            (request?.headers?.['user-agent'] as string | undefined) ?? null,
        },
      });
    } catch (err) {
      this.logger.warn(
        `Audit log write failed: ${resourceType} ${action} ${resourceId}`,
        err,
      );
    }
  }
}
