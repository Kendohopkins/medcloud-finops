resource "aws_iam_user" "grafana" {
  name = "${var.project_name}-grafana"
}

resource "aws_iam_policy" "grafana_cloudwatch_read" {
  name        = "${var.project_name}-grafana-cloudwatch-read"
  description = "Read-only CloudWatch metrics and logs access for Grafana"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      # CloudWatch metrics
      {
        Effect = "Allow"

        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]

        Resource = "*"
      },

      # CloudWatch Logs
      {
        Effect = "Allow"

        Action = [
          "logs:DescribeLogGroups",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "grafana_cloudwatch_read" {
  user       = aws_iam_user.grafana.name
  policy_arn = aws_iam_policy.grafana_cloudwatch_read.arn
}