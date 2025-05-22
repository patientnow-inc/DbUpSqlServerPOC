provider "aws" {
  region = "us-east-2"
}

# --- S3 Bucket for Artifacts ---
resource "aws_s3_bucket" "dbup_artifacts" {
  bucket = "my-dbup-dev-bucket"

  versioning {
    enabled = true
  }

  tags = {
    Name        = "DbUp Artifacts"
    Environment = "Dev"
  }
}

# --- IAM Role for CodeBuild ---
resource "aws_iam_role" "codebuild_service_role" {
  name = "codebuild-dbup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# --- IAM Policy to allow CodeBuild to read from S3 ---
resource "aws_iam_policy" "codebuild_s3_access_policy" {
  name        = "codebuild-s3-access-policy"
  description = "Allow CodeBuild to read from the artifact bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dbup_artifacts.arn,
          "${aws_s3_bucket.dbup_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# --- Attach AWS Managed and Custom Policy ---
resource "aws_iam_role_policy_attachment" "codebuild_managed_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = aws_iam_policy.codebuild_s3_access_policy.arn
}

# --- CodeBuild Project ---
resource "aws_codebuild_project" "dbup_project" {
  name        = "dbup-project"
  description = "Build project for running DbUp migrations"

  source {
    type      = "S3"
    location  = "${aws_s3_bucket.dbup_artifacts.bucket}/dbup.zip" # actual S3 object
    buildspec = "buildspec.yml"
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    environment_variables = [
      {
        name  = "DOTNET_ROOT"
        value = "/usr/share/dotnet"
      }
    ]
  }

  service_role = aws_iam_role.codebuild_service_role.arn

  tags = {
    Environment = "Dev"
    Project     = "DbUp"
  }
}
