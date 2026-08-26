resource "aws_sns_topic" "waste_alerts" {
  name = "${var.project_name}-waste-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.waste_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
