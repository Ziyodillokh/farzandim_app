import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** iOS StoreKit xaridini backend'da tekshirish uchun payload. */
export class AppleVerifyDto {
  // Ixtiyoriy: xarid/restore paytida ANIQ mahsulot ma'lum bo'ladi (client
  // beradi). Renewal-tekshiruv (ilova resume'da jim so'rov) paytida esa
  // qaysi mahsulot yangilanganini OLDINDAN bilib bo'lmaydi — shu holda bo'sh
  // qoldiriladi va backend kvitansiya ichidan ENG SO'NGGI mos yozuvni
  // avtomatik tanlaydi (apple-iap.service.ts: resolveLatestTransaction).
  @ApiProperty({
    required: false,
    description:
      'App Store product id (parvoz.*). Bo’sh bo’lsa backend kvitansiyadan avtomatik aniqlaydi.',
  })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  productId?: string;

  @ApiProperty({
    description: 'StoreKit serverVerificationData (base64 receipt yoki JWS)',
  })
  @IsString()
  @MinLength(1)
  verificationData: string;

  @ApiProperty({ required: false, description: 'StoreKit transaction id' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  transactionId?: string;
}
