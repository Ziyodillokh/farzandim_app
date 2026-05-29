import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { ChildrenController } from './children.controller';
import { ChildrenService } from './children.service';

@Module({
  imports: [StorageModule],
  controllers: [ChildrenController],
  providers: [ChildrenService],
  exports: [ChildrenService],
})
export class ChildrenModule {}
