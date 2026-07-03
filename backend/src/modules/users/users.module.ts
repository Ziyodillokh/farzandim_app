import { Module } from '@nestjs/common';
import { StorageModule } from '../../common/storage/storage.module';
import { SmsModule } from '../../common/sms/sms.module';
import { MailModule } from '../../common/mail/mail.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [StorageModule, SmsModule, MailModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
