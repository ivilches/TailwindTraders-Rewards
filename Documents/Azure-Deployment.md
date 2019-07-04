# Tailwind Traders Rewards Azure Resources Deployment

To run Tailwind Traders Rewards you need to create the Azure infrastructure. There are two ways to do it. Using Azure portal or using a Powershell script.

## Creating infrastructure using Azure Portal

An ARM script is provided that can be deployed just clicking following button:

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FTailwindTraders-Rewards%2Fmaster%2FDeploy%2Fdeployment.json"><img src="./Images/deploy-to-azure.png" alt="Deploy to Azure"/></a>

Azure portal will ask you for the following parameters:

* `servicePrincipalId`: Id of the service principal used to create the AKS
* `servicePrincipalSecret`: Password of the service principal
* `sqlServerAdministratorLogin`: Name of the user for the databases
* `sqlServerAdministratorLoginPassword`: Password for the user of the databases
* `aksVersion`: AKS version to use.

The deployment could take more than 10 minutes, and once finished all needed resources will be created.

## Create the resources using the CLI

You can use the CLI to deploy the ARM script. Open a Powershell window from the `/Deploy` folder and run the `Deploy-Arm-Azure.ps1` with following parameters:

* `-resourceGroup`: Name of the resource group
* `-location`: Location of the resource group

You can optionally pass two additional parameters:

* `-clientId`: Id of the service principal uesd to create the AKS
* `-password`: Password of the service principal 

If these two parameters are not passed a new service principal will be created.

There are three additional optional parameters to control some aspects of what is created:

* `-dbAdmin`: Name of the user of all databases. Defaults to `ttadmin`
* `-dbPassword`: Password of the user of all databases. Defaults to `Passw0rd1!`
* `-deployAks`: If set to `$false` AKS and ACR are not created. This is useful if you want to create the AKS yourself or use an existing AKS. Defaults to `$true`. If this parameter is `$true` the resource group can't exist (AKS must be deployed in a new resource group).

Once script finishes, everything is installed. If a service principal has been created, the script will output the service principal details - _please, take note of the appId and password properties for use them in the AKS deployment_ 

## Install the Tailwind Traders Rewards on the AKS

Now you are ready to install the backend on the AKS. Please follow the [guideline on how to do it](./DeploymentGuide.md).