provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "dbup_artifacts" {
  bucket = "dbup-artifacts-bucket"
}

resource "aws_codebuild_project" "dbup_project" {
  name          = "dbup-project"
  description   = "Build project for running DbUp migrations"

  source {
    type      = "S3"
    location  = "${aws_s3_bucket.dbup_artifacts.bucket}/"
    buildspec = "buildspec.yml"
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

resource "aws_iam_role" "codebuild_service_role" {
  name = "codebuild-dbup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess"
}
