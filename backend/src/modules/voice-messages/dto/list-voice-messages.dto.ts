import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsIn } from 'class-validator';

export class ListVoiceMessagesDto {
  @ApiPropertyOptional({ enum: ['sent', 'received'], description: 'Filter by role' })
  @IsOptional()
  @IsIn(['sent', 'received'])
  role?: 'sent' | 'received';
}
