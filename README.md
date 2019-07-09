# Tailwind Traders Rewards Reference App

![Tailwind Traders Rewards](Documents/Images/Rewards.png)

You can take a look at our live running website following this address: [https://rewards.tailwindtraders.com](https://rewards.tailwindtraders.com) 

[![Build status](https://dev.azure.com/TailwindTraders/Rewards/_apis/build/status/Rewards-CI)](https://dev.azure.com/TailwindTraders/Rewards/_build/latest?definitionId=28)

# Deploy to Azure

There are two scenarios to deploy this project into Azure:
1. **Scenario 1:** As a standalone PaaS in Azure. Adding the rewards web as an application service.
2. **Scenario 2:** As part of the TailwindTraders-Backend project (as services inside an AKS equal or newer than 1.14). Adding the rewards web as a Windows container inside AKS.

## Scenario 1
For the first scenario you have to deploy the ARM templates from following links:

- [Deploy common services](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment-base.json)
- [Deploy SQL Server service](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment-sql.json) 
- [Deploy Application service](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment-web.json)

>**Note** Remember to put the same SQL Server Username / Password on all ARM templates

Steps to publish website to Azure:
1. Open the `TailwindTraders.Rewards.Website.sln` solution.
1. Right click the website project.
1. Select the `Publish...` option.
1. Pick an `App Service` publish target with the `Select Existing` option.
1. Choose the already created Application Service from your resource group.
1. Select `Create`. This will create the publish profile
1. Select `Publish`. This will build and publish the rewards website to Azure.

Do the same for the Azure Function in the `TailwindTraders.Rewards.Function.sln` solution.

## Scenario 2
Create the infrastructure needed for TailwindTraders-Rewards without deploying the Rewards website as application service:
- [Deploy common services](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment-base.json)
- [Deploy SQL Server service](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment-sql.json) 

Requirement: Deploy the whole TailwindTraders-Backend to AKS following the instructions from [Deployment Guide](https://github.com/microsoft/TailwindTraders-Backend/blob/master/Documents/DeploymentGuide.md).

### Configuring services

Before deploying services using Helm, you need to setup the configuration. We refer to the configuration file with the name of *gvalues* file. This file **contains all secrets and connection strings** so beware to not commit in your repo accidentally.

An example of this file is in `helm/gvalues.yaml`. The deployment scripts use this file by default, **but do not rely on editing this file**. Instead create a copy of it a folder outside the repository and use the `-valuesFile` parameter of the deployment script.

>**Note:** The folder `/Deploy/helm/__values/` is added to `.gitignore`, so you can keep all your configuration files in it, to avoid accidental pushes.

Please refer to the comments of the file for its usage. Just ignore (but not delete) the `tls` section (it is used if TLS is enabled).

### Auto generating the configuration file

Generating a valid _gvalues_ file can be a bit harder, so there is a Powershell script that can do all work by you. This script assumes that all resources are deployed in the same resource group, and this resource group contains only the Tailwind Traders Rewards resources. Also assumes the Azure resources have been created using the tools provided in this repo.

To auto-generate your _gvalues_ file just go to `/Deploy` folder and from a Powershell window, type the following:

```
.\Generate-Config.ps1 -resourceGroup <your-resource-group> -sqlPwd <sql-password> -outputFile helm\__values\<name-of-your-file>
```

The parameters that `Generate-Config.ps1` accepts are:

* `-resourceGroup`: Resource group where all Azure resources are. **Mandatory**
* `-sqlPwd`: Password of SQL Servers server. This parameter is **mandatory** because can't be read using Azure CLI
* `-forcePwd`: If `$true`, the scripts updates the SQL Server to set their password to the value of `sqlPwd`. Defaults to `$false`.
* `-outputFile`: Full path of the output file to generate. A good idea is to generate a file in `/Deploy/helm/__values/` folder as this folder is ignored by Git. If not passed the result file is written on screen.
* `-gvaluesTemplate`: Template of the _gvalues_ file to use. The parameter defaults to the `/Deploy/helm/gvalues.template` which is the only template provided.

The script checks that all needed resources exists in the resource group. If some resource is missing or there is an unexpected resource, the script exits.

### Publish the project

To publish the Web project, follow these instructions:
1. Open Visual Studio as Administrator.
2. Open the TailwindTraders.Rewards.Website solution.
3. Right click in the TailwindTraders.Rewards.Website project and click in `Publish...`. This publish will generate the neccessary files to run the project with docker. In this case, we have a .pubxml configuration file to publish the artifacts inside the path defined in the Dockerfile (`obj/Docker/publish`)

### Build & deploy images to ACR

>**Note** Before you proceed, switch to windows containers in the Docker Desktop right click menu.

You can **manually use docker-compose** to build and push the images to the ACR. If using compose you can set following environment variables:

* `TAG`: Will contain the generated docker images tag
* `REGISTRY`: Registry to use. This variable should be set to the login server of the ACR

Once set, you can use `docker-compose build` and `docker-compose push` to build and push the images.

Additionaly there is a Powershell script in the `Deploy` folder, named `Build-Push.ps1`. You can use this script for building and pushing ALL images to ACR. Parameters of this script are:

* `resourceGroup`: Resource group where ACR is. **Mandatory**.
* `acrName`: ACR name (not login server). **Mandatory**.
* `dockerTag`: Tag to use for generated images (defaults to `latest`)
* `dockerBuild`: If `$true` (default value) docker images will be built using `docker-compose build`.
* `dockerPush`: If `$true` (default value) docker images will be push to ACR using `docker-compose push`.

This script uses `az` CLI to get ACR information, and then uses `docker-compose` to build and push the images to ACR.

To build an push images tagged with v1 to a ACR named my-acr in resource group named my-rg (located in the `Deploy` folder):

```
.\Build-Push.ps1 -resourceGroup my-rg -dockerTag v1 -acrName my-acr
```

To just push the images (without building them before):

```
.\Build-Push.ps1 -resourceGroup my-rg -dockerTag v1 -acrName my-acr -dockerBuild $false
```

### Deploying services

If using Powershell, have to run `./Deploy-Images-Aks.ps1` with following parameters:

* `-name <name>` Name of the deployment. Defaults to  `my-tt`
* `-aksName <name>` Name of the AKS
* `-resourceGroup <group>` Name of the resource group
* `-acrName <name>` Name of the ACR
* `-tag <tag>` Docker images tag to use. Defaults to  `latest`
* `-charts <charts>` List of comma-separated values with charts to install. Defaults to `*` (all)
* `-valueSFile <values-file>`: Values file to use (defaults to `gvalues.yaml`)
* `-namespace`: Containers namespace (defaults to empty which means the one in .kube/config)
* `-tlsEnv prod|staging` If **SSL/TLS support has been installed**, you have to use this parameter to enable https endpoints. Value must be `staging` or `prod` and must be the same value used when you installed SSL/TLS support. If SSL/TLS is not installed, you can omit this parameter.

## Data initial migration and seeding
Previously to launch for first time the application you must create a Database in SQL Server named `rewardsdb` and execute the sql script `Source\SQLScripts\CreateTablesAndPopulate.sql`, in order to create the needed tables and seeding with the required data.

# Demo Script

You can find a [demo script](https://github.com/Microsoft/TailwindTraders/tree/master/Documents/DemoScripts/Modernizing%20.NET%20Apps#modernizing-net-apps) with the walkthroughs once you have deployed the Azure resources and cloned the source code of this repository.

# Repositories

For this demo reference, we built several consumer and line-of-business applications and a set of backend services. You can find all repositories in the following locations:

* [Tailwind Traders](https://github.com/Microsoft/TailwindTraders)
* [Backend (AKS)](https://github.com/Microsoft/TailwindTraders-Backend)
* [Website (ASP.NET & React)](https://github.com/Microsoft/TailwindTraders-Website)
* [Desktop (WinForms & WPF -.NET Core)](https://github.com/Microsoft/TailwindTraders-Desktop)
* [Rewards (ASP.NET Framework)](https://github.com/Microsoft/TailwindTraders-Rewards)
* [Mobile (Xamarin Forms 4.0)](https://github.com/Microsoft/TailwindTraders-Mobile)

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
