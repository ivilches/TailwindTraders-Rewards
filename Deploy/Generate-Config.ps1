Param (
    [parameter(Mandatory=$true)][string]$resourceGroup,
    [parameter(Mandatory=$true)][string]$sqlPwd,
    [parameter(Mandatory=$false)][string]$outputFile=$null,
    [parameter(Mandatory=$false)][string]$gvaluesTemplate=".\\helm\\gvalues.template",
    [parameter(Mandatory=$false)][bool]$forcePwd=$false
)

function EnsureAndReturnFistItem($arr, $restype) {
    if (-not $arr -or $arr.Length -ne 1) {
        Write-Host "Fatal: No $restype found (or found more than one)" -ForegroundColor Red
        exit 1
    }
    return $arr[0]
}

# Check the rg
$rg=$(az group show -n $resourceGroup -o json | ConvertFrom-Json)

if (-not $rg) {
    Write-Host "Fatal: Resource group not found" -ForegroundColor Red
    exit 1
}

### Getting Resources

$sqlsrv=$(az sql server list -g $resourceGroup --query "[].{administratorLogin:administratorLogin, name:name, fullyQualifiedDomainName: fullyQualifiedDomainName}" -o json | ConvertFrom-Json)
$sqlsrv=EnsureAndReturnFistItem $sqlsrv "SQL Server"
Write-Host "Sql Server: $($sqlsrv.name)" -ForegroundColor Yellow

if ($forcePwd) {
    Write-Host "Reseting password to $sqlPwd for SQL server $($sqlsrv.name)" -ForegroundColor Yellow
    az sql server update -n $sqlsrv.name -g $resourceGroup -p $sqlPwd
}

## Showing Values that will be used

Write-Host "===========================================================" -ForegroundColor Yellow
Write-Host "gvalues file will be generated with values:"

$tokens=@{}
$tokens.dbhost=$sqlsrv.fullyQualifiedDomainName
$tokens.dbuser=$sqlsrv.administratorLogin
$tokens.dbpwd=$sqlPwd

# Standard fixed tokens
$tokens.ingressclass="addon-http-application-routing"
$tokens.secissuer="TTFakeLogin"
$tokens.seckey="nEpLzQJGNSCNL5H6DIQCtTdNxf5VgAGcBbtXLms1YDD01KJBAs0WVawaEjn97uwB"

Write-Host ($tokens | ConvertTo-Json) -ForegroundColor Yellow

Write-Host "===========================================================" -ForegroundColor Yellow

& .\token-replace.ps1 -inputFile $gvaluesTemplate -outputFile $outputFile -tokens $tokens






