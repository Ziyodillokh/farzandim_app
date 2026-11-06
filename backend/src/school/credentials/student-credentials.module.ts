// Maktab: o'quvchi kirish maʼlumotlari (`/api/school/students/:studentId/credentials`, tiklash so'rovlari).

import { Module } from '@nestjs/common';
import { ChildAuthModule } from '../../modules/child-auth/child-auth.module';
import { SchoolCoreModule } from '../school-core.module';
import { StudentCredentialsController } from './student-credentials.controller';
import { StudentCredentialsService } from './student-credentials.service';

@Module({
  imports: [SchoolCoreModule, ChildAuthModule],
  controllers: [StudentCredentialsController],
  providers: [StudentCredentialsService],
})
export class StudentCredentialsModule {}
