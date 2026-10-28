import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpStatus,
  ParseFilePipeBuilder,
  Post,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { AwsS3Service } from './aws-s3.service.js';
import { FileInterceptor } from '@nestjs/platform-express';

@Controller('aws-s3')
export class AwsS3Controller {
  constructor(private readonly awsS3Service: AwsS3Service) {}

  @Get('identity')
  getIdentity() {
    return this.awsS3Service.getIdentity();
  }

  @Get('demo-object')
  getDemoObjectMetadata() {
    return this.awsS3Service.getDemoObjectMetadata();
  }

  @Get('demo-objects')
  listDemoObjects() {
    return this.awsS3Service.listDemoObjects();
  }
  @Get('restricted-objects')
  testRestrictedPrefix() {
    return this.awsS3Service.testRestrictedPrefix();
  }
  @Get('demo-object-content')
  getDemoObjectContent() {
    return this.awsS3Service.getDemoObjectContent();
  }
  @Get('demo-download')
  async downloadDemoObject(): Promise<StreamableFile> {
    const file = await this.awsS3Service.getDemoObjectStream();

    return new StreamableFile(file.body, {
      type: file.contentType,
      disposition: 'attachment; filename="test-cloudfront.txt"',
      ...(file.contentLength !== undefined
        ? { length: file.contentLength }
        : {}),
    });
  }
  @Get('demo-download-url')
  getDemoDownloadUrl() {
    return this.awsS3Service.getDemoDownloadUrl();
  }
  @Post('demo-upload-url')
  createDemoUploadUrl() {
    return this.awsS3Service.createDemoUploadUrl();
  }
  @Post('direct-upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 5 * 1024 * 1024, // Máximo 5 MB
        files: 1,
      },
    }),
  )
  async uploadFileDirectly(
    @UploadedFile(
      new ParseFilePipeBuilder()
        .addFileTypeValidator({
          fileType: /^image\/(png|jpeg)$/,
        })
        .addMaxSizeValidator({
          maxSize: 5 * 1024 * 1024, // Máximo 5 MB
        })
        .build({
          errorHttpStatusCode: HttpStatus.UNPROCESSABLE_ENTITY,
        }),
    )
    file: Express.Multer.File | undefined,
  ) {
    if (!file) {
      throw new BadRequestException(
        'Debes adjuntar un archivo en el campo "file".',
      );
    }

    return this.awsS3Service.uploadFileDirectly(file);
  }
  @Post('demo-upload-post')
  createDemoPresignedPost(@Body('contentType') contentType: string) {
    return this.awsS3Service.createDemoPresignedPost(contentType);
  }
}
