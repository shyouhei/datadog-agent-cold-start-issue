terraform {
  backend "s3" {
    bucket         = "YOUR_BUCKET"
    key            = "dd-agent-debug.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt        = true
    region         = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1" # == data.aws_region.main.name
}

data "aws_region" "main" {}
data "aws_secretsmanager_secret" "main" {
  name = "YOUR_SECRET"
}
data "aws_secretsmanager_secret_version" "main" {
  secret_id = data.aws_secretsmanager_secret.main.id
}
data "aws_iam_role" "main" {
  name = "YOUR_ROLE"
}
data "aws_iam_policy" "main" {
  name = "AWSLambdaBasicExecutionRole"
}
data "archive_file" "main" {
  type             = "zip"
  output_path      = "${path.root}/.terraform/index.zip"
  output_file_mode = "0666"
  source_file      = "index.mjs"
}

resource "random_id" "main" {
  prefix      = "terraform-"
  byte_length = 39
}

resource "aws_lambda_function" "main" {
  function_name    = random_id.main.b64_url
  filename         = data.archive_file.main.output_path
  source_code_hash = data.archive_file.main.output_base64sha256
  role             = data.aws_iam_role.main.arn
  handler          = "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
  runtime          = "nodejs18.x"
  publish          = true
  timeout          = 60

  layers = [
    "arn:aws:lambda:ap-northeast-1:464622532012:layer:Datadog-Node18-x:90",
    "arn:aws:lambda:ap-northeast-1:464622532012:layer:Datadog-Extension:41",
  ]

  environment {
    variables = {
      "DD_SITE"               = "datadoghq.com"
      "DD_API_KEY_SECRET_ARN" = data.aws_secretsmanager_secret_version.main.arn
      "DD_LAMBDA_HANDLER"     = "index.main"
    }
  }

  tracing_config {
    mode = "Active"
  }
}