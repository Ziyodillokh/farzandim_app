import { Module } from '@nestjs/common';
import { SchoolAuditService } from '../../school/common/school-audit.service';
import { AdminSchoolsController } from './admin-schools.controller';
import { AdminSchoolsService } from './admin-schools.service';

@Module({
  controllers: [AdminSchoolsController],
  providers: [AdminSchoolsService, SchoolAuditService],
})
export class AdminSchoolsModule {}
