resource "aws_s3_bucket" "bucket" {
  bucket = "hg-s3-frontend-bucket"
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_iam_role" "role" {
  name = "api-gateway-s3-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "api-gateway-s3-policy"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   },
   {
        "Effect": "Allow",
        "Action": [
            "s3:*"
        ],
        "Resource": "arn:aws:s3:::*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_api_gateway_rest_api" "frontend_api_gateway" {
  name = "FrontendGateway"
}

resource "aws_api_gateway_resource" "frontend_file_resource" {
  parent_id   = aws_api_gateway_rest_api.frontend_api_gateway.root_resource_id
  path_part   = "{path}"
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id
}

resource "aws_api_gateway_method" "frontend_file_method" {
  rest_api_id   = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id   = aws_api_gateway_resource.frontend_file_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.path" = true
    "method.request.header.Accept" = true
    "method.request.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration" "frontend_file_handler" {
  http_method             = aws_api_gateway_method.frontend_file_method.http_method
  integration_http_method = aws_api_gateway_method.frontend_file_method.http_method
  resource_id             = aws_api_gateway_resource.frontend_file_resource.id
  rest_api_id             = aws_api_gateway_rest_api.frontend_api_gateway.id
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:us-east-2:s3:path/${aws_s3_bucket.bucket.bucket}/{path}"
  credentials             = aws_iam_role.role.arn
  request_parameters = {
    "integration.request.path.path" = "method.request.path.path"
    "integration.request.header.Content-Type" = "method.request.header.Content-Type"
    "integration.request.header.Accept" = "method.request.header.Accept"
  }
}

resource "aws_api_gateway_method_response" "frontend_file_method_response" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id = aws_api_gateway_resource.frontend_file_resource.id
  http_method = aws_api_gateway_method.frontend_file_method.http_method
  status_code = "200"
  response_parameters = { 
    "method.response.header.Content-Type" = true 
    "method.response.header.Content-Length" = true 
  }
}

resource "aws_api_gateway_integration_response" "frontend_file_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id = aws_api_gateway_resource.frontend_file_resource.id
  http_method = aws_api_gateway_method.frontend_file_method.http_method
  status_code = aws_api_gateway_method_response.frontend_file_method_response.status_code

  response_parameters = { 
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
  }
}