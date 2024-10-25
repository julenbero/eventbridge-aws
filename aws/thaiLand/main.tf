provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "ThaiLandFunction" {
  function_name = "ThaiLandFunction"
  handler       = "handler.thaiLand"
  runtime       = "nodejs16.x"
  filename      = "lambda.zip"
  role          = aws_iam_role.lambda_exec_role.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda_thailand"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "ThaiLandInvokePermission" {
  statement_id  = "AllowExecutionFromEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ThaiLandFunction.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ThaiLandEventsRule.arn
}

resource "aws_cloudwatch_event_rule" "ThaiLandEventsRule" {
  name        = "ThaiLandEventsRule"
  description = "Order to ThaiLand"

  event_pattern = jsonencode({
    source        = ["custom.orderManager"],
    "detail-type" = ["order"],
    detail = {
      restaurantName = ["thaiLand"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ThaiLandTarget" {
  rule      = aws_cloudwatch_event_rule.ThaiLandEventsRule.name
  target_id = "ThaiLandTarget"
  arn       = aws_lambda_function.ThaiLandFunction.arn
}

resource "aws_cloudwatch_log_group" "thailand_log_group" {
  name = "/aws/lambda/ThaiLandFunction"
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
