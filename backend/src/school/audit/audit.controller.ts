import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Actor, SchoolAuth } from '../auth/decorators';
import { SchoolActor } from '../auth/school-actor';
import { AuditService } from './audit.service';

@ApiTags('School - Audit')
@SchoolAuth()
@Controller('school/audit')
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  @Get()
  list(@Actor() actor: SchoolActor, @Query() query: Record<string, unknown>) {
    return this.audit.list(actor, query);
  }

  @Get('actors')
  actors(@Actor() actor: SchoolActor) {
    return this.audit.actors(actor);
  }
}
