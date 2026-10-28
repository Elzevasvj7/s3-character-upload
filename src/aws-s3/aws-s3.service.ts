import { Injectable, InternalServerErrorException } from '@nestjs/common';
import {
  S3Client,
  HeadObjectCommand,
  ListObjectsV2Command,
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { STSClient, GetCallerIdentityCommand } from '@aws-sdk/client-sts';
import { ConfigService } from '../common/config/config.service.js';
import { fromIni } from '@aws-sdk/credential-providers';
import { Readable } from 'node:stream';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';
import { UnsupportedMediaTypeException } from '@nestjs/common';
import { BadRequestException } from '@nestjs/common';
import { createPresignedPost } from '@aws-sdk/s3-presigned-post';

@Injectable()
export class AwsS3Service {
  private readonly bucket: string;
  private readonly s3: S3Client;
  private readonly sts: STSClient;
  private readonly uploadS3: S3Client;

  constructor(private readonly config: ConfigService) {
    const { region, bucket, profile, uploadProfile } = this.config.aws;
    const credentials = profile ? fromIni({ profile }) : undefined;
    this.bucket = bucket;
    this.s3 = new S3Client({
      region,
      credentials,
    });
    this.sts = new STSClient({
      region,
      credentials,
    });
    // Cliente de subida: usa el rol S3UploadDemoRole.
    const uploadCredentials = uploadProfile
      ? fromIni({ profile: uploadProfile })
      : undefined;

    this.uploadS3 = new S3Client({
      region,
      credentials: uploadCredentials,
    });
  }

  async getIdentity() {
    const result = await this.sts.send(new GetCallerIdentityCommand({}));

    return {
      account: result.Account,
      arn: result.Arn,
      userId: result.UserId,
    };
  }
  async uploadFileDirectly(file: Express.Multer.File) {
    const extensionByMimeType: Record<string, string> = {
      'image/png': '.png',
      'image/jpeg': '.jpg',
    };
    const extension = extensionByMimeType[file.mimetype];
    if (!extension) {
      throw new UnsupportedMediaTypeException(
        'Solo se permiten imágenes PNG y JPEG.',
      );
    }
    const key = `presigned-upload-demo/${randomUUID()}${extension}`;
    await this.uploadS3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: file.buffer,
        ContentType: file.mimetype,
      }),
    );
    return {
      message: 'Archivo subido correctamente',
      bucket: this.bucket,
      key,
      contentType: file.mimetype,
      size: file.size,
    };
  }
  async createDemoPresignedPost(contentType: string) {
    const extensionByContentType: Record<string, string> = {
      'image/png': '.png',
      'image/jpeg': '.jpg',
    };

    const extension = extensionByContentType[contentType];

    if (!extension) {
      throw new BadRequestException(
        'Solo se permiten los tipos image/png e image/jpeg.',
      );
    }

    const key = `presigned-upload-demo/${randomUUID()}${extension}`;
    const maxSizeBytes = 5 * 1024 * 1024;
    const expiresInSeconds = 300;

    const { url, fields } = await createPresignedPost(this.uploadS3, {
      Bucket: this.bucket,
      Key: key,
      Expires: expiresInSeconds,

      Fields: {
        'Content-Type': contentType,
      },

      Conditions: [
        ['content-length-range', 1, maxSizeBytes],
        { 'Content-Type': contentType },
      ],
    });

    return {
      url,
      fields,
      key,
      contentType,
      maxSizeBytes,
      expiresInSeconds,
    };
  }
}
