##  Setup S3 Backend

Create S3, name must be globally unique
```bash
aws s3api create-bucket --bucket <Bucket-Name> --region ap-southeast-3 --create-bucket-configuration LocationConstraint=ap-southeast-3
```

Go to versions.tf, edit the name accordingly:
```bash
  backend "s3" {
    bucket         = "test-bucket-127345"        # CHANGE THIS
    key            = "state/terraform.tfstate"   
    region         = "ap-southeast-3"          
    encrypt        = true                    
  }
```