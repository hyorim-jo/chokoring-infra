terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # 모든 프로젝트가 같이 쓰는 state 버킷. 프로젝트마다 key 를 나눈다.
  backend "s3" {
    bucket       = "chokoring-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project   = "chokoring-infra"
      ManagedBy = "terraform"
    }
  }
}
