import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../common/database/database.module';
import { SchoolCryptoService } from '../../school/common/school-crypto.service';
import { KelajakInsightsService } from './kelajak-insights.service';
import { KelajakParentController } from './kelajak-parent.controller';
import { KelajakController } from './kelajak.controller';
import { KelajakService } from './kelajak.service';

// Ochiq javob matni SchoolCryptoService bilan shifrlanadi (faqat ConfigService kerak —
// maktab modulini import qilmaymiz).
@Module({
  imports: [DatabaseModule],
  controllers: [KelajakController, KelajakParentController],
  providers: [KelajakService, KelajakInsightsService, SchoolCryptoService],
  exports: [KelajakService, KelajakInsightsService],
})
export class KelajakModule {}
