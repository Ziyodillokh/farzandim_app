// Parvoz School — sinf dars jadvali (`/api/school/timetable`) va bola ilovasi
// (`/api/child/school/timetable`).

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';
import { TimetableChildService } from './timetable-child.service';
import { TimetableChildController, TimetableController } from './timetable.controller';
import { TimetableService } from './timetable.service';

@Module({
  imports: [SchoolCoreModule],
  controllers: [TimetableController, TimetableChildController],
  providers: [TimetableService, TimetableChildService],
})
export class TimetableModule {}
