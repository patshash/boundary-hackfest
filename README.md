## Pre-Requisites
- HCP Account
- AWS Account
- [HCP service principal credentials](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/guides/auth)
- [Auth0 Account](https://auth0.com/signup)
- [Auth0 Machine-Machine client application](https://registry.terraform.io/providers/auth0/auth0/latest/docs/guides/quickstart)
- [Okta Account](https://developer.okta.com/signup/)
- [Okta API Token](https://developer.okta.com/docs/guides/create-an-api-token/main/)
- [Boundary CLI](https://developer.hashicorp.com/boundary/tutorials/hcp-getting-started/hcp-getting-started-install?in=boundary%2Fhcp-getting-started) v0.12.0
- [Boundary Desktop (Optional)](https://developer.hashicorp.com/boundary/tutorials/hcp-getting-started/hcp-getting-started-desktop-app)
- Microsoft Remote Desktop
- jq (command line JSON processor)

Note: The build instructions and the Github repo have been updated for HCP Boundary 0.12 version with the below changes.

1. Updated packer configuration to build AMI with Boundary 0.12 version.
2. Added “Okta” as an additional OIDC identity provider.
3. Moved the self-managed Vault server to private subnet. Configured HCP Boundary to connect to the private Vault through self-managed ingress worker. 
4. Configured multi-hop sessions to establish connections to targets in the private subnet. This eliminates the need to expose workers on private networks directly to clients. 
5. Credential injection using Vault SSH signed certificates.  The demo environment is now configured to inject single-use SSH certificates generated by Vault to connect to the SSH targets.


# Initial Setup
## Setup .envrc file with Variables.  Please treat these as secrets!
Once creds are created as per prerequisites, we need to make them available to Terraform as below.  It uses direnv if you have it installed.

```sh
vi .envrc
export TF_VAR_hcp_client_id=<hcp_client_id>
export TF_VAR_hcp_client_secret=<hcp_client_secret>
export TF_VAR_auth0_domain=<auth0_domain>
export TF_VAR_auth0_client_id=<auth0_client_id>
export TF_VAR_auth0_client_secret=<auth0_client_secret>
export TF_VAR_okta_org_name=<okta_org_name>
export TF_VAR_okta_base_url=okta.com
export TF_VAR_okta_api_token=<okta_api_token>
export TF_VAR_okta_domain=<okta_org_name>.okta.com
export TF_VAR_hcp_boundary_admin=<hcp_boundary_username>
export TF_VAR_hcp_boundary_password=<hcp_boundary_password> #Password for boundary admin user.
export TF_VAR_user_password=<auth0_user_password> #password for auth0 user access
export TF_VAR_rds_username=<rds_username>
export TF_VAR_rds_password=<rds_password>
```
Please ensure the passwords set in above environment variables follow below rules:

- **Password Length:** Minimum 10 characters.
- **Password Complexity:** Password should contain a combination of upper-case and lower-case letters, numbers, and special characters.

## Clone this repo to your local machine
```sh
git clone https://github.com/panchal-ravi/boundary-hackfest.git
cd <cloned-directory>
```

## Build HCP Boundary self-managed worker image using packer
```sh
cd amis/boundary
# Verify region is set correctly in variables.pkrvars.hcl file
packer build -var-file="variables.pkrvars.hcl" .
```

## Setup HCP Boundary Cluster
```sh
./setup.sh
terraform init -upgrade
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
- Okta resources:
    - Login to Okta
    - Click “Applications > Applications” in the left panel. “Boundary OIDC Test App” client application should be created. Click on the application name link and go to “Sign On” tab. Verify the “Groups claim filter” settings under “OpenID Connect Token” section is set to match groups regex.
    - Click “Directory > Groups” in the left panel. Two groups `admin` and `analyst` should be created
    - Click "Directory > People" in the left panel. Two users `admin` and `analyst` should be create
- Vault:
    - Self-managed Vault instance in the private subnet should be up and running. The vault instance should not be accessible over the public internet.
    - Run `terraform output -raw vault_ip` to view the Vault private IP address.
    - Vault root token should be available in `./generated/vault-token` file

- Two self managed workers for multi-hop sessions: 
    - Self-managed ingress worker (Upstream worker):
        - This worker should have public IP address assigned and is used as the first hop in multi-hop session. This worker does not access to the remote targets.
        - Verify the self-managed ingress boundary worker has started and registered successfully
        - Verify ingress worker status
        ```sh
        # Verify boundary-worker system service is started and active
        ssh -i ./generated/ssh_key ubuntu@$(terraform output -raw ingress_worker_ip) "systemctl status boundary-worker"

        # Verify there are no errors reported in the journal logs. The logs should have "worker has successfully authenticated" message.
        ssh -i ./generated/ssh_key ubuntu@$(terraform output -raw ingress_worker_ip) "journalctl -u boundary-worker"
        ```
        - There should be no errors reported in the journal logs
    - Self-managed egress worker (Downstream worker):
        - This worker should only have private IP address assigned and is used as the second hop in multi-hop session. This worker should have access to the remote targets in private subnet.
        - Verify the self-managed egress boundary worker has started and registered successfully
        - Verify egress worker status
        ```sh
        # Verify boundary-worker system service is started and active
        ssh -i ./generated/ssh_key ubuntu@$(terraform output -raw ingress_worker_ip) "ssh -o 'StrictHostKeyChecking=no' -i ~/ssh_key ubuntu@$(terraform output -raw egress_worker_ip) 'systemctl status boundary-worker'"

        # Verify there are no errors reported in the journal logs. The logs should have "worker has successfully authenticated" message.
        ssh -i ./generated/ssh_key ubuntu@$(terraform output -raw ingress_worker_ip)
        ```
        - There should be no errors reported in the journal logs
    - Verify the worker relationships is setup correctly. Notice the “Directly connected downstream workers” field value in the below output. The worker with the public IP address is the ingress (upstream) worker and the one with the private IP address is the egress (downstream) worker.
    ```
    > boundary workers list -scope-id=global -filter '"/item/type" == "pki"'

    Worker information:
    ID:                        w_XVoRFhVgAU
        Type:                    pki
        Version:                 1
        Address:                 10.200.21.205:9202
        ReleaseVersion:          Boundary v0.12.0+hcp
        Last Status Time:        Tue, 21 Feb 2023 09:15:12 UTC

    ID:                        w_gwBz0eBliW
        Type:                    pki
        Version:                 1
        Address:                 54.255.228.122:9202
        ReleaseVersion:          Boundary v0.12.0+hcp
        Last Status Time:        Tue, 21 Feb 2023 09:15:12 UTC
        Directly Connected Downstream Workers:
        w_XVoRFhVgAU
    ```

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
    - Verify two authentication methods of type “OIDC” are created
    - Click "Okta" OIDC auth method. This should be set as primary authentication method.
        - Verify "Issuer", "Client ID", "API URL Prefix", “Claims Scopes” and "Callback URL" details
    - Click "Managed Groups" for “Okta” OIDC auth method.
        - Verify `okta_db_admin` and `okta_db_analyst` managed groups are created
        - Click `okta_db_admin` or `okta_db_analyst` managed group and verify the "Filter" field.
    - Click "Auth0" OIDC auth method. 
        - Verify "Issuer", "Client ID", "API URL Prefix", “Claims Scopes” and "Callback URL" details
        - Click "Managed Groups" for “Auth0” OIDC auth method.
        - Verify `auth0_db_admin` and `auth0_db_analyst` managed groups are created
        - Click `auth0_db_admin` or `auth0_db_analyst` managed group and verify the "Filter" field.
- Roles:
    - Go to `demo-org`
    - Click "Roles" in the left panel
    - Verify `org_anon` and `default_project` roles are created
    - Go to `Global` scope from the top drop-down
    - Click “Roles” in the left panel
    - Verify `default_org`  role is created
- Static Credential Store:
    - Go to `demo-org` > `IT_Support` project
    - Click "Credential Stores" in the left panel
    - Verify `boundary_cred_store` record exists
    - Click `boundary_cred_store`
    - Click "Credentials"
    - Verify `static_db_creds` record exists
- Boundary Target:

    - This demo environment sets up Vault in the private network. A boundary target is configured to configure Vault resources using terraform and also to access Vault using UI/CLI for troubleshooting.  
    - Go to `demo-org > IT_Support` project
    - Click "Targets" in the left panel
    - Verify vault_enterpise target exists
    - Click `vault_enterprise`
    - Verify the “Target Address” field is set to the Vault private IP address. Starting with 0.12 users can specify the hostname/IP address directly within the target definition, negating the need to create hosts, host sets, or host catalogs.

## Add below variable to .envrc
```sh
export BOUNDARY_ADDR=$(terraform output -raw hcp_boundary_cluster_url)
export AUTH_ID=$(boundary auth-methods list -format json | jq ".items[].id" -r)
export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=$TF_VAR_hcp_boundary_password
boundary authenticate password -auth-method-id=$AUTH_ID -login-name=admin -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD
export ORG_ID=$(boundary scopes list -recursive -format json | jq '.items[] | select(.scope.type=="global") | .id' -r)
export PROJECT_ID=$(boundary scopes list -recursive -format json | jq '.items[] | select(.scope.type=="org") | .id' -r)
export OAUTH_ID=$(boundary auth-methods list -scope-id=$ORG_ID -format json | jq ".items[].id" -r)
export BOUNDARY_CONNECT_TARGET_SCOPE_ID=$PROJECT_ID
```

## Setup Vault Credential Store
This step configures Vault resources such as Vault policies and token using terraform. Since Vault is configured to run in the private network, we will start a local proxy using boundary connect that would tunnel connection to Vault.

```
# Make sure you are authenticated to Boundary using admin credentials
boundary connect -target-name vault_enterprise -listen-port 8200
```
Next, apply terraform.

```
terraform apply -target module.vault-credstore -auto-approve
```
Verify following resources are created in Vault and Boundary. To access Vault, open “http://localhost:8200” in the browser. The token to login to Vault can be found in `./generated/vault_token` file.

-  Vault:
    - Policies: `boundary-controller`, `kv-read`, `db-read`, `boundary-client` and `k8s-roles`
    - Token with permissions to access Vault paths as per above policies
- Boundary:
    - Credential store: `vault-cred-store`
    - Verify the credential store address is set to the Vault private IP.
    - Verify the worker filter is set to use self-managed ingress worker to connect to Vault

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
    - Targets: `postgres_analyst`, `postgres_admin` with vault brokered database credentials. Verify settings for the ingress and egress worker filter fields for the respective targets. This is used to establish multi-hop session to the remote target in the private network.
    - Vault credential libraries: `vault-db-admin` and `vault-db-analyst`

Connect to Database target.
- Login to Boundary as admin or analyst role. Credentials injected to the session would depend on the role you logged in as.
    ```sh
    boundary authenticate oidc -scope-id $ORG_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
    You may also use Boundary Desktop to view targets you are authorized to access based on your role.
    - Open Boundary Desktop
    - Enter Boundary Cluster URL. You can retreive the URL by running below  command
        ```
        terraform output -raw hcp_boundary_cluster_url
        ```
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
    - SSH secret engine ssh-client-signer
        - A role `boundary-client` should be created. This is used to generate dynamic SSH client certificates signed by the issuing CA certificate configured with this secrets engine.
- Boundary
    - Host-Catalog: `linux_servers`
    - Host-set: `linux_host_set`
    - Host: `linux_server_1`
    - Roles (Org level): `linux_admin` for respective OIDC roles/managed_groups
    - Targets: `linux_admin`. Verify settings for the ingress and egress worker filter fields. This is used to establish multi-hop session to the remote target in the private network.
    - Vault credential libraries: `vault-ssh-client-cert` and `vault-ssh-key`. The `vault-ssh-client-cert` is used to inject dynamic SSH client certificates while connecting to the remote SSH based hosts.

Connect to Linux target using SSH.
- Login to Boundary as admin role
    ```sh
    boundary authenticate oidc -scope-id $ORG_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
- Connect to the target
    ```sh
    boundary connect ssh -target-name linux_admin
    ```
    Boundary injects SSH client credentials directly to the worker and creates a session to the Linux target without exposing users to the SSH client certificate and key.

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
    - Targets: `windows_admin`, `windows_analyst`. Each target is configured with
        - Dynamic database credentials, setup as credentials library under Vault credentials store
        - Static windows credentials, setup as static credentials library under Boundary static credentials
    - Vault credential libraries: `vault-db-admin`, `vault-db-analyst `
    - Boundary static credential libraries:  `static_windows_creds`

 - Connect to Windows target
    - If using Mac, install "Microsoft Remote Desktop" from the App Store
    - Login to Boundary as admin or analyst role
        ```sh
        boundary authenticate oidc -scope-id $ORG_ID
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
- Postgres database running as a pod
- Vault
    - Kubernetes Secret Engine
    - Kubernetes role to generate dynamic short-lived service account token with read only permission for "test" namespace
- Boundary
    - EKS Cluster as Target
        - Host-Catalog: `eks_cluster`
        - Host-set: `eks_cluster_set`
        - Host: `eks_cluster_1`
        - Roles: `eks_readonly`
        - Targets: `eks_readonly` with dynamic service account credentials brokered by boundary vault credential library
    - Postgres DB as Target
        - Host-Catalog: `eks_db_servers`
        - Host-set: `eks_postgres_set`
        - Host: `eks_postgres_1`
        - Roles: `eks_db_admin`
        - Targets: `eks_postgres_admin` with static credentials brokered by boundary static credential library
    - Vault Credential Library: `eks_token_readonly`

### Connect to Database target running as Kubernetes pod.
- Login to Boundary as admin.
    ```sh
    boundary authenticate oidc -scope-id $ORG_ID
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


### Connect to EKS Cluster target
- Login to Boundary as analyst.
    ```sh
    boundary authenticate oidc -auth-method-id=$OAUTH_ID
    ```
- List available targets for the logged in user
    ```sh
    boundary targets list -scope-id $PROJECT_ID
    ```
- Connect to EKS cluster 
    ```sh
    boundary connect -target-name=eks_readonly 
    ```
    Above command does below:
    - Creates an encrypted tunnel from the local client machine to a boundary worker which then proxies connection to the EKS cluster.
    - Prints the address (127.0.0.1) and port number (random number) the proxy listens on
    - Prints the dynamic kubernetes service account token generated by Vault

    To run `kubectl` commands, set below command line options:
    - --server=https://127.0.0.1:<random_proxy_port_number> 
    - --token=<dynamic_service_account_token>
    - --certificate-authority=<path_to_eks_ca_cert>
    - --tls-server-name=kubernetes

    Full command to list pods in `test` namespace would be as below:
    ```sh
    kubectl get pods -n test --server=https://127.0.0.1:<random_proxy_port_number> --token <dynamic_service_account_token> --certificate-authority <path_to_eks_ca_cert> --tls-server-name=kubernetes
    ```

    Below is the helper utility to simplify running kubectl commands without providing options every time.

    ```sh
    boundary connect -target-name=eks_readonly -format json | jq -r '"export SERVER=https://"+.address+":"+(.port|tostring),"export TOKEN="+(.credentials[].secret.decoded.service_account_token)'

    # Run export commands from the above output 
    # Next set alias as below
    alias kb="kubectl --server $SERVER --token $TOKEN --certificate-authority <path_to_eks_ca_cert> --tls-server-name kubernetes"

    # Now run kubectl commands using kb
    kb get pods -n test
    ```
    User with analyst role should have permission to list and read kubernetes pods, services and deployments. However, the users should not have persmissions to list secrets or create any resources.  

    ```sh
    # Below command should be allowed
    kb get services -n test

    # Below command should show permissions error
    kb -n test create deploy nginx --image=nginx

    # User is not allowed to list secrets and should also result in permissions error
    kb -n test get secrets
    ```
    