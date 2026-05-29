import { Module } from '@nestjs/common';
import { AdminModeratorsController } from './admin-moderators.controller';
import { AdminModeratorsService } from './admin-moderators.service';

@Module({
  controllers: [AdminModeratorsController],
  providers: [AdminModeratorsService],
})
export class AdminModeratorsModule {}
