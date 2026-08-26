data "archive_file" "idle_detector_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_idle_detector"
  output_path = "${path.module}/lambda_idle_detector/idle_detector.zip"
}

resource "aws_iam_role" "idle_detector_role" {
  name = "${var.project_name}-idle-detector-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.idle_detector_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "idle_detector_policy" {
  name = "${var.project_name}-idle-detector-policy"
  role = aws_iam_role.idle_detector_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeAndReadMetrics"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeVolumes", "cloudwatch:GetMetricStatistics"]
        Resource = "*"
      },
      {
        Sid      = "WriteWasteLog"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.waste_log.arn
      },
      {
        Sid      = "PublishAlerts"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.waste_alerts.arn
      }
    ]
  })
}

resource "aws_lambda_function" "idle_detector" {
  function_name    = "${var.project_name}-idle-detector"
  role             = aws_iam_role.idle_detector_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.idle_detector_zip.output_path
  source_code_hash = data.archive_file.idle_detector_zip.output_base64sha256

  environment {
    variables = {
      WASTE_LOG_TABLE       = aws_dynamodb_table.waste_log.name
      SNS_TOPIC_ARN         = aws_sns_topic.waste_alerts.arn
      CPU_THRESHOLD_PERCENT = tostring(var.cpu_threshold_percent)
      LOOKBACK_DAYS         = tostring(var.lookback_days)
    }
  }
}

resource "aws_cloudwatch_log_group" "idle_detector" {
  name              = "/aws/lambda/${aws_lambda_function.idle_detector.function_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_event_rule" "daily_scan" {
  name                = "${var.project_name}-daily-scan"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "daily_scan_target" {
  rule = aws_cloudwatch_event_rule.daily_scan.name
  arn  = aws_lambda_function.idle_detector.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.idle_detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_scan.arn
}

output "waste_log_table" {
  value = aws_dynamodb_table.waste_log.name
}

output "idle_detector_function_name" {
  value = aws_lambda_function.idle_detector.function_name
}
