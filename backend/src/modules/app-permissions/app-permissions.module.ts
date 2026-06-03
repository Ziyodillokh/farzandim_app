import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { AppPermissionsController } from './app-permissions.controller';
import { AppPermissionsService } from './app-permissions.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AppPermissionsController],
  providers: [AppPermissionsService],
})
export class AppPermissionsModule {}
