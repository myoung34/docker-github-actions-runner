param(
    # ex.:https://nodejs.org/download/release/latest-v16.x
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
    [PSDefaultValue (Value = '16')]
    [Alias ("MajorVersion")]
    [string]$MaxVersion,

    [Parameter ()]
    [Alias ("IsDebug")]
    [PSDefaultValue (Value)]
    [switch]$DebugMessages
)
# test data:
# .\get-node-release.ps1 https://nodejs.org/download/release/latest-v16.x 'tar.gz' -Platforms amd64,arm64 -Alternative x64,arm64
########################################
Set-StrictMode -Version 3.0            #
$ErrorActionPreference = "Stop"        #
########################################

if ( [string]::IsNullOrWhiteSpace($Os)) {
    $Os = 'linux'
}
else {
    $Os = $Os.ToLowerInvariant()
}
if ( [string]::IsNullOrWhiteSpace($MaxVersion)) {
    $MaxVersion = '16'
}
else {
    $MaxVersion = $MaxVersion.ToLowerInvariant()
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
$Like = "*$( $Os )*.$( $FileType )"

$DownloadUrls = (Invoke-WebRequest -Uri $Url `
    | Select-Object -ExpandProperty Links | Where-Object href -like $Like).href
if (($null -eq $DownloadUrls)) {
    ErrorMessage "Invalid URL: $( $Url )"
    exit 1
}

$Output = @{
    LATEST_RELEASE_VERSION = ''
}


$LatestReleaseVersion = ''
$BasePath = $Url
if (!$Url.EndsWith('/')) {
    $BasePath = ('{0}/' -f $Url)
}

if (($null -eq $AnotherName) -or ($AnotherName.Count -eq 0)) {
    foreach ($Platform in $Platforms) {
        $Found = $false

        foreach ($Url in $DownloadUrls) {
            if (($Url -match $Platform) -and ($Url -match $MaxVersion)) {
                $Found = $true
                $Output.Add($Platform, ('{0}{1}' -f $BasePath, $Url))
                DebugMessage $Platform, ('{0}{1}' -f $BasePath, $Url)

                if ( [string]::IsNullOrEmpty($LatestReleaseVersion)) {
                    $LatestReleaseVersion = ($Url -replace '^\D+(\d+\.\d+\.\d+).+', '$1')
                }
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
    for ($Index = 0; $Index -lt $Platforms.Count; $Index++) {
        $AltPlatform = $AnotherName[$Index]
        $Platform = $Platforms[$Index]

        $Found = $false
        foreach ($Url in $DownloadUrls) {
            if (($Url -match $AltPlatform) -and ($Url -match $MaxVersion)) {
                $Found = $true
                $Output.Add($Platform, ('{0}{1}' -f $BasePath, $Url))
                DebugMessage $Platform, ('{0}{1}' -f $BasePath, $Url)

                if ( [string]::IsNullOrEmpty($LatestReleaseVersion)) {
                    $LatestReleaseVersion = ($Url -replace '^\D+(\d+\.\d+\.\d+).+', '$1')
                }
                break
            }
        }

        if (! $Found) {
            $Output.$Platform = ''
            DebugMessage $Platform, 'NONE!'
        }
    }
}

$Output.LATEST_RELEASE_VERSION = $LatestReleaseVersion

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
