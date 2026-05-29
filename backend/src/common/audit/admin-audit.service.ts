import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';

export interface AdminAuditLogOptions {
  action: string;
  moderatorId?: string;
  email?: string;
  resourceType?: string;
  resourceId?: string;
  status?: string;
  details?: unknown;
}

@Injectable()
export class AdminAuditService {
  private readonly logger = new Logger(AdminAuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Write an entry to the ModeratorAuditLog table.
   * Silently catches errors so audit failures never break the main operation.
   */
  async log(
    request: { ip?: string; headers?: Record<string, string | string[] | undefined> },
    opts: AdminAuditLogOptions,
  ): Promise<void> {
    try {
      await this.prisma.moderatorAuditLog.create({
        data: {
          moderatorId: opts.moderatorId ?? null,
          email: opts.email ?? null,
          action: opts.action,
          resourceType: opts.resourceType ?? null,
          resourceId: opts.resourceId ?? null,
          status: opts.status ?? 'success',
          details: opts.details === undefined ? undefined : (opts.details as object),
          ipAddress: request?.ip ?? null,
          userAgent:
            (request?.headers?.['user-agent'] as string | undefined) ?? null,
        },
      });
    } catch (err) {
      this.logger.warn(
        `Admin audit log write failed: ${opts.action}`,
        err,
      );
    }
  }
}
