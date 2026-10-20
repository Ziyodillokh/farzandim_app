import { Module } from '@nestjs/common';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { FcmModule } from '../../common/fcm/fcm.module';
import { SchoolModeModule } from '../../school/school-mode/school-mode.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';

@Module({
  imports: [RealtimeModule, FcmModule, SchoolModeModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
  exports: [RoutinesService],
})
export class RoutinesModule {}
