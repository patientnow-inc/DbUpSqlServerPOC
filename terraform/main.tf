provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "dbup_artifacts" {
  bucket = "dbup-artifacts-bucket"
}

resource "aws_iam_role" "codebuild_service_role" {
  name = "codebuild-dbup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_attach_policy" {
  role       = aws_iam_role.codebuild_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_codebuild_project" "dbup_project" {
  name          = "dbup-project"
  service_role  = aws_iam_role.codebuild_service_role.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    environment_variables = [
      {
        name  = "CONNECTION_STRING"
        value = "Server=mydb;Database=test;User Id=sa;Password=pass;"
      }
    ]
  }
  source {
    type      = "S3"
    location  = "${aws_s3_bucket.dbup_artifacts.bucket}/publish.zip"
    buildspec = "buildspec.yml"
  }
}
