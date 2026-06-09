import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Google yoki Apple ID token bilan kirish/ro'yxatdan o'tish DTO'si.
 * Frontend Google/Apple SDK'lardan oladigan `idToken`'ni shu yerga yuboradi.
 */
export class SocialLoginDto {
  @ApiProperty({
    description: 'Google yoki Apple tomonidan berilgan ID token (JWT)',
  })
  @IsString()
  idToken!: string;

  @ApiPropertyOptional({
    description:
      'Apple uchun: birinchi loginda foydalanuvchi qaytargan to\'liq ism. ' +
      'Apple keyingi safar nomni qaytarmaydi, shuning uchun Flutter saqlab yuboradi.',
    example: 'Ahmad Aliyev',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional({ example: 'Redmi Note 12S' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceModel?: string;

  @ApiPropertyOptional({ example: 'android', enum: ['android', 'ios', 'web'] })
  @IsOptional()
  @IsString()
  @MaxLength(16)
  platform?: string;
}
