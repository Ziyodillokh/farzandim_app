import { Module } from '@nestjs/common';
import { AdminKelajakController } from './admin-kelajak.controller';
import { AdminKelajakService } from './admin-kelajak.service';

@Module({
  controllers: [AdminKelajakController],
  providers: [AdminKelajakService],
})
export class AdminKelajakModule {}
