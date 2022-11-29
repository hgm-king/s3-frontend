resource "aws_s3_bucket" "bucket" {
  bucket = "hg-s3-frontend-bucket"
}

resource "aws_s3_object" "file_upload" {
  bucket = aws_s3_bucket.bucket.id
  // this makes TF recognize that the zip has changed

  for_each = fileset("${path.module}/../dist/", "*")

  key    = each.value
  source = "${path.module}/../dist/${each.value}"
  # etag makes the file update when it changes; see https://stackoverflow.com/questions/56107258/terraform-upload-file-to-s3-on-every-apply
  etag   = filemd5("${path.module}/../dist/${each.value}")
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
        "Service": "apigateway.amazonaws.com"
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


resource "aws_api_gateway_method" "index_file_method" {
  rest_api_id   = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id   = aws_api_gateway_rest_api.frontend_api_gateway.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.path" = true
    "method.request.header.Accept" = true
    "method.request.header.Content-Type" = true
  }
}

resource "aws_api_gateway_integration" "index_file_handler" {
  http_method             = aws_api_gateway_method.index_file_method.http_method
  integration_http_method = aws_api_gateway_method.index_file_method.http_method
  resource_id             = aws_api_gateway_rest_api.frontend_api_gateway.root_resource_id
  rest_api_id             = aws_api_gateway_rest_api.frontend_api_gateway.id
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:us-east-2:s3:path/${aws_s3_bucket.bucket.bucket}/index.html"
  credentials             = aws_iam_role.role.arn
  request_parameters = {
    "integration.request.path.path" = "method.request.path.path"
    "integration.request.header.Content-Type" = "method.request.header.Content-Type"
    "integration.request.header.Accept" = "method.request.header.Accept"
  }
}

resource "aws_api_gateway_method_response" "index_file_method_response" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id = aws_api_gateway_rest_api.frontend_api_gateway.root_resource_id
  http_method = aws_api_gateway_method.index_file_method.http_method
  status_code = "200"
  response_parameters = { 
    "method.response.header.Content-Type" = true 
    "method.response.header.Content-Length" = true 
  }
}

resource "aws_api_gateway_integration_response" "index_file_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id
  resource_id = aws_api_gateway_rest_api.frontend_api_gateway.root_resource_id
  http_method = aws_api_gateway_method.index_file_method.http_method
  status_code = aws_api_gateway_method_response.index_file_method_response.status_code
  response_parameters = { 
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type" = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.frontend_api_gateway.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.frontend_file_resource.id,
      aws_api_gateway_method.frontend_file_method.id,
      aws_api_gateway_method.index_file_method.id,
      aws_api_gateway_integration.frontend_file_handler.id,
      aws_api_gateway_integration.index_file_handler.id,
      aws_api_gateway_integration_response.index_file_integration_response.id,
      aws_api_gateway_integration_response.frontend_file_integration_response.id,
      aws_api_gateway_method_response.frontend_file_method_response.id,
      aws_api_gateway_method_response.index_file_method_response.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1_api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.api_gateway_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.frontend_api_gateway.id
  stage_name    = "v1"
}