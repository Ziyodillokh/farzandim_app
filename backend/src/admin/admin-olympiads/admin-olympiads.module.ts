import { Module } from '@nestjs/common';
import { AdminOlympiadsController } from './admin-olympiads.controller';
import { AdminOlympiadsService } from './admin-olympiads.service';

@Module({
  controllers: [AdminOlympiadsController],
  providers: [AdminOlympiadsService],
})
export class AdminOlympiadsModule {}
