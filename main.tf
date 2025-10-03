terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "eu-central-1"
}

resource "aws_s3_bucket" "code_files" {
  bucket = "imageprocessingwebsite-code-files"
}

resource "aws_s3_bucket_object" "pillow_layer" {
  bucket = aws_s3_bucket.code_files.id
  key    = "pillow.zip"
  source = "${path.module}/lambda/create-thumbnail-lambda/pillow-layer.zip"
}

resource "aws_s3_bucket_object" "CreatePostPresignedUrlLambdaCode" {
  bucket = aws_s3_bucket.code_files.id
  key    = "create-post-presigned-url-lambda.zip"
  source = "${path.module}/lambda/create-post-presigned-url-lambda/create-post-presigned-url-lambda.zip"
}

resource "aws_s3_bucket_object" "CreateThumbnailsLambdaCode" {
  bucket = aws_s3_bucket.code_files.id
  key    = "create-thumbnails-lambda.zip"
  source = "${path.module}/lambda/create-thumbnail-lambda/create-thumbnail-lambda.zip"
}

resource "aws_s3_bucket" "S3Bucket" {
    bucket = "imageprocessingprojectwebsite"
}

resource "aws_s3_bucket_object" "index_html" {
  bucket = aws_s3_bucket.S3Bucket.id
  key    = "index.html"
  source = "${path.module}/index.html"
  content_type = "text/html"
  depends_on = [aws_s3_bucket.S3Bucket]
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.S3Bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
  depends_on = [aws_s3_bucket.S3Bucket]
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.S3Bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.S3Bucket.arn}/*"
      }
    ]
  })
  depends_on = [aws_s3_bucket.S3Bucket]
}

# enable static website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.S3Bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html" # or error.html if you have one
  }
  depends_on = [aws_s3_bucket.S3Bucket]
}

# ======================================================================
# S3 bucket for storing the processed images
# ======================================================================

resource "aws_s3_bucket" "S3Bucket2" {
    bucket = "imageprocessingwebsitedata"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion" {
  layer_name          = "pillow-layer"
  s3_bucket           = aws_s3_bucket.code_files.id
  s3_key              = aws_s3_bucket_object.pillow_layer.key
  compatible_runtimes = ["python3.13"]
}

resource "aws_s3_bucket_cors_configuration" "data_bucket_cors" {
  bucket = aws_s3_bucket.S3Bucket2.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]  # Or your website domain if you want stricter control
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.S3Bucket2.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.CreateThumbnailsLambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "originals/" # Filtering happens here
  }

  # This ensures the permission is created before the notification
  depends_on = [aws_lambda_permission.LambdaPermission2]
}

# ======================================================================
#                            IAM roles
# ======================================================================

# ======================================================================
# IAM policys for the lambda functions
# ======================================================================

resource "aws_iam_policy" "CreateThumbnailsLambdaPolicy" {
  name = "CreateThumbnailsLambdaPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
        ],
        "Resource": [
          "${aws_s3_bucket.S3Bucket2.arn}/*"
        ]
      }
    ]
  })
  description = "Policy for a lambda function to create thumbnails"
}

resource "aws_iam_policy" "CreatePostPresignedUrlLambdaPolicy" {
  name = "CreatePostPresignedUrlLambdaPolicy"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
        ],
        "Resource": [
          "${aws_s3_bucket.S3Bucket2.arn}/*"
        ]
      }
    ]
  })
  description = "Policy for the lambda function to create presigned URLs for image uploads"
}

# ======================================================================
# IAM roles for the lambda functions
# ======================================================================

resource "aws_iam_role" "CreateThumbnailsLambdaRole" {
  name = "CreateThumbnailsLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "CreatePostPresignedUrlLambdaRole" {
  name = "CreatePostPresignedUrlLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "create_presigned_url_policy_attach" {
  role       = aws_iam_role.CreatePostPresignedUrlLambdaRole.name
  policy_arn = aws_iam_policy.CreatePostPresignedUrlLambdaPolicy.arn
}

resource "aws_iam_role_policy_attachment" "create_thumbnails_policy_attach" {
  role       = aws_iam_role.CreateThumbnailsLambdaRole.name
  policy_arn = aws_iam_policy.CreateThumbnailsLambdaPolicy.arn
}

# ======================================================================
#                            Lambda functions
# ======================================================================

# ======================================================================
# Lambda function to create presigned URLs for image uploads
# ======================================================================
resource "aws_lambda_function" "CreatePostPresignedUrlLambda" {
    description = "Lambda function to create presigned URLs image uploads"
    environment {
        variables = {
          REGION_NAME = "eu-central-1"
          BUCKET_NAME = aws_s3_bucket.S3Bucket2.id
        }
    }
    function_name = "CreatePostPresignedUrlLambda"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = aws_s3_bucket.code_files.id
    s3_key    = aws_s3_bucket_object.CreatePostPresignedUrlLambdaCode.key
    memory_size = 128
    role = aws_iam_role.CreatePostPresignedUrlLambdaRole.arn
    runtime = "python3.13"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

# ======================================================================
# Lambda function to create thumbnails for images
# ======================================================================
resource "aws_lambda_function" "CreateThumbnailsLambda" {
    description = "Create thumbnails for images"
    environment {
        variables = {
            REGION_NAME = "eu-central-1"
            BUCKET_NAME = "${aws_s3_bucket.S3Bucket2.id}"
        }
    }
    function_name = "CreateThumbnailsLambda"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    memory_size = 128
    runtime = "python3.13"
    s3_bucket = aws_s3_bucket.code_files.id
    s3_key    = aws_s3_bucket_object.CreateThumbnailsLambdaCode.key
    role = aws_iam_role.CreateThumbnailsLambdaRole.arn
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        aws_lambda_layer_version.LambdaLayerVersion.arn
    ]
}

resource "aws_lambda_permission" "LambdaPermission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.CreatePostPresignedUrlLambda.arn
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.ApiGatewayV2Api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "LambdaPermission2" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.CreateThumbnailsLambda.arn
    principal = "s3.amazonaws.com"
    source_arn = aws_s3_bucket.S3Bucket2.arn # Corrected: Use only the bucket ARN
}

# ======================================================================
#                            API Gateway
# ======================================================================

resource "aws_apigatewayv2_api" "ApiGatewayV2Api" {
    api_key_selection_expression = "$request.header.x-api-key"
    protocol_type = "HTTP"
    name = "ImageProcessingAPI"
    route_selection_expression = "$request.method $request.path"
    cors_configuration {
        allow_credentials = false
        allow_headers = [
            "content-type,x-amz-date,authorization,x-api-key,x-amz-security-token"
        ]
        allow_methods = [
            "POST",
            "OPTIONS",
            "*"
        ]
        allow_origins = [
            "*"
        ]
        max_age = 0
    }
}

resource "aws_apigatewayv2_integration" "s3_site_integration" {
  api_id                 = aws_apigatewayv2_api.ApiGatewayV2Api.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "INTERNET"
  integration_method     = "GET"
  integration_uri        = "http://imageprocessingprojectwebsite.s3-website.eu-central-1.amazonaws.com/"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    connection_type = "INTERNET"
    integration_method = "POST"
    integration_type = "AWS_PROXY"
    integration_uri = "${aws_lambda_function.CreatePostPresignedUrlLambda.arn}"
    timeout_milliseconds = 30000
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "HomeRoute" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    api_key_required = false
    authorization_type = "NONE"
    # integration_type = "HTTP_PROXY"
    route_key = "ANY /"
    target = "integrations/${aws_apigatewayv2_integration.s3_site_integration.id}"
}

resource "aws_apigatewayv2_route" "ApiGatewayV2Route2" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    api_key_required = false
    authorization_type = "NONE"
    route_key = "POST /upload"
    target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
    name = "$default"
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    auto_deploy = true
    default_route_settings {
        detailed_metrics_enabled = false
        throttling_burst_limit = 2000
        throttling_rate_limit  = 1000
    }
    tags = {}
}
