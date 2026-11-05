// Parvoz School — yozma vazifa (rasm bilan topshirish): bola ilovasi, xodim baholashi va
// imzolangan rasm proksisi. `HomeworkStorageService` o'quv modulidan ham ishlatiladi.

import { Module } from '@nestjs/common';
import { SchoolCoreModule } from '../school-core.module';
import { HomeworkPhotoUrlService } from './homework-photo-url.service';
import { HomeworkPhotoService } from './homework-photo.service';
import { HomeworkStaffService } from './homework-staff.service';
import { HomeworkStorageService } from './homework-storage.service';
import { HomeworkSubmitService } from './homework-submit.service';
import { HomeworkChildController, HomeworkPhotoController, HomeworkStaffController } from './homework.controller';

@Module({
  imports: [SchoolCoreModule],
  controllers: [HomeworkStaffController, HomeworkChildController, HomeworkPhotoController],
  providers: [HomeworkStorageService, HomeworkPhotoUrlService, HomeworkPhotoService, HomeworkStaffService, HomeworkSubmitService],
  exports: [HomeworkStorageService],
})
export class HomeworkModule {}
