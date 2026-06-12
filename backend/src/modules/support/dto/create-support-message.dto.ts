import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Support chat xabari — matn YOKI biriktirma (oldin /support/attachments
 * orqali yuklangan key) bo'lishi shart (service tekshiradi).
 */
export class CreateSupportMessageDto {
  @ApiPropertyOptional({ example: 'Salom, yordam kerak' })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  text?: string;

  @ApiPropertyOptional({ description: 'Upload javobidagi MinIO key' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  attachmentKey?: string;

  @ApiPropertyOptional({ enum: ['image', 'video', 'document'] })
  @IsOptional()
  @IsIn(['image', 'video', 'document'])
  attachmentType?: string;

  @ApiPropertyOptional({ example: 'rasm.jpg' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  fileName?: string;

  @ApiPropertyOptional({ example: 102400 })
  @IsOptional()
  @IsInt()
  @Min(0)
  fileSize?: number;

  @ApiPropertyOptional({ example: 'image/jpeg' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  mimeType?: string;
}
