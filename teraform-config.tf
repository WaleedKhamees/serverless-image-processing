terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = "eu-central-1"
}

resource "aws_lambda_function" "LambdaFunction" {
    description = ""
    environment {
        variables {
            REGION_NAME = "eu-central-1"
            BUCKET_NAME = "${aws_s3_bucket.S3Bucket2.id}"
        }
    }
    function_name = "CreatePostPresignedUrlLambda"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-cent-1-tasks"
    s3_key = "/snapshots/222634384254/CreatePostPresignedUrlLambda-4cbe83fe-c3cc-4116-ab78-5981f20cae5b"
    s3_object_version = "naXMuOjX_eAbpzLgvAuQy6bx2fDTxMrZ"
    memory_size = 128
    role = "arn:aws:iam::222634384254:role/PresignedPostLambda"
    runtime = "python3.13"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
}

resource "aws_lambda_function" "LambdaFunction2" {
    description = ""
    environment {
        variables {
            REGION_NAME = "eu-central-1"
            BUCKET_NAME = "${aws_s3_bucket.S3Bucket2.id}"
        }
    }
    function_name = "CreateThumbnailsLambda"
    handler = "lambda_function.lambda_handler"
    architectures = [
        "x86_64"
    ]
    s3_bucket = "awslambda-eu-cent-1-tasks"
    s3_key = "/snapshots/222634384254/CreateThumbnailsLambda-9ebd10b2-052a-4492-9ef0-f04234b4c553"
    s3_object_version = "982hpulfCr_AZDxY94LdCTWfdnIlj6CY"
    memory_size = 128
    role = "arn:aws:iam::222634384254:role/service-role/CreateThumbnailsLambda-role-j285hijd"
    runtime = "python3.13"
    timeout = 3
    tracing_config {
        mode = "PassThrough"
    }
    layers = [
        "arn:aws:lambda:eu-central-1:222634384254:layer:pillow-layer:1"
    ]
}

resource "aws_s3_bucket" "S3Bucket" {
    bucket = "imageprocessingprojectwebsite"
}

resource "aws_s3_bucket" "S3Bucket2" {
    bucket = "imageprocessingwebsitedata"
}

resource "aws_s3_bucket_policy" "S3BucketPolicy" {
    bucket = "${aws_s3_bucket.S3Bucket.id}"
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadGetObject\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::imageprocessingprojectwebsite/*\"}]}"
}

resource "aws_lambda_permission" "LambdaPermission" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:eu-central-1:222634384254:z0v6ao1cb3/*/*/upload"
}

resource "aws_lambda_permission" "LambdaPermission2" {
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.LambdaFunction2.arn}"
    principal = "s3.amazonaws.com"
    source_arn = "${aws_s3_bucket.S3Bucket2.arn}"
}

resource "aws_lambda_layer_version" "LambdaLayerVersion" {
    description = ""
    compatible_runtimes = [
        "python3.13"
    ]
    layer_name = "pillow-layer"
    s3_bucket = "awslambda-eu-cent-1-layers"
    s3_key = "/snapshots/222634384254/pillow-layer-377d568f-a429-45c6-aea4-c6a9662df9bf"
}

resource "aws_apigatewayv2_integration" "ApiGatewayV2Integration" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    connection_type = "INTERNET"
    integration_method = "ANY"
    integration_type = "HTTP_PROXY"
    integration_uri = "http://imageprocessingprojectwebsite.s3-website.eu-central-1.amazonaws.com/"
    timeout_milliseconds = 30000
    payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "ApiGatewayV2Integration2" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    connection_type = "INTERNET"
    integration_method = "POST"
    integration_type = "AWS_PROXY"
    integration_uri = "${aws_lambda_function.LambdaFunction.arn}"
    timeout_milliseconds = 30000
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ApiGatewayV2Route" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    api_key_required = false
    authorization_type = "NONE"
    route_key = "ANY /"
    target = "integrations/9is0vos"
}

resource "aws_apigatewayv2_route" "ApiGatewayV2Route2" {
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    api_key_required = false
    authorization_type = "NONE"
    route_key = "POST /upload"
    target = "integrations/hjlguk8"
}

resource "aws_apigatewayv2_stage" "ApiGatewayV2Stage" {
    name = "$default"
    stage_variables {}
    api_id = "${aws_apigatewayv2_api.ApiGatewayV2Api.id}"
    deployment_id = "r85rci"
    default_route_settings {
        detailed_metrics_enabled = false
    }
    auto_deploy = true
    tags = {}
}

resource "aws_apigatewayv2_api" "ApiGatewayV2Api" {
    api_key_selection_expression = "$request.header.x-api-key"
    protocol_type = "HTTP"
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
    tags = {}
}

