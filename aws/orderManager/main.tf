provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "serverless_lambda_manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name = "LambdaExecutionPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "EventBridgePutEvents",
        Effect = "Allow",
        Action = [
          "events:PutEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "cognito_auth_policy" {
  name = "CognitoAuthPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:AdminInitiateAuth",
          "cognito-idp:InitiateAuth",
          "cognito-idp:RespondToAuthChallenge"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cognito_auth_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.cognito_auth_policy.arn
}

resource "aws_cloudwatch_log_group" "putorder_log_group" {
  name = "/aws/lambda/PutOrderFunction"
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_lambda_function" "PutOrderFunction" {
  function_name = "PutOrderFunction"
  handler       = "handler.putOrder"
  runtime       = "nodejs16.x"
  filename      = "lambda.zip"
  role          = aws_iam_role.lambda_exec_role.arn
}

resource "aws_cognito_user_pool" "order_user_pool" {
  name = "OrderAPIUserPool"
}

resource "aws_cognito_user_pool_client" "order_user_pool_client" {
  name            = "OrderAPIAppClient"
  user_pool_id    = aws_cognito_user_pool.order_user_pool.id
  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

resource "null_resource" "create_default_user" {
  provisioner "local-exec" {
    command = <<EOT
      aws cognito-idp admin-create-user \
        --user-pool-id ${aws_cognito_user_pool.order_user_pool.id} \
        --username default_user \
        --user-attributes Name=email,Value=default@example.com \
        --temporary-password "TemporaryPass123!" \
        --message-action SUPPRESS
    EOT
  }
  depends_on = [
    aws_cognito_user_pool.order_user_pool,
    aws_cognito_user_pool_client.order_user_pool_client
  ]
}

resource "aws_cognito_user_pool_domain" "order_user_pool_domain" {
  domain       = "secure-order-api"
  user_pool_id = aws_cognito_user_pool.order_user_pool.id
}

resource "aws_api_gateway_rest_api" "OrderAPI" {
  name        = "OrderAPI"
  description = "API for placing orders"
}

resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.OrderAPI.id
  parent_id   = aws_api_gateway_rest_api.OrderAPI.root_resource_id
  path_part   = "order"
}

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name            = "CognitoAuthorizer"
  rest_api_id     = aws_api_gateway_rest_api.OrderAPI.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.order_user_pool.arn]
}

resource "aws_api_gateway_method" "post_order" {
  rest_api_id   = aws_api_gateway_rest_api.OrderAPI.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "order_integration" {
  rest_api_id             = aws_api_gateway_rest_api.OrderAPI.id
  resource_id             = aws_api_gateway_resource.order_resource.id
  http_method             = aws_api_gateway_method.post_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.PutOrderFunction.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.PutOrderFunction.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.OrderAPI.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "order_deployment" {
  rest_api_id = aws_api_gateway_rest_api.OrderAPI.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.order_integration
  ]
}

output "apiId" {
  description = "El ID de la API Gateway creada"
  value       = aws_api_gateway_rest_api.OrderAPI.id
}

output "TestingAPI" {
  description = "URL del endpoint de API Gateway"
  value       = "${aws_api_gateway_deployment.order_deployment.invoke_url}/order"
}

output "CognitoClientId" {
  description = "ID del App Client de Cognito para autenticación"
  value       = aws_cognito_user_pool_client.order_user_pool_client.id
}

output "CognitoDomain" {
  description = "Dominio de autenticación para el grupo de usuarios"
  value       = aws_cognito_user_pool_domain.order_user_pool_domain.domain
}

output "CognitoClientSecret" {
  description = "Client secret para OrderAPIAppClient"
  value       = aws_cognito_user_pool_client.order_user_pool_client.client_secret
  sensitive   = true
}
