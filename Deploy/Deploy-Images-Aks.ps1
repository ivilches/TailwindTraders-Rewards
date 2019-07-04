Param(
    [parameter(Mandatory=$false)][string]$name = "my-tt-rewards",
    [parameter(Mandatory=$false)][string]$aksName,
    [parameter(Mandatory=$false)][string]$resourceGroup,
    [parameter(Mandatory=$false)][string]$acrName,
    [parameter(Mandatory=$false)][string]$tag="latest",
    [parameter(Mandatory=$false)][string]$charts = "*",
    [parameter(Mandatory=$false)][string]$valuesFile = "",
    [parameter(Mandatory=$false)][string][ValidateSet('prod','staging','none', IgnoreCase=$false)]$tlsEnv = "none",
    [parameter(Mandatory=$false)][bool]$useInfraInAks=$false
)

function validate {
    $valid = $true

    if ([string]::IsNullOrEmpty($aksName)) {
        Write-Host "No AKS name. Use -aksName to specify name" -ForegroundColor Red
        $valid=$false
    }
    if ([string]::IsNullOrEmpty($resourceGroup))  {
        Write-Host "No resource group. Use -resourceGroup to specify resource group." -ForegroundColor Red
        $valid=$false
    }

    if ([string]::IsNullOrEmpty($aksHost))  {
        Write-Host "AKS host of HttpRouting can't be found. Are you using right AKS ($aksName) and RG ($resourceGroup)?" -ForegroundColor Red
        $valid=$false
    }     
    if ([string]::IsNullOrEmpty($acrLogin))  {
        Write-Host "ACR login server can't be found. Are you using right ACR ($acrName) and RG ($resourceGroup)?" -ForegroundColor Red
        $valid=$false
    }

    if ($valid -eq $false) {
        exit 1
    }
}

function createHelmCommand([string]$command) {
    $tlsSecretName = ""
    if ($tlsEnv -eq "staging") {
        $tlsSecretName = "ttr-letsencrypt-staging"
    }
    if ($tlsEnv -eq "prod") {
        $tlsSecretName = "ttr-letsencrypt-prod"
    }

    $newcmd = $command

    if (-not [string]::IsNullOrEmpty($tlsSecretName)) {
        $newcmd = "$newcmd --set ingress.tls[0].secretName=$tlsSecretName --set ingress.tls[0].hosts={$aksHost}"
    }

    return "$newcmd";
}

Write-Host "--------------------------------------------------------" -ForegroundColor Yellow
Write-Host " Deploying images on cluster $aksName"  -ForegroundColor Yellow
Write-Host " "  -ForegroundColor Yellow
Write-Host " Additional parameters are:"  -ForegroundColor Yellow
Write-Host " Release Name: $name"  -ForegroundColor Yellow
Write-Host " AKS to use: $aksName in RG $resourceGroup and ACR $acrName"  -ForegroundColor Yellow
Write-Host " Images tag: $tag"  -ForegroundColor Yellow
Write-Host " TLS/SSL environment to enable: $tlsEnv"  -ForegroundColor Yellow
Write-Host " --------------------------------------------------------" 

$acrLogin=$(az acr show -n $acrName -g $resourceGroup -o json| ConvertFrom-Json).loginServer
$aksHost=$(az aks show -n $aksName -g $resourceGroup --query addonProfiles.httpapplicationrouting.config.HTTPApplicationRoutingZoneName -o json | ConvertFrom-Json)

if (-not $aksHost) {
    $aksHost=$(az aks show -n $aksName -g $resourceGroup --query addonProfiles.httpApplicationRouting.config.HTTPApplicationRoutingZoneName -o json | ConvertFrom-Json)
}

Write-Host "acr login server is $acrLogin" -ForegroundColor Yellow
Write-Host "aksHost is $aksHost" -ForegroundColor Yellow

validate

Push-Location helm
Write-Host "Deploying charts $charts" -ForegroundColor Yellow

if ($useInfraInAks) {
    Write-Host "charts $charts will be configured to use internal AKS infrastructure." -ForegroundColor Yellow  
    if ([String]::IsNullOrEmpty($valuesFile)) {
        $valuesFile="gvalues_inf.yaml"
    }
}
else {
    if ([String]::IsNullOrEmpty($valuesFile)) {
        $valuesFile="gvalues.yaml"
    }
}

Write-Host "Configuration file used is $valuesFile" -ForegroundColor Yellow

if ($charts.Contains("wr") -or  $charts.Contains("*")) {
    Write-Host "Rewards chart - wr" -ForegroundColor Yellow
    $command = "helm upgrade --install $name-web rewards-web -f $valuesFile
     --set ingress.hosts={$aksHost}
     --set image.repository=$acrLogin/rewards.web
     --set image.tag=$tag
        
    $command = createHelmCommand $command
    cmd /c "$command"
}

if ($charts.Contains("infra")) {
    Write-Host "*** Infrastructure ***" -ForegroundColor Green
    $command = createHelmCommand "helm  upgrade --install $name-infra infrastructure -f $valuesFile --set ingress.hosts={$aksHost}"
    cmd /c "$command"
}

Pop-Location

Write-Host "Tailwind Traders Rewards deployed on AKS" -ForegroundColor Yellow