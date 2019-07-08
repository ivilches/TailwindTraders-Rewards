# Deploy The Tailwind Traders Reward services on AKS

Pre-requisites for this deployment are to have 

* The AKS and all related resources deployed in Azure
* A terminal with Powershell environment
* [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed.
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed.
* Docker installed.

## Pre-requisite: Azure infrastructure created

Tailwind Traders Rewards requires various Azure resources created. Please follow the [Azure infrastructure deployment guide](./Azure-Deployment.md) if you don't have the resources deployed.

### Service Principal

A Service Principal is needed for creating the AKS. If you use the [CLI to create the resources](./Azure-Deployment.md#create-the-resources-using-the-cli), you can reuse a SP one passing to the script the id and password as optional parameters; if not, the script will create a new one for you and will print the details (id and password among them).

In case you use [Azure Portal for the resources' creation](./Azure-Deployment.md#creating-infrastructure-using-azure-portal), you can also reuse a SP or create manually a new one for passing the credentials to the template.
 
## Connecting kubectl to AKS

From the terminal type:

* `az login` and follow instructions to log into your Azure.
* If you have more than one subscription type `az account list -o table` to list all your Azure subscriptions. Then type  `az account set --subscription <subscription-id>` to select your subscription
* `az aks get-credentials -n <your-aks-name> -g <resource-group-name>` to download the configuration files that `kubectl` needs to connect to your AKS.

At this point if you type `kubectl config current-context` the name of your AKS cluster should be displayed. That means that `kubectl` is ready to use your AKS

## Installing Tiller on AKS

Helm is a tool to deploy resources in a Kubernetes cluster in a clean and simple manner. It is composed of two tools, one client-side (the Helm client) that needs to be installed on your machine, and a server component called _Tiller_ that has to be installed on the Kubernetes cluster.

To install Helm, refer to its [installation page](https://docs.helm.sh/using_helm/#installing-helm). Once Helm is installed, _Tiller_ must be deployed on the cluster. For deploying _Tiller_ run the `Add-Tiller.ps1` (from Powershell).

Once installed, helm commands like `helm ls` should work without any error.

## Configuring services

Before deploying services using Helm, you need to setup the configuration. We refer to the configuration file with the name of _gvalues_ file. This file **contains all secrets and connection strings** so beware to not commit in your repo accidentally.

An example of this file is in `helm/gvalues.yaml`. The deployment scripts use this file by default, **but do not rely on editing this file**. Instead create a copy of it a folder outside the repository and use the `-valuesFile` parameter of the deployment script.

>**Note:** The folder `/Deploy/helm/__values/` is added to `.gitignore`, so you can keep all your configuration files in it, to avoid accidental pushes.

Please refer to the comments of the file for its usage. Just ignore (but not delete) the `tls` section (it is used if TLS is enabled).

### Auto generating the configuration file

Generating a valid _gvalues_ file can be a bit harder, so there is a Powershell script that can do all work by you. This script assumes that all resources are deployed in the same resource group, and this resource group contains only the Tailwind Traders resources. Also assumes the Azure resources have been created using the tools provided in this repo.

To auto-generate your _gvalues_ file just go to `/Deploy` folder and from a Powershell window, type the following:

```
.\Generate-Config.ps1 -resourceGroup <your-resource-group> -sqlPwd <sql-password> -outputFile helm\__values\<name-of-your-file>
```

The parameters that `Generate-Config.ps1` accepts are:

* `-resourceGroup`: Resource group where all Azure resources are. **Mandatory**
* `-sqlPwd`: Password of SQL Servers and PostgreSQL server. This parameter is **mandatory** because can't be read using Azure CLI
* `-forcePwd`: If `$true`, the scripts updates the SQL Server and PostgreSQ to set their password to the value of `sqlPwd`. Defaults to `$false`.
* `-outputFile`: Full path of the output file to generate. A good idea is to generate a file in `/Deploy/helm/__values/` folder as this folder is ignored by Git. If not passed the result file is written on screen.
* `-gvaluesTemplate`: Template of the _gvalues_ file to use. The parameter defaults to the `/Deploy/helm/gvalues.template` which is the only template provided.

The script checks that all needed resources exists in the resource group. If some resource is missing or there is an unexpected resource, the script exits.

## Create secrets on the AKS

Docker images are stored in a ACR (a private Docker Registry hosted in Azure).

Before deploying anything on AKS, a secret must be installed to allow AKS to connect to the ACR through a Kubernetes' service account. 

To do so from a Bash terminal run the file `./create-secret.sh` with following parameters:

* `-g <group>` Resource group where AKS is
* `--acr-name <name>`  Name of the ACR
* `--clientid <id>` Client id of the service principal to use
* `--password <pwd>` Service principal password

Please, note that the Service principal must be already exist. To create a service principal you can run the command `az ad sp create-for-rbac`.

If using Powershell run the `./Create-Secret.ps1` with following parameters:

* `-resourceGroup <group>` Resource group where AKS is
* `-acrName <name>`  Name of the ACR

This will create the secret in AKS **using ACR credentials**. If ACR login is not enabled you can create a secret by using a service principal. For use a Azure service principal following additional parameters are needed:

* `-clientId <id>` Client id of the service principal to use
* `-password <pwd>` Service principal password

Please, note that the Service principal must be already exist. To create a service principal you can run the command `az ad sp create-for-rbac`.

## Build & deploy images to ACR

### Publish the project
 In order wer are using a legacy app, you'll need to publish the Web project previously to execute the following steps of this guide.
To publish the Web project, follow these instructions:
1. Open Visual Studio as Administrator.
2. Open the TailwindTraders.Rewards.Website solution.
3. Right click in the TailwindTraders.Rewards.Website project and click in `Publish...`. This publish will generate the neccessary files to run the project with docker. In this case, we have a .pubxml configuration file to publish the artifacts inside the path defined in the Dockerfile (`obj/Docker/publish`  


You can **manually use docker-compose** to build and push the images to the ACR. If using compose you can set following environment variables:

* `TAG`: Will contain the generated docker images tag
* `REGISTRY`: Registry to use. This variable should be set to the login server of the ACR

Once set, you can use `docker-compose build` and `docker-compose push` to build and push the images.

>**Note:** Remember to switch docker to Windows containers.

Additionaly there is a Powershell script in the `Deploy` folder, named `Build-Push.ps1`. You can use this script for building and pushing ALL images to ACR. Parameters of this script are:

* `resourceGroup`: Resource group where ACR is. Mandatory.
* `acrName`: ACR name (not login server). Mandatory.
* `dockerTag`: Tag to use for generated images (defaults to `latest`)
* `dockerFile`: path to the docker compose file to be used. Defaults to `docker-compose-win.yml`
* `dockerBuild`: If `$true` (default value) docker images will be built using `docker-compose build`.
* `dockerPush`: If `$true` (default value) docker images will be push to ACR using `docker-compose push`.

This script uses `az` CLI to get ACR information, and then uses `docker-compose` to build and push the images to ACR.

To build and push images tagged with v1 to a ACR named my-acr in resource group named my-rg:

```
.\Build-Push.ps1 -resourceGroup my-rg -dockerTag v1 -acrName my-acr
```

To just push the images (without building them before):

```
.\Build-Push.ps1 -resourceGroup my-rg -dockerTag v1 -acrName my-acr -dockerBuild $false
```

## Limit the used resources for the services
You can set the CPU and RAM limit and request consumption values for each one of the services, editing the values in its corresponding `values.yaml`, under the field `resources`:
```yaml
resources:
  limits:
    cpu: "500m"
  requests:
    cpu: "100m"
```

## Deploying services

To deploy the services from a Bash terminal run `./Deploy-Images-Aks.ps1` with following parameters:

* `-name <name>` Name of the deployment. Defaults to  `my-tt-rewards`
* `-aksName <name>` Name of the AKS
* `-resourceGroup <group>` Name of the resource group
* `-acrName <name>` Name of the ACR
* `-tag <tag>` Docker images tag to use. Defaults to  `latest`
* `-charts <charts>` List of comma-separated values with charts to install. Defaults to `*` (all backend services)
* `-valuesFile <values-file>`: Values file to use (defaults to `gvalues.yaml`)
* `-useInfraInAks`: Flag needed to check if infrastructure services will be in AKS or not.

This script will install all services using Helm and your custom configuration from the configuration file set by `-valuesFile` parameter.

The parameter `charts` allow for a selective installation of charts. Is a list of comma-separated values that mandates the services to deploy in the AKS. Values are:

* `wr` Rewards Web

Note that parameter `-useInfrainAKS` won't deploy the infrastructure in the AKS. **This is done by adding `infra` to the `-charts` parameter**. Note that the `infra` chart is only deployed if `-charts` contains the `infra` value. So if you want to deploy all services and the infrastructure must use `-charts="*,infra"` (`*` means "all backend services").

When `infra` value is used, the SQL Server database is deployed inside AKS.