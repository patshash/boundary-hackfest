## Pre-Requisites
- HCP Account
- AWS Account
- [HCP service principal credentials](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/guides/auth)
- [Auth0 Account](https://auth0.com/signup)
- [Auth0 Machine-Machine client application](https://registry.terraform.io/providers/auth0/auth0/latest/docs/guides/quickstart)
- [Boundary CLI](https://developer.hashicorp.com/boundary/tutorials/hcp-getting-started/hcp-getting-started-install?in=boundary%2Fhcp-getting-started)
- [Boundary Desktop (Optional)](https://developer.hashicorp.com/boundary/tutorials/hcp-getting-started/hcp-getting-started-desktop-app)
- Microsoft Remote Desktop

# Export following variables in .envrc file
```sh
export TF_VAR_hcp_client_id=<hcp_client_id>
export TF_VAR_hcp_client_secret=<hcp_client_secret>
export TF_VAR_auth0_domain=<auth0_domain>
export TF_VAR_auth0_client_id=<auth0_client_id>
export TF_VAR_auth0_client_secret=<auth0_client_secret>
export TF_VAR_hcp_boundary_admin=<hcp_boundary_username>
export TF_VAR_hcp_boundary_password=<hcp_boundary_password>
export TF_VAR_user_password=<auth0_user_password>
export TF_VAR_rds_username=<rds_username>
export TF_VAR_rds_password=<rds_password>
```
## Clone this repo to your local machine
```sh
git clone https://github.com/panchal-ravi/boundary-hackfest.git
cd <cloned-directory>
```

## Build HCP Boundary self-managed worker image using packer
```sh
cd amis/boundary
# Verify region is set correctly in variables.pkrvars.hcl file
packer build -var-file="variables.pkrvars.hcl"
```

## Setup HCP Boundary Cluster
```sh
./setup.sh
terraform init
terraform validate
terraform apply -target module.boundary-cluster -auto-approve
```
This step creates and configures several resources mentioned below.
- Auth0 resources:
    - Login to Auth0
    - Click "Applications" in the left panel. `b-hackfest-<id>` client application should be created
    - Click "User Management > Roles" in the left panel. Two roles `admin` and `analyst` should be created 
    - Click "User Management > Users" in the left panel. Two users `admin` and `analyst` should be created 
    - Click "Actions > Flow" in the left panel. Click "Login" flow. A custom login flow should be created. This custom action adds role information to OIDC token returned to Boundary.
- Vault:
    - Self-managed Vault instance should be up and running. 
    - Run `terraform output` to view the Vault public IP. 
    - Vault root token should be available in `./generated/vault-token` file
    - Open browser and enter http://<vault-ip>:8200. Verify you are able to login using the root token.
- Self-managed worker:
    - Verify the self-managed boundary worker has started and registered successfully
    - Run `terraform output` to view the Worker public IP.
        ```sh
        ssh -i ./generaged/ssh-key ubuntu@<worker-ip>
        systemctl status boundary-worker
        journalctl -flu boundary-worker
        ```
    - There should be no errors reported in the journal logs


## Setup Boundary core resources (Org, Project, Authentication Method, Principles, Roles)
```
terraform apply -target module.boundary-resources -auto-approve
```
Verify following resources are created in Boundary:
- Scopes:
    - Verify `demo-org` organization is created. This should be shown whenever user logs in.
    - Click `Demo Org`
    - Verify `IT_Support` project is created
- OIDC Authentication Method:
    - Go to "Demo Org"
    - Click "Auth Methods" in the left panel
    - Verify "OIDC Authentication" method is created
    - Click "OIDC Authentication"
        - Verify "Issuer", "Client ID", "API URL Prefix" and "Callback URL" details 
    - Click "Managed Groups"
        - Verify `db_admin` and `db_analyst` managed groups are created
        - Click `db_admin` or `db_analyst` managed group and verify the "Filter" field. 
- Roles:
    - Go to `demo-org`
    - Click "Roles" in the left panel
    - Verify `org_anon_listing`, `default_org` and `default_project` roles are created
- Static Credential Store:
    - Go to `demo-org` > `IT_Support` project
    - Click "Credential Stores" in the left panel
    - Verify `boundary_cred_store` record exists
    - Click `boundary_cred_store`
    - Click "Credentials"
    - Verify `static_db_creds` record exists

## Setup Vault Credential Store
```
terraform apply -target module.vault-credstore -auto-approve
```
Verify following resources are created in Vault and Boundary. 
-  Vault:
    - Policies: `boundary-controller`, `kv-read`, `db-read`
    - Token with permissions to access Vault paths as per above policies
- Boundary:
    - Credential store: `vault-cred-store`

## Setup Database Target (AWS RDS Postgres)
```
terraform apply -target module.db-target -auto-approve
```
This step should setup and configure below resources:
- AWS RDS Instance in private subnet
- Vault
    - DB Secret Engine
    - DB Connection and Roles (admin, analyst) for dynamic database credentials
- Boundary
    - Host-Catalog: `db_servers`
    - Host-set: `rds_postgres_set`
    - Host: `rds_postgres_1`
    - Roles (Org level): `db_analyst`, `db_admin` for respective OIDC roles/managed_groups
    - Targets: `postgres_analyst`, `postgres_admin` with vault brokered database credentials

Connect to Database target.
- Login to Boundary as admin or analyst role. Credentials injected to the session would depend on the role you logged in as.
    ```sh
    boundary authenticate oidc -auth-method-id=$OAUTH_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
    You may also use Boundary Desktop to view targets you are authorized to access based on your role.
    - Open Boundary Desktop
    - Enter Boundary Cluster URL. You can retreive the URL by running `terraform output -raw hcp_boundary_cluster_url` command
    - Select `demo-org` from "Choose a different scope" dropdown. 
    - Click "Sign In" to login using your OIDC user credentials.

- Connect to the target
    ```sh
    # If login as admin
    boundary connect postgres -target-name postgres_admin -dbname postgres

    # If login as analyst
    boundary connect postgres -target-name postgres_analyst -dbname postgres
    ```
    Boundary would connect to postgres database with vault brokered dynamic database credentials. Database access permission would be based on the user role.

    ```sh
    # If logged in as admin, verify you are able to insert or delete records in the table
    postgres=> select * from country;
    postgres=> insert into country values ('TH', 'Thailand');
    postgres=> select * from country;

    # If logged in as analyst, verify you are able to only view records in the table
    postgres=> select * from country;
    postgres=> insert into country values ('JP', 'Japan');
    ERROR:  permission denied for table country
    ```



## Setup SSH Target
```
terraform apply -target module.ssh-target -auto-approve
```
This step should setup and configure below resources:
- Linux instance in private subnet
- Vault
    - KV secret engine
    - `backend-sshkey` secret containing username and SSH private key.
- Boundary
    - Host-Catalog: `linux_servers`
    - Host-set: `linux_host_set`
    - Host: `linux_server_1`
    - Roles (Org level): `linux_admin` for respective OIDC roles/managed_groups
    - Targets: `linux_admin`

Connect to Linux target using SSH.
- Login to Boundary as admin role
    ```sh
    boundary authenticate oidc -auth-method-id=$OAUTH_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
- Connect to the target
    ```sh
    boundary connect connect ssh -target-name linux_admin
    ```
    Boundary injects SSH credentials directly to the worker and creates a session to the Linux target without exposing users to the private SSH key.

## Setup RDP Target
```
terraform apply -target module.rdp-target -auto-approve
```
This step should setup and configure below resources:
- Windows instance in private network
- Boundary
    - Host-Catalog: `windows_servers`
    - Host-set: `windows_host_set`
    - Host: `windows_server_1`
    - Roles: `windows_analyst`, `windows_admin` for respective OIDC roles/managed_groups
    - Targets: `windows_admin`, `windows_analyst` with vault brokered database credentials for respective roles

To connect to the target Windows server using RDP, follow below steps: 
- Retrieve windows admin credentials:
    - Go to AWS EC2 and filter by running instances
    - Select b-hackfest-<id>-windows instance
    - Click "Connect" button at the top
    - Click "RDP Client" 
    - Click "Get Password"
    - Copy and paste "./generate/rsa-key" file content in "Private key contents" box
    - Click "Decrypt password"
    - Copy the password
- Create static credential library in Boundary
    - Go to "Demo Org" > "IT Support" project
    - Go to "Credential Stores" > `boundary-cred-store`
    - Click "Credentials"
    - Click "Manage > New Credential"
    - Provide below details and Click "Save"
        - Name: static_windows_creds
        - Type: Username & Password
        - Username: Administrator
        - Password: Paste the password copied in above step
- Assign static credential to Windows targets in Boundary
    - Go to "Demo Org" > "IT Support" project
    - Click "Targets" in the left panel
    - Click `windows_admin` 
    - Click "Brokered Credentials"
    - Click "Manage > Add Brokered Credentials"
    - Select `static_windows_creds` and click "Add Brokered Credentials"
    - Click "Targets" in the left panel
    - Click `windows_analyst` 
    - Click "Brokered Credentials"
    - Click "Manage > Add Brokered Credentials"
    - Select `static_windows_creds` and click "Add Brokered Credentials"
 - Connect to Windows target
    - If using Mac, install "Microsoft Remote Desktop" from the App Store
    - Login to Boundary as admin or analyst role
        ```sh
        boundary authenticate oidc -auth-method-id=$OAUTH_ID
        ```
    - List available targets for the logged in user
        ```sh
        boundary targets list -scope-id $PROJECT_ID
        ```
    - Connect to the target
        ```sh
        boundary connect -exec open -target-name=windows_admin -- rdp://full%20address=s={{boundary.addr}} -W
        ```
        Above command prints two set of credentials:
        - Static username/password to access Windows Server (using Boundary static credential library)
        - Dynamic Database Credentials to access AWS RDS (using Vault credential library) 

## Setup Kubernetes workload Target
```sh
terraform apply -target module.k8s-target -auto-approve
```
This step should setup and configure below resources:
- EKS Cluster
- Self-managed worker running as a pod
- Postres database running as a pod
- Boundary
    - Host-Catalog: `eks_db_servers`
    - Host-set: `eks_postgres_set`
    - Host: `eks_postgres_1`
    - Roles: `eks_db_admin`
    - Targets: `eks_postgres_admin` with static credentials brokered by boundary static credential library

Connect to Database target running as Kubernetes pod.
- Login to Boundary as admin.
    ```sh
    boundary authenticate oidc -auth-method-id=$OAUTH_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
- Connect to the target
    ```sh
    boundary connect postgres -target-name eks_postgres_admin -dbname postgres
    ```
    Boundary would connect to postgres database with static database credentials brokered by Boundary credential store.