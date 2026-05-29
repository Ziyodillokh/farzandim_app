import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsUUID } from 'class-validator';

export class ReadAllVoiceMessagesDto {
  @ApiPropertyOptional({ description: 'Only mark messages from this sender as read' })
  @IsOptional()
  @IsUUID()
  fromUserId?: string;
}
