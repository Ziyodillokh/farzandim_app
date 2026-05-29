import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsString, IsUUID, IsOptional, IsNumber, Min } from 'class-validator';

export class SendVideoMessageDto {
  @ApiProperty({ description: 'UUID of the receiver (parent or paired child)' })
  @IsNotEmpty()
  @IsString()
  @IsUUID()
  receiverId: string;

  @ApiPropertyOptional({ description: 'Duration of the video message in seconds' })
  @IsOptional()
  @IsNumber()
  @Min(0)
  durationSeconds?: number;
}
