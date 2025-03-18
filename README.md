# mlopspltf-infra
This repository holds all the infrastructure-as-code elements for MLOps platform project.

In this project we have decided to use `Terraform` as IaC framework. On the CICD from we will use Github Actions. So in this section we will discuss how to implement `Github Workflows` that wil deploy our infrastructure to `AWS Cloud` using `Terraform`.

## CICD Structure
This repository will has one `main` branch, one `develop` branch and multiple `feature/*` branches. The branches represent one particular environment of AWS Environment:
- `main` branch -> AWS `prd` Environment
- `develop` branch -> AWS `tst` Environment
- `feature/*` branch -> AWS `dev` Environment

To maintain this mapping, we will use conditional actions based on branch and git events. We have discussed this below.

### Git Push Event Outcome
For any `push` events, there are four main step:
1. Check if any terraform directory is updated or not.
2. Run `terraform init` and `terraform plan` with proper command line variables to check if the code update is valid or not.
3. If validation (step 2) passes, there is a manual approval step. This is implemented via `GitHub Environments`.
4. If approved then the deployment will happen in the target AWS environment based on the branch.

Target AWS Environment is derived as mentioned below:
1. Any `push` event to `feature/*` branches will use AWS `dev` Environment as target environment.
2. Any `push` event to `develop` branch will use AWS `tst` Environment as  target environment.
2. Any `push` event to `main` branch will use AWS `prd` Environment as  target environment.


### Git Pull Request Event Outcome
There will be validation steps executed for any `pull request` event to either `develop` or `main` branch. In case of `pull-request` only following two steps will be executed:
1. Check if any terraform directory is updated or not.
2. Run `terraform init` and `terraform plan` with proper command line variables to check if the code update is valid or not.

Here also the target AWS Environment derivation is same as mentioned above.

## IAC Structure
Now, coming to `terraform`, we will use AWS S3 and Dynamodb as remote backend. Same bucket and dynamodb table will be used for this entire project. We will store the state files as `{repo-name}/{tf-module-name}/terraform.tfstate`. This way we can reuse the same backend for our entire project, accross multiple repositories.

But as having a AWS backend to support Terraform means we need to deploy AWS S3 and AWS DynamoDB table `via Terraform(?)`. This becomes cyclical and paradoxical.

The solution for this is simple: Deploy the initial setup required from local using locally setup AWS profiles using terraform. Then upload the statefiles that were created in your local to the just deployed S3 bucket in proper path. Then change the terraform `main.tf` in each module to use s3 backend. We have discussed this in detail below.

### First setup backend
In this repo we have tried to follow DRY principle as much as possible when it coomes to maintaining multiple evironments. All the modules are parameterized to use environment as variable and the remote backend properties are also parameterized.

The backend bucket anme and DDB table names are as follows:
- mlopspltf-{env}-s3-tf-backend
- mlopspltf-{env}-ddb-tf-backend

#### Config/Parameter files
There is a small catch, terraform doesn't allow us to use variable interpolation in backend section. But it does provide an option to store the backend configurations in config files and pass the file name from command line input of `terraform init`. We have used this option. The backend properties are stored in environment specific config files:

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
As discussed before, the idea is to configure AWS backend one time from local for each environments and then use environment specific config files to run the commands. To do so, we have to make sure we are logged into the correct environment. In my local I am using AWS SSO login, as my AWS environment is already setup with AWS Organization, AWS IAM Identity Center & Azure Entra ID. But this can be done manually configuring AWS profiles also using `aws configure sso` and `aws sso login`. Or we can direct export the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as OS environment variables. Also for using SSO user, `AWS_SESSION_TOKEN` has to be exported.

#### Commands for AWS SSO Login
- `aws sso login --profile mlaipltf-managed-profile`
- Execute `eval "$(aws configure export-credentials --profile mlaipltf-managed-profile --format env)"`
<!-- - Add `profile = "mlaipltf-managed-profile"` in the `provider` section of `entrypoint/main.tf` -->


### One time backend setup
There is a initial one time work to configure the backends. As mentioned before the state files and locks will be maintained s3 bucket and DynamoDB. But we have to create those bucket and table before we can use them as state manager for rest of the lifecycle.

The idea is, use `local` backend (comment out the backend section in root module) one time, and create the bucket and DDB table first:
#### Commands (replace {env} with actual environment tag)
- terraform init
- terraform plan --var-file="../env_specific_vars/{env}.tfvars"
- terraform apply --var-file="../env_specific_vars/{env}.tfvars" -auto-approve

Note that, this will create one `terraform.tfstate` file in your local. Now, once the apply is also executed, the bucket should be available in the AWS environment. Now we can upload this tfstae file to the path we are going to mention in the backend config (key property). For this module it is `mlopspltf_infra/tf_remote_backend/terraform.tfstate`. Then, uncomment the backend section in `main.tf`.
Please note, **for any future new modules, this step is not required**.

### Using the backend
For any future modules, we just start using the bucket and ddb table as s3 backend. In the `main.tf` module we use below mentioned backend section:
```
   backend "s3" {
    bucket         = ""
    key            = "{terraform state file}"
    region         = "us-east-1"
    dynamodb_table = ""
    encrypt        = true
  }
```

Then follwoing terraform commands can be used:
#### Commands
- terraform init -backend-config="../backend_configs/<env>.config"
- terraform plan --var-file="../env_specific_vars/<env>.tfvars"
- terraform apply --var-file="../env_specific_vars/<env>.tfvars"

### AWS authentication for Terraform from github action
There are multiple options to do AWS authentication in Github Workflow. One of the wide spread technique is to store AWS credentials in `github secrets` and using those in the github workflow. But the main drawback in that process, in key rotation.

So we have decided to use AWS SSO Login using `aws-actions/configure-aws-credentials@v4` git action. There are some pre-requesite for using this action:
- We have to create one Identity Provider for github (if not present already) in AWS IAM
- We have to create one role that github action can assume, we can control the trusted entities in the role configuration.

We have discussed this in much in-depth in my blog here.

That's all for the CICD part of this project. We will use exactly same process for each repository.