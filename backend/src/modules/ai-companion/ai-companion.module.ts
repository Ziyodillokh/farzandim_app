import { Module } from '@nestjs/common';
import { AiCompanionController } from './ai-companion.controller';
import { AiCompanionService } from './ai-companion.service';

/**
 * AiCompanionModule — Faro AI hamroh (#64/#65/#69/#70). PrismaService global,
 * ConfigService global (ANTHROPIC_API_KEY). API kalit FAQAT serverda.
 */
@Module({
  controllers: [AiCompanionController],
  providers: [AiCompanionService],
})
export class AiCompanionModule {}
