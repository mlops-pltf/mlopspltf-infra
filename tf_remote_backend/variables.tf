variable "environment" {
  description = "Environemnt Name"
  type        = string
}

variable "tf_remote_backend_bucket_name" {
  description = "Terraform remote backend s3 bucket name"
  type        = string
}

variable "tf_remote_backend_ddb_table_name" {
  description = "Terraform remote backend DDB table name"
  type        = string
}
