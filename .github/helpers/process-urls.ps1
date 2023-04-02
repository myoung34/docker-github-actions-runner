param(
    [Parameter (Mandatory = $true)]
    [string]$UniqueId,

    [Parameter (Mandatory = $true)]
    [string]$JsonFile,

    [Parameter (Mandatory = $true)]
    [string]$OutputPrefix,

    [Parameter (Mandatory = $true)]
    [Alias ("Arch")]
    [string[]]$Platforms,

    [Parameter ()]
    [switch]$IsDebug = $false
)
########################################
Set-StrictMode -Version 3.0            #
$ErrorActionPreference = "Stop"        #
########################################
[string]$ConstApiMime = "Accept: application/vnd.github+json"
[string]$ConstApiVersion = "X-GitHub-Api-Version: 2022-11-28"
function DebugMessage {
    param(
        [string[]]
        $Url
    )
    if (! $IsDebug) {
        return
    }
    $Msg = ('Caller: {0}, Values: {1}' -f $^, ($Url -join ';'))
    Write-Host $Msg -ForegroundColor DarkGray
}
function GetApiUrl {
    param(
        [string] $Url
    )

    if ($Url -match 'github\.com') {
        return [string]($Url -replace '^https\:\/\/github\.com\/([^\/]+)\/([^\/|\.]+).*', '/repos/$1/$2')
    }

    return [string]''
}

function GetReleaseVersion {
    param([string]$Url, [string]$MaxVersion)

    $ApiUrl = GetApiUrl $Url
    $Request = (gh api -H $ConstApiMime -H $ConstApiVersion "$( $ApiUrl )/releases/latest")

    if ($LASTEXITCODE -eq 0) {
        $Tag = ($Request | ConvertFrom-Json).tag_name
        if (($Tag -match '^(\D*)(\d+\.\d+\.\d+)(.*)') -and (![string]::IsNullOrWhiteSpace($Matches[2])) -and (($MaxVersion -eq '') -or ($_ -match $MaxVersion) )) {
            return [version]::Parse($Matches[2])
        }
    }

    return [version]::new()
}

function GetTagsVersion {
    param([string]$Url, [string]$MaxVersion)

    $ApiUrl = GetApiUrl $Url
    $Request = (gh api -H $ConstApiMime -H $ConstApiVersion "$( $ApiUrl )/tags")

    if ($LASTEXITCODE -eq 0) {
        $Tag = (($Request | ConvertFrom-Json).name | ForEach-Object {
                $MatchResult = ($_ -match '^(\D*)(\d+\.\d+\.\d+)(.*)')
                $VersionToParse = $Matches[2]
                if ($MatchResult -and (![string]::IsNullOrWhiteSpace($VersionToParse)) -and (($MaxVersion -eq '') -or ($VersionToParse -match $MaxVersion) )) {
                    [version]::Parse($VersionToParse)
                }
                else {
                    [version]::new()
                }
            } | Sort-Object -Descending | Select-Object -Index 0)
        return [version]($Tag -as [version])
    }
    return [version]::new()
}

function GetNodeVersion {
    param([string]$Url, [string] $MaxVersion)

    $Like = ('*{0}*' -f $MaxVersion)
    $Request = (Invoke-WebRequest -Uri $Url | Select-Object -ExpandProperty Links | Where-Object href -like $Like).href

    if ($LASTEXITCODE -eq 0) {
        $Tag = ($Request | ForEach-Object {
                $MatchResult = ($_ -match '^(\D*)(\d+\.\d+\.\d+)(.*)')
                $VersionToParse = $Matches[2]
                if ($MatchResult -and (![string]::IsNullOrWhiteSpace($VersionToParse)) -and (($MaxVersion -eq '') -or ($VersionToParse -match $MaxVersion) )) {
                    [version]::Parse($VersionToParse)
                }
                else {
                    [version]::new()
                }
            } | Sort-Object -Descending | Select-Object -Index 0)
        return [version]($Tag -as [version])
    }
    return [version]::new()
}


