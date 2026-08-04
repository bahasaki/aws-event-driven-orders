resource "aws_sns_topic" "order_events" {
  name = "${var.project_name}-order-events-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}