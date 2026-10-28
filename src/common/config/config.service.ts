import { Injectable } from "@nestjs/common";
import { ConfigService as NestConfigService } from "@nestjs/config";
/**
 * Acceso tipado y agrupado a la configuración validada.
 * Inyectable en cualquier módulo (auth, storage, mt5, nowpayments).
 */
@Injectable()
export class ConfigService {
  constructor(private readonly config: NestConfigService) {}

  private get<T = string>(key: string): T | undefined {
  return this.config.get<T>(key);
}

  get nodeEnv() {
    return this.get("NODE_ENV");
  }

  get isProduction() {
    return this.get("NODE_ENV") === "production";
  }

  get port() {
    return this.get("PORT");
  }
  get aws() {
    return {
      region: this.get("AWS_REGION"),
      profile: this.get("AWS_PROFILE"),
      bucket: this.get("AWS_BUCKET") ?? "my-lab-bucket-nando",
      accessKeyId: this.get("AWS_ACCESS_KEY_ID"),
      secretAccessKey: this.get("AWS_SECRET_ACCESS_KEY"),
      uploadProfile: this.get("AWS_UPLOAD_PROFILE"),

    };
  }
}
