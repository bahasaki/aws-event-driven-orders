locals {
  producer_src  = "${path.module}/../lambdas/producer"
  processor_src = "${path.module}/../lambdas/processor"
  notifier_src  = "${path.module}/../lambdas/notifier"
}

# --- ZIP archives ---

data "archive_file" "producer" {
  type        = "zip"
  source_dir  = local.producer_src
  output_path = "${path.module}/../lambdas/producer.zip"
}

data "archive_file" "processor" {
  type        = "zip"
  source_dir  = local.processor_src
  output_path = "${path.module}/../lambdas/processor.zip"
}

data "archive_file" "notifier" {
  type        = "zip"
  source_dir  = local.notifier_src
  output_path = "${path.module}/../lambdas/notifier.zip"
}

# --- Upload to S3 ---

resource "aws_s3_object" "producer" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "producer.zip"
  source = data.archive_file.producer.output_path
  etag   = data.archive_file.producer.output_md5
}

resource "aws_s3_object" "processor" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "processor.zip"
  source = data.archive_file.processor.output_path
  etag   = data.archive_file.processor.output_md5
}

resource "aws_s3_object" "notifier" {
  bucket = aws_s3_bucket.lambda_artifacts.bucket
  key    = "notifier.zip"
  source = data.archive_file.notifier.output_path
  etag   = data.archive_file.notifier.output_md5
}

# --- Lambda functions ---

resource "aws_lambda_function" "producer" {
  function_name = "${var.project_name}-producer-${var.environment}"
  role          = aws_iam_role.producer.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  s3_bucket        = aws_s3_bucket.lambda_artifacts.bucket
  s3_key           = aws_s3_object.producer.key
  source_code_hash = data.archive_file.producer.output_base64sha256

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.order_events.arn
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor-${var.environment}"
  role          = aws_iam_role.processor.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  s3_bucket        = aws_s3_bucket.lambda_artifacts.bucket
  s3_key           = aws_s3_object.processor.key
  source_code_hash = data.archive_file.processor.output_base64sha256

  timeout     = 30
  memory_size = 128

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_lambda_function" "notifier" {
  function_name = "${var.project_name}-notifier-${var.environment}"
  role          = aws_iam_role.notifier.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  s3_bucket        = aws_s3_bucket.lambda_artifacts.bucket
  s3_key           = aws_s3_object.notifier.key
  source_code_hash = data.archive_file.notifier.output_base64sha256

  timeout     = 30
  memory_size = 128

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- SQS Event Source Mappings ---

resource "aws_lambda_event_source_mapping" "processor" {
  event_source_arn = aws_sqs_queue.processing_queue.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_lambda_event_source_mapping" "notifier" {
  event_source_arn = aws_sqs_queue.notification_queue.arn
  function_name    = aws_lambda_function.notifier.arn
  batch_size       = 1
  enabled          = true
}