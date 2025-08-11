terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0" # Updated to be compatible with all module versions
    }
  }

  required_version = ">= 1.0.0"
}
