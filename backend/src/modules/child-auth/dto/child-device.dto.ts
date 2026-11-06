import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export const CHILD_PLATFORMS = ['android', 'ios'] as const;
export type ChildPlatform = (typeof CHILD_PLATFORMS)[number];

/** Kirayotgan qurilma: `id` — ilovani o'rnatish identifikatori (client yaratadi, <= 64). */
export class ChildDeviceDto {
  @ApiProperty({ maxLength: 64, description: "Ilova o'rnatish identifikatori" })
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  @Matches(/^[^\u0000-\u001f\u007f]+$/, { message: 'device.id boshqaruv belgilarini o\'z ichiga olmasligi kerak' })
  id!: string;

  @ApiPropertyOptional({ maxLength: 60, example: 'Redmi Note 12S' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  model?: string;

  @ApiProperty({ enum: CHILD_PLATFORMS })
  @IsIn(CHILD_PLATFORMS)
  platform!: ChildPlatform;

  @ApiPropertyOptional({
    default: true,
    description:
      "Bu qurilma shu bolaning ota-ona nazoratini bajara oladimi (standart true). `false` — qurilma boshqa bolaning nazoratini " +
      "yuritadi: YANGI sessiya hech qachon ASOSIY bo'lmaydi (bu qurilmadagi joriy ASOSIY sessiyani almashtiruvchi qayta kirish bundan mustasno).",
  })
  @IsOptional()
  @IsBoolean()
  hostsControl?: boolean;
}
