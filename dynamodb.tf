resource "aws_dynamodb_table" "waste_log" {
  name         = "${var.project_name}-waste-log"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "resource_id"
  range_key = "detected_at"

  attribute {
    name = "resource_id"
    type = "S"
  }

  attribute {
    name = "detected_at"
    type = "S"
  }
}