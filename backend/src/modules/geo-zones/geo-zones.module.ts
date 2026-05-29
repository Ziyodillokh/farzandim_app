import { Module } from '@nestjs/common';
import { RealtimeModule } from '../../common/realtime/realtime.module';
import { GeoZonesController } from './geo-zones.controller';
import { GeoZonesService } from './geo-zones.service';

@Module({
  imports: [RealtimeModule],
  controllers: [GeoZonesController],
  providers: [GeoZonesService],
  exports: [GeoZonesService],
})
export class GeoZonesModule {}
