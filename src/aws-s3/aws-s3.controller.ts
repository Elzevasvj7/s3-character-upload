import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpStatus,
  ParseFilePipeBuilder,
  Post,
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
  @Post('create-upload-url')
  createDemoPresignedPost(@Body('contentType') contentType: string) {
    return this.awsS3Service.createDemoPresignedPost(contentType);
  }

  @Get('version')
  getVersion() {
    return {
      service: 'aws-sdk-s3-lab',
      version: '2.0.0',
      message: 'Running version 2',
    };
  }
}
