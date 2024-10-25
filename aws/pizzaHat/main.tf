provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "PizzaHatFunction" {
  function_name = "PizzaHatFunction"
  handler       = "handler.pizzaHat"
  runtime       = "nodejs16.x"
  filename      = "lambda.zip"
  role          = aws_iam_role.lambda_exec_role.arn
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda_pizzahat"

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

resource "aws_lambda_permission" "PizzaHatInvokePermission" {
  statement_id  = "AllowExecutionFromEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.PizzaHatFunction.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.PizzaHatEventsRule.arn
}

resource "aws_cloudwatch_event_rule" "PizzaHatEventsRule" {
  name        = "PizzaHatEventsRule"
  description = "Order to PizzaHat"

  event_pattern = jsonencode({
    source        = ["custom.orderManager"],
    "detail-type" = ["order"],
    detail = {
      restaurantName = ["pizzaHat"]
    }
  })
}

resource "aws_cloudwatch_event_target" "PizzaHatTarget" {
  rule      = aws_cloudwatch_event_rule.PizzaHatEventsRule.name
  target_id = "PizzaHatTarget"
  arn       = aws_lambda_function.PizzaHatFunction.arn
}

resource "aws_cloudwatch_log_group" "pizzahat_log_group" {
  name = "/aws/lambda/PizzaHatFunction"
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
