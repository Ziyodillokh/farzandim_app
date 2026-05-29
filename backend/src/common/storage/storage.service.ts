import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  CreateBucketCommand,
  HeadBucketCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { BUCKETS, BucketName } from './storage.constants';
import { EnvConfig } from '../config/env.schema';

/** Max signed URL TTL (S3/MinIO SigV4 limit is 7 days). */
const MAX_SIGNED_URL_TTL_SECONDS = 7 * 24 * 60 * 60 - 60;

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private readonly s3: S3Client;
  private readonly s3Public: S3Client;

  constructor(private readonly config: ConfigService<EnvConfig, true>) {
    const endpoint = this.config.get('MINIO_ENDPOINT', { infer: true });
    const accessKeyId = this.config.get('MINIO_ACCESS_KEY', { infer: true });
    const secretAccessKey = this.config.get('MINIO_SECRET_KEY', { infer: true });
    const publicUrl = this.config.get('MINIO_PUBLIC_URL', { infer: true });

    this.s3 = new S3Client({
      endpoint,
      region: 'us-east-1',
      credentials: { accessKeyId, secretAccessKey },
      forcePathStyle: true,
    });

    this.s3Public =
      publicUrl && publicUrl !== endpoint
        ? new S3Client({
            endpoint: publicUrl,
            region: 'us-east-1',
            credentials: { accessKeyId, secretAccessKey },
            forcePathStyle: true,
          })
        : this.s3;
  }

  async onModuleInit(): Promise<void> {
    await this.ensureBuckets();
  }

  /**
   * Upload a file to the specified bucket.
   */
  async upload(
    bucket: BucketName,
    key: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<void> {
    await this.s3.send(
      new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: buffer,
        ContentType: contentType,
      }),
    );
  }

  /**
   * Delete a file from the specified bucket.
   */
  async delete(bucket: BucketName, key: string): Promise<void> {
    await this.s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  }

  /**
   * Generate a signed download URL using the public S3 client.
   */
  async getSignedUrl(
    bucket: BucketName,
    key: string,
    expiresInSec = 3600,
  ): Promise<string> {
    const command = new GetObjectCommand({ Bucket: bucket, Key: key });
    const safeExpires = Math.min(expiresInSec, MAX_SIGNED_URL_TTL_SECONDS);
    return getSignedUrl(this.s3Public, command, { expiresIn: safeExpires });
  }

  /**
   * Ensure all required buckets exist. Idempotent.
   */
  async ensureBuckets(): Promise<void> {
    for (const bucket of Object.values(BUCKETS)) {
      try {
        await this.s3.send(new HeadBucketCommand({ Bucket: bucket }));
      } catch {
        try {
          await this.s3.send(new CreateBucketCommand({ Bucket: bucket }));
          this.logger.log(`Created bucket: ${bucket}`);
        } catch (err) {
          this.logger.error(`Failed to create bucket ${bucket}:`, err);
        }
      }
    }
  }
}
