param(
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
# Execution in GitHub Actions gives
# The variable '$LASTEXITCODE' cannot be retrieved because it has not been set
$LASTEXITCODE = 0
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

    if (($LASTEXITCODE -eq 0) -and ($? -eq $true)) {
        $Tag = ($Request | ConvertFrom-Json).tag_name
        $IsMaxVersion = [string]::IsNullOrEmpty($MaxVersion) ? $true : ($Tag -match $MaxVersion)
        $IsMatch = ($Tag -match '^(\D*)(\d+\.\d+\.\d+)(.*)')
        $VersionToParse = $Matches[2]
        if (($IsMatch) -and (![string]::IsNullOrWhiteSpace($VersionToParse)) -and (($MaxVersion -eq '') -or ($IsMaxVersion) )) {
            return [version]::Parse($VersionToParse)
        }
    }

    return [version]::new()
}

function GetTagsVersion {
    param([string]$Url, [string]$MaxVersion)

    $ApiUrl = GetApiUrl $Url
    $Request = (gh api -H $ConstApiMime -H $ConstApiVersion "$( $ApiUrl )/tags")

    if (($LASTEXITCODE -eq 0) -and ($? -eq $true)) {
        $Tag = (($Request | ConvertFrom-Json).name | ForEach-Object {
                $MatchResult = ($_ -match '^(\D*)(\d+\.\d+\.\d+)(.*)')
                $VersionToParse = $Matches[2]
                $IsMaxVersion = [string]::IsNullOrEmpty($MaxVersion) ? $true : ($VersionToParse -match $MaxVersion)
                if ($MatchResult -and (![string]::IsNullOrWhiteSpace($VersionToParse)) -and ($IsMaxVersion) ) {
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

    if (($LASTEXITCODE -eq 0) -and ($? -eq $true)) {
        $Tag = ($Request | ForEach-Object {
                $MatchResult = ($_ -match '^(\D*)(\d+\.\d+\.\d+)(.*)')
                $VersionToParse = $Matches[2]
                $IsMaxVersion = [string]::IsNullOrEmpty($MaxVersion) ? $true : ($VersionToParse -match $MaxVersion)
                if ($MatchResult -and (![string]::IsNullOrWhiteSpace($VersionToParse)) -and ($IsMaxVersion )) {
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
    [string]$Msg = ''
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
        $Msg = ('√ {0}:{1} → {2}' -f $Element, $VersionInput.ToString(), $VersionObtained.ToString())
        Write-Host $Msg -ForegroundColor Cyan
    }
    else {
        if ($VersionInput -eq $VersionObtained) {
            Write-Host ('≡ {0} same version {1}' -f $Element, $VersionObtained) -ForegroundColor Green
        }
        else {
            $Msg = ('ѣ Invalid versions in {0}:{1} ↔ {2}' -f $Element, $VersionInput.ToString(), $VersionObtained.ToString())
            Write-Host $Msg -ForegroundColor Red
        }
        $ReturnVersion = $Node.version
    }

    return @{
        Version = [string]$ReturnVersion
        Info    = $Msg
    }
}

try {
    #[string]$JsonFile = './url-list.json'
    $JsonFile = (Resolve-Path -Path $JsonFile)
    $WorkDir = $OutputPrefix
    $ScriptsPath = (Resolve-Path -Path $MyInvocation.MyCommand.Path | Get-Item).Directory.FullName
    DebugMessage $ScriptsPath
    $Files = @{ }
    for ($Index = 0; $Index -lt $Platforms.Count; $Index++) {
        $Arch = $Platforms[$Index].ToLowerInvariant()
        if ($Arch.Contains('/')) {
            $Parted = $Arch -split '/'
            $Arch = $Parted[1]
        }
        # Also clean input array
        $Platforms[$Index] = $Arch
        $Files.$Arch = New-Object System.Collections.Generic.List[System.String]
    }
    $LogVersionVerdict = New-Object -TypeName "System.Text.StringBuilder"
    $AppList = (Get-Content -Raw $JsonFile | ConvertFrom-Json -AsHashtable)
    $JsonOutput = @{ }
    $GhRunnerVersion = ''
    foreach ($Element in $AppList.Keys) {
        $Node = $AppList[$Element]

        $KeyMaxVersion = 'max-version'
        $KeySrcUrlFrom = 'src-url-from'
        $KeyUrlSrc = 'url-src'
        $MaxVersion = [string]($Node.ContainsKey($KeyMaxVersion) ? $Node.$KeyMaxVersion : '')
        $VersionInfo = ProcessVersion $Node.process $Node.url $Node.version $MaxVersion
        if (![string]::IsNullOrEmpty($VersionInfo.Info)) {
            [void]$LogVersionVerdict.Append($VersionInfo.Info).Append(';')
        }

        $CurrentProcess = [ordered]@{
            install = $Node.install
            archive = $Node.archive
            process = $Node.process
            url     = $Node.url
            version = $VersionInfo.Version
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
            # $Parameters = @{
            #     FilePath     = $ScriptNodeJsRelease
            #     ArgumentList = $Node.url, $Node.archive, $Platforms, $Alternative
            #     # ArgumentList = "-Url $($Node.url) -FileType $($Node.archive) -Platforms $($Platforms) -AnotherName $($Alternative)"
            # }
            $PlatformsFlat = $Platforms -join ','
            $AlternativeFlat = $Alternative -join ','
            $ScriptInvoke = "$($ScriptsPath)\nodejs-latest.ps1 -Url $($Node.url) -FileType $($Node.archive) -Platforms $($PlatformsFlat) -AnotherName $($AlternativeFlat) -MaxVersion $($MaxVersion)"
            DebugMessage $ScriptInvoke
            $ScriptOutput = Invoke-Expression $ScriptInvoke -ErrorAction Stop
            DebugMessage ($ScriptOutput | ConvertTo-Json)

            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $ScriptOutput.$Item
            }
        }
        else {
            # Binary from GitHub
            $Alternative = @(ChangeNames $Node $Platforms)
            # $Parameters = @{
            #     FilePath     = $ScriptGithubLatestRelease
            #     #ArgumentList = "-Url $($Node.url) -FileType $($Node.archive) -Platforms $($Platforms) -AnotherName $($Alternative)"
            #     ArgumentList = $Node.url, $Node.archive, $Platforms, $Alternative
            # }
            # $ScriptOutput = Invoke-Command @parameters
            $PlatformsFlat = $Platforms -join ','
            $AlternativeFlat = $Alternative -join ','
            $ScriptInvoke = "$($ScriptsPath)\github-latest-release.ps1 -Url $($Node.url) -FileType $($Node.archive) -Platforms $($PlatformsFlat) -AnotherName $($AlternativeFlat)"
            DebugMessage $ScriptInvoke
            $ScriptOutput = Invoke-Expression $ScriptInvoke -ErrorAction Stop
            DebugMessage ($ScriptOutput | ConvertTo-Json)

            foreach ($Item in $Files.Keys) {
                $ModKey = "url-$( $Item )"
                $CurrentProcess.$ModKey = $ScriptOutput.$Item
            }
        }

        # Add to env file depend architecture
        foreach ($Item in $Files.Keys) {
            $ModKey = "url-$( $Item )"
            $Files.$Item.Add(('{0}_URL={1}' -f (CleanVar $Element), $CurrentProcess.$ModKey))
            $Files.$Item.Add(('{0}_VERSION={1}' -f (CleanVar $Element), $CurrentProcess.version))
        }

        # Output JSON
        $JsonOutput += [ordered]@{
            $Element = $CurrentProcess
        }

        if ($Element -like 'gh-runner') {
            $GhRunnerVersion = $CurrentProcess.version
        }
    }

    # Ok now write files
    # Add to env file depend architecture
    $FilesWasChanged = $false
    foreach ($Item in $Files.Keys) {
        $Filename = ('{0}_{1}.env' -f $Item, 'extra')
        $Filename = (Join-Path -Path $WorkDir -ChildPath $Filename)
        Write-Information ("Trying to write file: {0}, Key: {1}" -f $Filename, $Item)
        $NewContent = ($Files.$Item.ToArray() -join "`n")
        $IsNull = ([string]::IsNullOrWhiteSpace($NewContent))

        if ($IsNull) {
            continue
        }

        if (Test-Path -Path $Filename -PathType Leaf) {
            $OldContent = (Get-Content -Path $Filename)
            $IsNull = ([string]::IsNullOrWhiteSpace($OldContent))
            if (!$IsNull) {
                $FilesCompare = (Compare-Object -ReferenceObject $NewContent -DifferenceObject $OldContent  `
                    | Measure-Object).Count

                if ($FilesCompare -eq 0) {
                    # Nothing to do here
                    continue
                }
            }
            # Delete old file
            Remove-Item -Path $Filename -Force -Verbose
        }
        Add-Content -Path $Filename -Value $NewContent -Encoding ascii -NoNewline

        $FilesWasChanged = $true
    }

    # Write JSON
    # if ($IsDebug) {
    #     $Filename = ('{0}.json' -f $UniqueId)
    #     $Filename = (Join-Path -Path $WorkDir -ChildPath $Filename)
    #     $JsonOutput | Sort-Object  | ConvertTo-Json | Out-File -Path $Filename
    # }

    if ($FilesWasChanged) {
        Write-Output "files_changed=1"
    }
    else {
        Write-Output "files_changed=0"
    }
    Write-Output ('gh_runner_new_version={0}' -f $GhRunnerVersion)
    Write-Output('log_version={0}' -f $LogVersionVerdict.ToString())
    exit 0
}
catch {
    Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
    Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
    throw
}
