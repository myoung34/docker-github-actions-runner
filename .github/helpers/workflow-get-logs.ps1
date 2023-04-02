param(
    [Parameter (Mandatory = $true)]
    [Alias ("Actor")]
    [string]$Owner,

    [Parameter (Mandatory = $true)]
    [Alias ("Repo")]
    [string]$Repository,

    [Parameter (Mandatory = $true)]
    [Alias ("Name")]
    [string]$WorkflowName
)
########################################
Set-StrictMode -Version 3.0            #
$ErrorActionPreference = "Stop"        #
########################################
$ConstApiMime = "Accept: application/vnd.github+json"
$ConstApiVersion = "X-GitHub-Api-Version: 2022-11-28"

$Repos = ('/repos/{0}/{1}' -f $Owner, $Repository)
$ListWorkflow = @((gh api -H $ConstApiMime -H $ConstApiVersion "$( $Repos )/actions/workflows" | ConvertFrom-Json).workflows)
Write-Host ('Selected {0} workflows' -f $ListWorkflow.Length)
$SelectedWorkflow = $ListWorkflow  | Where-Object name -ilike $WorkflowName

if ($null -eq $SelectedWorkflow)
{
    Write-Host 'Invalid name' -ForegroundColor Red
    exit 1
}

Write-Host ('Found {0} in path {1}' -f $SelectedWorkflow.id, $SelectedWorkflow.path) -ForegroundColor Green

# Get runs
$Runs = ((gh api -H $ConstApiMime -H $ConstApiVersion `
            "$( $Repos )/actions/workflows/$( $SelectedWorkflow.id )/runs") | ConvertFrom-Json).workflow_runs `
            | Where-Object conclusion -eq 'success' | Sort-Object -Property created_at
#$Runs
$Run = $Runs[0]
$Path = Join-Path -Path (Get-Location) -ChildPath "$($Run.id)_$($Run.run_attempt).log"

(gh run view --log $Run.id -R "$($Owner)/$($Repository)" ) | Out-File -FilePath $Path -Force
