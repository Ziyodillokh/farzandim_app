import { Module } from '@nestjs/common';
import { RetentionService } from './retention.service';

/**
 * Ma'lumot saqlash muddati (retention) moduli — @Cron orqali 90 kundan eski
 * xom joylashuv/faollik tarixini tozalaydi. (PrismaService @Global orqali keladi;
 * ScheduleModule.forRoot() app.module'da global.)
 */
@Module({
  providers: [RetentionService],
})
export class RetentionModule {}
