import { Module } from '@nestjs/common';
import { FcmModule } from '../../common/fcm/fcm.module';
import { TrialService } from './trial.service';

/**
 * Standart 1-haftalik demo (trial) moduli. `TrialService`ni AuthModule signup'da
 * (grantStandardTrial) ishlatadi; @Cron esa push eslatmalarni yuboradi.
 * (PrismaService @Global orqali keladi; FcmModule push uchun import qilinadi.)
 */
@Module({
  imports: [FcmModule],
  providers: [TrialService],
  exports: [TrialService],
})
export class TrialModule {}