function CleanVar {
    param(
        [string]
        $DurtyString
    )

    return ($DurtyString -replace ('[^a-zA-Z\d_\-\s]', '') -replace '[\s|\-]', '_').ToUpperInvariant()
}
function ChangeNames {
    param(
        [PSCustomObject]$Object,
        [string[]]$Platforms
    )
    $Result = New-Object 'System.Collections.Generic.List[String]'
    foreach ($Arch in $Platforms) {
        if ( $Object.ContainsKey($Arch)) {
            $Result.Add($Object.$Arch)
        }
        else {
            $Result.Add($Arch)
        }
    }
    return $Result.ToArray()
}
function ProcessVersion {
    param(
        [string]$Process,
        [string]$Url,
        [string]$VersionInput,
        [string]$MaxVersion
    )
    [string]$ReturnVersion = ''
    $Process = $Process.ToLowerInvariant()
    $VersionObtained = [version]::new()

    if ($Process -eq 'release') {
        $VersionObtained = GetReleaseVersion $Url $MaxVersion
    }
    elseif ($Process -eq 'tags') {
        $VersionObtained = GetTagsVersion $Url $MaxVersion
    }
    else {
        # nodejs
        $VersionObtained = GetNodeVersion $Url $MaxVersion
    }

    [version]$VersionInput = [version]::new()
    try {
        $VersionInput = [version]::Parse($Node.version)
    }
    catch {
        $VersionObtained = $VersionInput
    }
    if ($VersionInput -lt $VersionObtained) {
        $ReturnVersion = $VersionObtained.ToString()
        Write-Host ('{0} -version updated {1}' -f $Element, $VersionObtained) -ForegroundColor Cyan
    }
    else {
        if ($VersionInput -eq $VersionObtained) {
            Write-Host ('{0} - same version {1}' -f $Element, $VersionObtained) -ForegroundColor Green
        }
        else {
            $Msg = ('Invalid versions in {0}. Prev: {1}, Current: {2}' -f $Element, $VersionInput, $VersionObtained)
            Write-Host $Msg -ForegroundColor Red
        }
        $ReturnVersion = $Node.version
    }

    return [string]$ReturnVersion
}
try {
    #[string]$JsonFile = './url-list.json'
    $JsonFile = (Resolve-Path -Path $JsonFile)
    $WorkDir = (Resolve-Path -Path $OutputPrefix)
    $Files = @{ }
    foreach ($Arch in $Platforms) {
        $Filename = ('{0}_{1}.env' -f $Arch, $UniqueId)
        $Filename = (Join-Path -Path $WorkDir -ChildPath $Filename)
        $Files.$Arch = $Filename
        if ((Test-Path -Path $Filename -PathType Leaf)) {
            Remove-Item -Path $Filename -Force -Verbose
        }
    }
    $AppList = (Get-Content -Raw $JsonFile | ConvertFrom-Json -AsHashtable)
    $JsonOutput = @{ }
    foreach ($Element in $AppList.Keys) {
        $Node = $AppList[$Element]

        $KeyMaxVersion = 'max-version'
        $KeySrcUrlFrom = 'src-url-from'
        $KeyUrlSrc = 'url-src'
        $MaxVersion = [string]($Node.ContainsKey($KeyMaxVersion) ? $Node.$KeyMaxVersion : '')
        $Version = ProcessVersion $Node.process $Node.url $Node.version $MaxVersion
        $CurrentProcess = [ordered]@{
            install = $Node.install
            archive = $Node.archive
            process = $Node.process
            url     = $Node.url
            version = $Version
        }

        $Type = $Node.$KeySrcUrlFrom
        $InstallType = $Node.install
        if ($Type -eq 'replace') {
            # AWS...
            foreach ($Item in $Files.Keys) {
                $Arch = $Node.ContainsKey($Item) ? $Node.$Item : $Item

                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $Node.$KeyUrlSrc -replace '{REPLACE}', $Arch
            }
        }
        elseif (($Type -eq 'url-src')) {
            # D for Dotnet and Docker
            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $Node.$KeyUrlSrc
            }
        }
        elseif (($Type -eq 'url') -and ($InstallType -eq 'make')) {
            # and Git/Git.Git
            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $Node.url
            }
        }
        elseif (($Type -eq 'url') -and ($Node.process -eq 'nodejs')) {
            # NodeJS
            $Alternative = @(ChangeNames $Node $Platforms)
            $ScriptOutput = (./get-node-release.ps1 -Url $Node.url `
                    -FileType $Node.archive -Platforms $Platforms `
                    -AnotherName $Alternative)

            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $ScriptOutput.$Item
            }
        }
        else {
            # Binary from GitHub
            $Alternative = @(ChangeNames $Node $Platforms)
            $ScriptOutput = (./get-latest-release.ps1 -Url $Node.url `
                    -FileType $Node.archive -Platforms $Platforms `
                    -AnotherName $Alternative)

            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $ScriptOutput.$Item
            }
        }

        # Add to env file depend architecture
        foreach ($Item in $Files.Keys) {
            $Filename = $Files.$Item
            $ModKey = "url-$( $Item )"
            Add-Content -Path $Filename -Value ('{0}_URL={1}{2}' -f (CleanVar $Element), $CurrentProcess.$ModKey, "`n") -Encoding ascii -NoNewline
            Add-Content -Path $Filename -Value ('{0}_VERSION={1}{2}' -f (CleanVar $Element), $CurrentProcess.version, "`n") -Encoding ascii -NoNewline
        }

        # Output JSON
        $JsonOutput += [ordered]@{
            $Element = $CurrentProcess
        }
    }

    # Write JSON
    $Filename = ('{0}.json' -f $UniqueId)
    $Filename = (Join-Path -Path $WorkDir -ChildPath $Filename)
    $JsonOutput | Sort-Object  | ConvertTo-Json | Out-File -Path $Filename

    exit 0
}
catch {
    Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
    throw
}
