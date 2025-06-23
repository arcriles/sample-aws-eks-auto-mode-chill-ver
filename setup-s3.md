##  Setup S3 Backend

Create S3, name must be globally unique
```bash
aws s3api create-bucket --bucket <Bucket-Name> --region ap-southeast-3 --create-bucket-configuration LocationConstraint=ap-southeast-3
```

Go to variables.tf, edit first variable from this:
```bash
variable "remote_state_bucket" {
  description = "Name of the S3 bucket storing the remote state"
  type        = string
}
```

to this:
```bash
variable "remote_state_bucket" {
  description = "Name of the S3 bucket storing the remote state"
  default     = <Bucket-Name>
  type        = string
}
```