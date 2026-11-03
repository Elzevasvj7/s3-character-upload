resource "aws_s3_bucket" "lab-bucket" {
  bucket = "my-lab-bucket-nando"
  tags = {
    Name        = "My Lab Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "lab_bucket" {
  bucket = aws_s3_bucket.lab-bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lab_bucket" {
  bucket = aws_s3_bucket.lab-bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "lab-bucket" {
  bucket = aws_s3_bucket.lab-bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lab-bucket" {
  bucket = aws_s3_bucket.lab-bucket.id

  depends_on = [
    aws_s3_bucket_versioning.lab-bucket
  ]

  rule {
    id     = "expire-old-lab-versions"
    status = "Enabled"

    filter {
      prefix = "lifecycle-lab/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_cloudfront_origin_access_control" "lab-bucket" {
  name                              = "s3-lab-bucket-cloudfront-oac"
  description                       = "OAC para el laboratorio S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "lab" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Laboratorio S3 y CloudFront"
  price_class     = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.lab-bucket.bucket_regional_domain_name
    origin_id                = "s3-lab-bucket-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.lab-bucket.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-lab-bucket-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "lab-bucket" {
  bucket = aws_s3_bucket.lab-bucket.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowCloudFrontReadDemoPrefix"
        Effect = "Allow"

        Principal = {
          Service = "cloudfront.amazonaws.com"
        }

        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.lab-bucket.arn}/cloudfront-demo/*"

        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.lab.arn
          }
        }
      }
    ]
  })
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.lab.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.lab.id
}