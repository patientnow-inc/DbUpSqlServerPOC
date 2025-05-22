provider "aws" {
  region = "us-east-2"
}

# --- S3 Bucket for Artifacts ---
resource "aws_s3_bucket" "dbup_artifacts" {
  bucket = "dbup-artifacts-bucket"

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
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# --- IAM Policy Attachment for CodeBuild Role ---
resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}

# --- CodeBuild Project ---
resource "aws_codebuild_project" "dbup_project" {
  name        = "dbup-project"
  description = "Build project for running DbUp migrations"

  source {
    type      = "S3"
    location  = "${aws_s3_bucket.dbup_artifacts.bucket}/dbup.zip" # <- Object key is needed
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
}
