param(
    # ex.:https://github.com/cli/cli/releases or https://github.com/cli/cli/releases/latest
    [Parameter (Mandatory = $true)]
    [Alias ("Uri")]
    [string]$Url,

    # tar.gz, zip
    [Parameter (Mandatory = $true)]
    [Alias ("Extension")]
    [string]$FileType,

    # ex.: amd64,arm64
    [Parameter ()]
    [Alias ("Arch")]
    [string[]]$Platforms,

    [Parameter ()]
    [Alias ("OutputFormat")]
    [PSDefaultValue (Value = $true)]
    [switch]$ForActions,

    # if we set platforms like amd64,arm64 we need to set here x64,arm64
    [Parameter ()]
    [Alias ("Alternative")]
    [string[]]$AnotherName,

    # linux,windows
    [Parameter ()]
    [PSDefaultValue (Value = 'linux')]
    [Alias ("TargetOs")]
    [string]$Os,

    [Parameter ()]
    [Alias ("IsDebug")]
    [PSDefaultValue (Value)]
    [switch]$DebugMessages
)
# test data:
# ./get-latest-release.ps1 https://github.com/actions/runner/releases 'tar.gz' -Platforms amd64,arm64 -Alternative x64,arm64
# ./get-latest-release.ps1 https://github.com/cli/cli/releases 'tar.gz' -Platforms amd64,arm64 -ForActions -IsDebug
########################################
Set-StrictMode -Version 3.0            #
$ErrorActionPreference = "Stop"        #
########################################

$ConstApiMime = "Accept: application/vnd.github+json"
$ConstApiVersion = "X-GitHub-Api-Version: 2022-11-28"

if ( [string]::IsNullOrWhiteSpace($Os)) {
    $Os = 'linux'
}
else {
    $Os = $Os.ToLowerInvariant()
}


function DebugMessage {
    param(
        [string[]]$Url
    )
    if (! $DebugMessages) {
        return
    }

    Write-Host ($Url -join ', ') -ForegroundColor Blue
}

function ErrorMessage {
    param(
        [string[]]$Url
    )

    Write-Host ($Url -join ', ') -ForegroundColor Red
}

$ApiUrl = $Url -replace '^https\:\/\/github\.com\/([^\/]+)\/([^\/]+).*', '/repos/$1/$2'

DebugMessage $ApiUrl

$Release = (gh api -H $ConstApiMime -H $ConstApiVersion "$( $ApiUrl )/releases/latest" | ConvertFrom-Json)

if (($null -eq $Release) -or ([string]::IsNullOrWhiteSpace($Release.tag_name))) {
    ErrorMessage "Invalid URL: $( $Url )"
    exit 1
}

$LatestReleaseVersion = $Release.tag_name -replace '^\D+(\d+\.\d+\.\d+).*', '$1'
DebugMessage $LatestReleaseVersion
$Like = "*$( $Os )*$( $FileType )"

$DownloadUrls = ($Release.assets | Where-Object browser_download_url -like $Like).browser_download_url
$Output = @{
    LATEST_RELEASE_VERSION = $LatestReleaseVersion
}

if (($null -eq $AnotherName) -or ($AnotherName.Count -eq 0)) {
    foreach ($Platform in $Platforms) {
        $Found = $false

        foreach ($Url in $DownloadUrls) {
            if ($Url -match $Platform) {
                $Found = $true
                $Output.Add($Platform, $Url)
                DebugMessage $Platform, $Url
                break
            }
        }

        if (! $Found) {
            $Output.$Platform = ''
            DebugMessage $Platform, 'NONE!'
        }
    }
}
else {
    [bool]$NotAlpine = $Url.Contains('PowerShell')
    for ($Index = 0; $Index -lt $Platforms.Count; $Index++) {
        $AltPlatform = $AnotherName[$Index]
        DebugMessage 'AnotherNames', $AltPlatform
        $Platform = $Platforms[$Index]

        $Found = $false
        foreach ($Url in $DownloadUrls) {
            # Alpine was added for pwsh
            if ($NotAlpine) {
                if (($Url.Contains('fxdependent')) -or ($Url.Contains('alpine'))) {
                    continue
                }
                if (($Url -match $AltPlatform)) {
                    $Found = $true
                    $Output.Add($Platform, $Url)
                    DebugMessage $Platform, $Url
                    break
                }
            }
            else {
                if (($Url -match $AltPlatform)) {
                    $Found = $true
                    $Output.Add($Platform, $Url)
                    DebugMessage $Platform, $Url
                    break
                }
            }
        }

        if (! $Found) {
            $Output.$Platform = ''
            DebugMessage $Platform
            , 'NONE!'
        }
    }
}


if ($ForActions) {
    $Plain = New-Object -TypeName "System.Text.StringBuilder"
    $Output.GetEnumerator() | ForEach-Object {
        [void]$Plain.Append($_.Key.ToUpperInvariant())
        [void]$Plain.Append('=')
        [void]$Plain.AppendLine($_.Value)
    }
    Write-Output $Plain.ToString()
}
else {
    $Output
}
