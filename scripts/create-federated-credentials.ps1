param(
    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [Parameter(Mandatory = $true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $true)]
    [string]$RepoName
)

$environments = @("dev", "prod")

foreach ($env in $environments) {
    $credential = @{
        name      = "github-actions-$env"
        issuer    = "https://token.actions.githubusercontent.com"
        subject   = "repo:$GitHubOrg/$RepoName`:environment:$env"
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Depth 5

    $tempFile = New-TemporaryFile
    Set-Content -Path $tempFile -Value $credential -Encoding utf8

    Write-Host "Creating federated credential for $env..."

    az ad app federated-credential create `
        --id $AppId `
        --parameters "@$tempFile"

    Remove-Item $tempFile
}