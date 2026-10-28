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

  async getDemoObjectMetadata() {
    const result = await this.s3.send(
      new HeadObjectCommand({
        Bucket: this.bucket,
        Key: 'cloudfront-demo/demo.txt',
      }),
    );

    return {
      key: 'cloudfront-demo/demo.txt',
      contentType: result.ContentType ?? null,
      contentLength: result.ContentLength ?? null,
      lastModified: result.LastModified?.toISOString() ?? null,
      versionId: result.VersionId ?? null,
    };
  }

  async listDemoObjects() {
    const result = await this.s3.send(
      new ListObjectsV2Command({
        Bucket: this.bucket,
        Prefix: 'cloudfront-demo/',
      }),
    );

    return {
      bucket: this.bucket,
      prefix: 'cloudfront-demo/',
      keys: (result.Contents ?? []).flatMap((object) =>
        object.Key ? [object.Key] : [],
      ),
    };
  }
  async testRestrictedPrefix() {
    try {
      const result = await this.s3.send(
        new ListObjectsV2Command({
          Bucket: this.bucket,
          Prefix: 'lifecycle-lab/',
        }),
      );

      // Si llegamos aquí, el listado fue permitido.
      return {
        expected: false,
        access: 'ALLOWED',
        keys: result.Contents?.map((object) => object.Key) ?? [],
      };
    } catch (error: unknown) {
      const awsError = error as {
        name?: string;
        $metadata?: {
          httpStatusCode?: number;
        };
      };

      if (
        awsError.name === 'AccessDenied' ||
        awsError.$metadata?.httpStatusCode === 403
      ) {
        return {
          expected: true,
          access: 'DENIED',
          message: 'El rol no puede listar este prefijo.',
        };
      }

      throw error;
    }
  }
  async getDemoObjectContent() {
    const key = 'cloudfront-demo/test-cloudfront.txt';

    const result = await this.s3.send(
      new GetObjectCommand({
        Bucket: this.bucket,
        Key: key,
      }),
    );

    if (!result.Body) {
      throw new Error('S3 no devolvió el contenido del objeto');
    }

    const content = await result.Body.transformToString();

    return {
      bucket: this.bucket,
      key,
      contentType: result.ContentType ?? null,
      contentLength: result.ContentLength ?? null,
      content,
    };
  }
  async getDemoObjectStream() {
    const key = 'cloudfront-demo/test-cloudfront.txt';

    const result = await this.s3.send(
      new GetObjectCommand({
        Bucket: this.bucket,
        Key: key,
      }),
    );

    if (!result.Body) {
      throw new InternalServerErrorException(
        'S3 no devolvió el contenido del objeto',
      );
    }

    if (!(result.Body instanceof Readable)) {
      throw new InternalServerErrorException(
        'El cuerpo recibido de S3 no es un stream de Node.js',
      );
    }

    return {
      body: result.Body,
      contentType: result.ContentType ?? 'application/octet-stream',
      contentLength: result.ContentLength,
    };
  }
  async getDemoDownloadUrl() {
    const key = 'cloudfront-demo/test-cloudfront.txt';
    const expiresInSeconds = 300;

    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ResponseContentDisposition: 'attachment; filename="test-cloudfront.txt"',
    });

    const url = await getSignedUrl(this.s3, command, {
      expiresIn: expiresInSeconds,
    });

    return {
      key,
      url,
      expiresInSeconds,
      expiresAt: new Date(Date.now() + expiresInSeconds * 1000).toISOString(),
    };
  }
  async createDemoUploadUrl() {
    const key = `presigned-upload-demo/${randomUUID()}.txt`;
    const contentType = 'text/plain';
    const expiresInSeconds = 300;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(this.uploadS3, command, {
      expiresIn: expiresInSeconds,
      signableHeaders: new Set(['content-type']),
    });

    return {
      key,
      method: 'PUT',
      uploadUrl,
      contentType,
      expiresInSeconds,
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
