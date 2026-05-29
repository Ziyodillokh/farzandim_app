import { Controller, Get } from '@nestjs/common';
import { PrismaService } from './common/database/prisma.service';
import { Public } from './common/decorators/public.decorator';

@Controller()
export class AppController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @Get()
  root() {
    return { message: 'Farzandim API ishlaydi!' };
  }

  @Public()
  @Get('health')
  async health() {
    let dbStatus = 'ok';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      dbStatus = 'error';
    }

    return {
      status: dbStatus === 'ok' ? 'ok' : 'degraded',
      service: 'Farzandim Backend',
      version: '2.0.0',
      timestamp: new Date().toISOString(),
      database: dbStatus,
    };
  }
}
