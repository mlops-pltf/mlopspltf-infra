# mlopspltf-infra
This repository holds all the infrastructure-as-code elements for MLOps platform project.


## AWS SSO Login for Local

While testing from local, first we need to login to AWS using SSO and then use the specific profile in the code.
Please follow the below mentioned steps once every time after logging in:
- `aws sso login --profile mlaipltf-managed-profile`
- Execute `eval "$(aws configure export-credentials --profile mlaipltf-managed-profile --format env)"`
- Add `profile = "mlaipltf-managed-profile"` in the `provider` section of `entrypoint/main.tf`


## Backend Configuration
We have to firt create the s3 bucket and dynamodb table to be used as backend of Terraform.
### Commands
- terraform init
- terraform plan --var-file="../env_specific_vars/tst.tfvars"
- terraform apply --var-file="../env_specific_vars/tst.tfvars" -auto-approve

Once the remote backend objects are created we can uncomment the backend section in the `main.tf`.
Also we have to manually upload the `.tfstate` file that is generated in the last step to the backend path that is mentioned.
Once these two steps are done, run following commands to sync with the remote backend:
### Commands
- terraform init -backend-config="../backend_configs/tst.config"
- terraform plan --var-file="../env_specific_vars/tst.tfvars"
- terraform apply --var-file="../env_specific_vars/tst.tfvars"