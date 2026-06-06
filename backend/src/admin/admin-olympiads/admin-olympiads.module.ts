import { Module } from '@nestjs/common';
import { AdminOlympiadsController } from './admin-olympiads.controller';
import { OlympiadImageController } from './olympiad-image.controller';
import { AdminOlympiadsService } from './admin-olympiads.service';

@Module({
  controllers: [AdminOlympiadsController, OlympiadImageController],
  providers: [AdminOlympiadsService],
})
export class AdminOlympiadsModule {}
