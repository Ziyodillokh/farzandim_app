import { Module } from '@nestjs/common';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { RoutinesController } from './routines.controller';
import { RoutinesService } from './routines.service';

@Module({
  imports: [RealtimeModule],
  controllers: [RoutinesController],
  providers: [RoutinesService],
  exports: [RoutinesService],
})
export class RoutinesModule {}
