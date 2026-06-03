import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsIn, IsNotEmpty, IsString } from 'class-validator';

export const PERMISSION_KEYS = [
  'camera',
  'microphone',
  'location',
  'contacts',
  'sms',
  'calendar',
  'phone',
  'storage',
] as const;

/**
 * Bitta ilova uchun bitta ruxsat siyosatini saqlash (upsert).
 */
export class UpsertAppPermissionDto {
  @ApiProperty({ example: 'com.instagram.android' })
  @IsString()
  @IsNotEmpty()
  packageName!: string;

  @ApiProperty({ example: 'camera', enum: PERMISSION_KEYS })
  @IsString()
  @IsIn(PERMISSION_KEYS as unknown as string[])
  permission!: string;

  @ApiProperty({ example: true, description: 'true = ruxsat berilgan' })
  @IsBoolean()
  allowed!: boolean;
}
