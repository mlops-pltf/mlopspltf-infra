# mlopspltf-infra
This repository holds all the infrastructure-as-code elements for MLOps platform project.

## Running the codebase from Local
I have tried to write the repo following DRY principle as much as possible when it coomes to maintaining multiple evironments. All the modules are parameterized to use environment as variable and the remote backend properties are also parameterized.
I am using AWS S3 & DynamoDB as the remote backend. The bucket anme and DDB table names are as follows:
- mlopspltf-<env>-s3-tf-backend
- mlopspltf-<env>-ddb-tf-backend

### Config/Parameter files
There is a small catch, terraform doesn't allow us to use variable interpolation in backend section. But it does provide an option to store the backend configurations in config files and pass the file name from command line input of `terraform init`. I have used this option. The backend properties are stored in environment specific config files:

- backend_configs
    - dev.config
    - prd.config
    - tst.config

Similarly we have created environment spefici variable files, maintaining similar structure, which are passed as command line input in `terraform plan/apply/destroy`.

- env_specific_vars
    - dev.tfvars
    - prd.tfvars
    - tst.tfvars

### How to switch between environments
The idea is to configure AWS backend one time from local for each environments and then use environment specific config files to run the commands. To do so, we have to make sure we are logged into the correct environment. In my local I am using AWS SSO login, as my AWS environment is already setup with AWS Organization, AWS IAM Identity Center & Azure Entra ID. But this can be done manually configuring AWS profiles also using `aws configure sso` and `aws sso login`. Or we can direct export the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as OS environment variables. Also for using SSO user, `AWS_SESSION_TOKEN` has to be exported.

#### Commands for AWS SSO Login
- `aws sso login --profile mlaipltf-managed-profile`
- Execute `eval "$(aws configure export-credentials --profile mlaipltf-managed-profile --format env)"`
<!-- - Add `profile = "mlaipltf-managed-profile"` in the `provider` section of `entrypoint/main.tf` -->


### One time backend setup
There is a initial one time work to configure the backends. As mentioned before the state files and locks will be maintained s3 bucket and DynamoDB. But we have to create those bucket and table before we can use them as state manager for rest of the lifecycle.

The idea is, use `local` backend (comment out the backend section in root module) one time, and create the bucket and DDB table first:
#### Commands (replace <env> with actual environment tag)
- terraform init
- terraform plan --var-file="../env_specific_vars/<env>.tfvars"
- terraform apply --var-file="../env_specific_vars/<env>.tfvars" -auto-approve

Note that, this will create one `terraform.tfstate` file in your local. Now, once the apply is also executed, the bucket should be available in the AWS environment. Now we can upload this tfstae file to the path we are going to mention in the backend config (key property). For this module it is `mlopspltf_infra/tf_remote_backend/terraform.tfstate`. Then, uncomment the backend section in `main.tf`.
Please note, **for any future new modules, this step is not required**.

### Working with multiple remote environments
For any future modules, we just start using the bucket and ddb table as s3 backend. Commands are as follows:
### Commands
- terraform init -backend-config="../backend_configs/<env>.config"
- terraform plan --var-file="../env_specific_vars/<env>.tfvars"
- terraform apply --var-file="../env_specific_vars/<env>.tfvars"