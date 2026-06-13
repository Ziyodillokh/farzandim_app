import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, Max, Min } from 'class-validator';

// Bola ilovasi player video yuklanganda haqiqiy davomiylikni yuboradi.
// Backend uni faqat hozir noma'lum (0/null) bo'lsa yozadi — admin kiritgan
// qiymatni bosib ketmaydi. Asosan link orqali qo'shilgan YouTube videolari
// uchun (admin duration kiritmaydi).
export class ReportDurationDto {
  @ApiProperty({ example: 754, description: 'Real duration in seconds' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(86400)
  durationSec!: number;
}
