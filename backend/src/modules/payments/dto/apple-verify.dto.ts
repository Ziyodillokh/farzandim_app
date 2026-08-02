import { ApiProperty } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** iOS StoreKit xaridini backend'da tekshirish uchun payload. */
export class AppleVerifyDto {
  @ApiProperty({ description: 'App Store product id (com.farzandim.parent.*)' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  productId: string;

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
