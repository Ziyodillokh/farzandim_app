// Parvoz School — Students moduli (`/api/school/...`).

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';

@Module({
  imports: [SchoolCoreModule],
  controllers: [],
  providers: [],
})
export class StudentsModule {}
