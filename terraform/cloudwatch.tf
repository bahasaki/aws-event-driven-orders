# --- Alarm: сообщения в processing DLQ ---

resource "aws_cloudwatch_metric_alarm" "processing_dlq_depth" {
  alarm_name          = "${var.project_name}-processing-dlq-depth-${var.environment}"
  alarm_description   = "Messages in processing DLQ - indicates processor Lambda failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.processing_dlq.name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarm: сообщения в notification DLQ ---

resource "aws_cloudwatch_metric_alarm" "notification_dlq_depth" {
  alarm_name          = "${var.project_name}-notification-dlq-depth-${var.environment}"
  alarm_description   = "Messages in notification DLQ - indicates notifier Lambda failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.notification_dlq.name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# --- Alarm: Lambda processor errors ---

resource "aws_cloudwatch_metric_alarm" "processor_errors" {
  alarm_name          = "${var.project_name}-processor-errors-${var.environment}"
  alarm_description   = "Processor Lambda error rate elevated"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}