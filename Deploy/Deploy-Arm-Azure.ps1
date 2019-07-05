Param(
    [parameter(Mandatory=$true)][string]$resourceGroup,
    [parameter(Mandatory=$true)][string]$location,
    [parameter(Mandatory=$false)][string]$clientId,
    [parameter(Mandatory=$false)][string]$password,
    [parameter(Mandatory=$false)][string]$dbAdmin="ttadmin",
    [parameter(Mandatory=$false)][string]$dbPassword="Passw0rd1!",
    [parameter(Mandatory=$false)][string]$winUser="ttradmin",
    [parameter(Mandatory=$false)][string]$winPassword="Passw0rd2!",
    [parameter(Mandatory=$false)][bool]$deployAks=$true
)
$spCreated=$false
$script="./deployment-no-aks.json"
if (-not $deployAks) {
    $script="./deployment-no-aks.json"
}

Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Deploying ARM script $script" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------- " -ForegroundColor Yellow

$rg = $(az group show -n $resourceGroup -o json | ConvertFrom-Json)
if ($deployAks) {
    # Deployment including AKS must be done in a non-existent resource group
    if ($rg) {
        Write-Host "Resource group $resourceGroup already exists. Exiting." -ForegroundColor Red
        exit 1
    }

    if (-not $clientId -or -not $password) {
        Write-Host "Service principal will be created..." -ForegroundColor Yellow
        $sp = $(az ad sp create-for-rbac -o json | ConvertFrom-Json)
        $clientId = $sp.appId
        $password = $sp.password
        $spCreated=$true
    }

    Write-Host "Install required az-cli extension aks-preview" -ForegroundColor Yellow
    az extension add --name aks-preview

    Write-Host "Getting last AKS version in location $location" -ForegroundColor Yellow
    $aksVersions=$(az aks get-versions -l $location --query  orchestrators[].orchestratorVersion -o json | ConvertFrom-Json)
    $aksLastVersion=$aksVersions[$aksVersions.Length-1]

    Write-Host "AKS last version is $aksLastVersion" -ForegroundColor Yellow
    if (-not $aksLastVersion.StartsWith("1.14.0")) {
        Write-Host "AKS 1.14 required. Exiting." -ForegroundColor Red
        exit 1
    }

    Write-Host "Begining the ARM deployment..." -ForegroundColor Yellow
    az group create -n $resourceGroup -l $location
    az group deployment create -g $resourceGroup --template-file $script `
      --parameters sqlServerAdministratorUser=$dbAdmin `
      --parameters sqlServerAdministratorPassword=$dbPassword 
    #   --parameters servicePrincipalId=$clientId `
    #   --parameters servicePrincipalSecret=$password `
    #   --parameters aksVersion=$aksLastVersion

    Write-Host "Creating ARM template..." -ForegroundColor Yellow
    $aksName = "tailwindtradersaks" + [guid]::NewGuid()
    az aks create --resource-group $resourceGroup `
        --name $aksName `
        --node-count 2 `
        --enable-addons monitoring `
        --kubernetes-version $aksLastVersion   `
        --windows-admin-username $winUser  `
        --windows-admin-password $winPassword  `
        --enable-vmss `
        --network-plugin azure  `
        --service-principal $clientId `
        --client-secret $password

    az aks nodepool add --resource-group $resourceGroup `
        --cluster-name $aksName `
        --os-type Windows `
        --name npwin `
        --node-count 2 `
        --kubernetes-version $aksLastVersion
}
else {
    # Deployment without AKS can be done in a existing or non-existing resource group.
    if (-not $rg) {
        Write-Host "Creating resource group $resourceGroup in $location"
        az group create -n $resourceGroup -l $location
    }
    
    Write-Host "Begining the ARM deployment..." -ForegroundColor Yellow
    az group deployment create -g $resourceGroup --template-file $script `
      --parameters sqlServerAdministratorUser=$dbAdmin `
      --parameters sqlServerAdministratorPassword=$dbPassword
}

if ($spCreated) {
    Write-Host "-----------------------------------------" -ForegroundColor Yellow
    Write-Host "Details of the Service Principal Created:" -ForegroundColor Yellow
    Write-Host ($sp | ConvertTo-Json) -ForegroundColor Yellow
    Write-Host "-----------------------------------------" -ForegroundColor Yellow
}

Write-Host "-----------------------------------------" -ForegroundColor Yellow
Write-Host "Db admin: $dbAdmin"
Write-Host "Db Admin Pwd: $dbPassword"
Write-Host "-----------------------------------------" -ForegroundColor Yellow


