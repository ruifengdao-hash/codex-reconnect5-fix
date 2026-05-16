<#
.SYNOPSIS
Fixes repeated "reconnect 5" issues in Codex when using Clash Verge / Mihomo on Windows.

.DESCRIPTION
This script applies the same low-risk fixes used during diagnosis:
- Sets user-level proxy environment variables for Codex and child processes.
- Keeps localhost out of the proxy path.
- Adds OpenAI/Codex domains to Clash Verge rule enhancement files.
- Optionally disables IPv6 in Clash Verge merge enhancement.
- Optionally disables Clash Verge auto-close-connection behavior.
- Adds ::1 to Windows system proxy bypass list.

Restart Clash Verge and Codex after running the script.

If you do not know your proxy port, run Check-ClashPort.ps1 first or use -AutoDetectPort.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7897

Use the default proxy host 127.0.0.1 and set the Clash/Mihomo port to 7897.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyHost 192.168.1.10 -ProxyPort 7897

Use a custom proxy host and port. This is useful when Clash/Mihomo runs on another device or LAN address.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort 7890 -WhatIf

Preview the changes without modifying anything.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -AutoDetectPort

Try to detect the local Clash/Mihomo listening port automatically, then apply the fix.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ProxyHost = "127.0.0.1",
    [int]$ProxyPort = 7897,
    [switch]$AutoDetectPort,
    [string]$ClashVergeDir = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev",
    [string[]]$OpenAIDomains = @(
        "openai.com",
        "chatgpt.com",
        "oaistatic.com",
        "oaiusercontent.com",
        "auth0.com"
    ),
    [bool]$DisableClashIpv6 = $true,
    [bool]$DisableAutoCloseConnection = $true,
    [switch]$TryWinHttpImport
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message"
}

function Write-Done {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Get-ClashConfiguredMixedPort {
    param([string]$ClashDir)

    $candidateFiles = @(
        (Join-Path $ClashDir "config.yaml"),
        (Join-Path $ClashDir "clash-verge.yaml"),
        (Join-Path $ClashDir "verge.yaml")
    )

    foreach ($file in $candidateFiles) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            continue
        }

        $content = Get-Content -LiteralPath $file -Raw
        $mixedMatch = [regex]::Match($content, "(?m)^\s*(mixed-port|verge_mixed_port)\s*:\s*(?<port>\d+)\s*$")
        if ($mixedMatch.Success) {
            return [int]$mixedMatch.Groups["port"].Value
        }
    }

    return $null
}

function Find-LocalProxyPort {
    param([string]$ClashDir)

    $configuredPort = Get-ClashConfiguredMixedPort -ClashDir $ClashDir
    if ($configuredPort) {
        return $configuredPort
    }

    $preferredPorts = @(7897, 7890, 7891, 7893, 7894, 7895, 7896, 7898, 7899, 1080, 10808, 10809)

    $listeners = Get-NetTCPConnection -LocalAddress 127.0.0.1 -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -in $preferredPorts } |
        Select-Object LocalPort, OwningProcess, @{ Name = "ProcessName"; Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } }

    $clashListener = $listeners |
        Where-Object { $_.ProcessName -match "clash|mihomo|verge|v2ray|sing-box" } |
        Sort-Object @{ Expression = { [array]::IndexOf($preferredPorts, [int]$_.LocalPort) } } |
        Select-Object -First 1

    if ($clashListener) {
        return $clashListener.LocalPort
    }

    $anyListener = $listeners |
        Sort-Object @{ Expression = { [array]::IndexOf($preferredPorts, [int]$_.LocalPort) } } |
        Select-Object -First 1

    if ($anyListener) {
        return $anyListener.LocalPort
    }

    return $null
}

function Backup-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$Path.bak-$stamp"
    if ($PSCmdlet.ShouldProcess($Path, "Create backup $backupPath")) {
        Copy-Item -LiteralPath $Path -Destination $backupPath
    }
}

function Set-UserProxyEnvironment {
    param([string]$ProxyUrl)

    $pairs = @(
        @{ Name = "HTTP_PROXY"; Value = $ProxyUrl },
        @{ Name = "HTTPS_PROXY"; Value = $ProxyUrl },
        @{ Name = "ALL_PROXY"; Value = $ProxyUrl },
        @{ Name = "http_proxy"; Value = $ProxyUrl },
        @{ Name = "https_proxy"; Value = $ProxyUrl },
        @{ Name = "all_proxy"; Value = $ProxyUrl },
        @{ Name = "NO_PROXY"; Value = "localhost,127.0.0.1,::1" },
        @{ Name = "no_proxy"; Value = "localhost,127.0.0.1,::1" }
    )

    foreach ($pair in $pairs) {
        if ($PSCmdlet.ShouldProcess("User environment", "Set $($pair.Name)=$($pair.Value)")) {
            [Environment]::SetEnvironmentVariable($pair.Name, $pair.Value, "User")
        }
    }
}

function Update-WindowsProxyBypass {
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $path
    $current = $props.ProxyOverride

    $parts = @()
    if ($current) {
        $parts += $current -split ";" | Where-Object { $_ -ne "" }
    }

    foreach ($required in @("localhost", "127.*", "::1", "<local>")) {
        if ($parts -notcontains $required) {
            $parts += $required
        }
    }

    $newValue = ($parts | Select-Object -Unique) -join ";"
    if ($PSCmdlet.ShouldProcess($path, "Set ProxyOverride=$newValue")) {
        Set-ItemProperty -Path $path -Name ProxyOverride -Value $newValue
    }
}

function Set-Or-AppendYamlScalar {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $content = ""
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $content = Get-Content -LiteralPath $Path -Raw
    }

    $pattern = "(?m)^$([regex]::Escape($Key))\s*:\s*.*$"
    if ($content -match $pattern) {
        $newContent = [regex]::Replace($content, $pattern, "$Key`: $Value")
    }
    else {
        if ($content -and -not $content.EndsWith("`n")) {
            $content += "`r`n"
        }
        $newContent = $content + "$Key`: $Value`r`n"
    }

    if ($PSCmdlet.ShouldProcess($Path, "Set $Key to $Value")) {
        Set-Content -LiteralPath $Path -Value $newContent -Encoding UTF8
    }
}

function Update-ClashRuleEnhancement {
    param(
        [string]$RulesPath,
        [string[]]$Domains
    )

    if (-not (Test-Path -LiteralPath $RulesPath -PathType Leaf)) {
        $initial = "# Profile Enhancement Rules Template for Clash Verge`r`n`r`nprepend: []`r`n`r`nappend: []`r`n`r`ndelete: []`r`n"
        if ($PSCmdlet.ShouldProcess($RulesPath, "Create rules enhancement file")) {
            Set-Content -LiteralPath $RulesPath -Value $initial -Encoding UTF8
        }
    }

    $existing = Get-Content -LiteralPath $RulesPath -Raw
    $rules = foreach ($domain in $Domains) {
        "  - DOMAIN-SUFFIX,$domain,Proxy"
    }

    if ($existing -match "(?ms)^prepend:\s*\[\]\s*$") {
        $replacement = "prepend:`r`n" + ($rules -join "`r`n")
        $newContent = [regex]::Replace($existing, "(?ms)^prepend:\s*\[\]\s*$", $replacement)
    }
    elseif ($existing -match "(?ms)^prepend:\s*\r?\n(?<body>.*?)(?=^\S|\z)") {
        $body = $Matches.body
        $missingRules = $rules | Where-Object { $body -notmatch [regex]::Escape($_) }
        if ($missingRules.Count -eq 0) {
            Write-Done "OpenAI domain rules already exist in $RulesPath"
            return
        }
        $insert = ($missingRules -join "`r`n") + "`r`n"
        $newContent = [regex]::Replace($existing, "(?ms)^prepend:\s*\r?\n", "prepend:`r`n$insert", 1)
    }
    else {
        $block = "prepend:`r`n" + ($rules -join "`r`n") + "`r`n"
        $newContent = $block + "`r`n" + $existing
    }

    if ($PSCmdlet.ShouldProcess($RulesPath, "Add OpenAI/Codex proxy rules")) {
        Set-Content -LiteralPath $RulesPath -Value $newContent -Encoding UTF8
    }
}

function Disable-ClashIpv6InMerge {
    param([string]$MergePath)

    if (-not (Test-Path -LiteralPath $MergePath -PathType Leaf)) {
        if ($PSCmdlet.ShouldProcess($MergePath, "Create merge enhancement file")) {
            Set-Content -LiteralPath $MergePath -Value "# Profile Enhancement Merge Template for Clash Verge`r`n" -Encoding UTF8
        }
    }

    Set-Or-AppendYamlScalar -Path $MergePath -Key "ipv6" -Value "false"
}

function Disable-ClashAutoCloseConnection {
    param([string]$VergePath)

    if (-not (Test-Path -LiteralPath $VergePath -PathType Leaf)) {
        Write-Warn "Cannot find $VergePath. Skipped auto_close_connection update."
        return
    }

    Set-Or-AppendYamlScalar -Path $VergePath -Key "auto_close_connection" -Value "false"
}

function Get-ClashProfileItemFile {
    param(
        [string]$ProfilesYaml,
        [string]$Uid
    )

    if (-not $Uid) {
        return $null
    }

    $escapedUid = [regex]::Escape($Uid)
    $pattern = "(?ms)^\s*-\s+uid:\s*$escapedUid\s*\r?\n(?<block>.*?)(?=^\s*-\s+uid:|\z)"
    $match = [regex]::Match($ProfilesYaml, $pattern)
    if (-not $match.Success) {
        return $null
    }

    $block = $match.Groups["block"].Value
    $fileMatch = [regex]::Match($block, "(?m)^\s*file:\s*(?<file>\S+)\s*$")
    if ($fileMatch.Success) {
        return $fileMatch.Groups["file"].Value.Trim("'`"")
    }

    return $null
}

function Resolve-ClashEnhancementPaths {
    param([string]$ClashDir)

    $profilesDir = Join-Path $ClashDir "profiles"
    $profilesYamlPath = Join-Path $ClashDir "profiles.yaml"
    $result = [ordered]@{
        ProfilesDir = $profilesDir
        RulesPath   = Join-Path $profilesDir "rules-enhancement.yaml"
        MergePath   = Join-Path $profilesDir "merge-enhancement.yaml"
        VergePath   = Join-Path $ClashDir "verge.yaml"
    }

    if (-not (Test-Path -LiteralPath $profilesYamlPath -PathType Leaf)) {
        return [pscustomobject]$result
    }

    $profilesYaml = Get-Content -LiteralPath $profilesYamlPath -Raw
    $currentMatch = [regex]::Match($profilesYaml, "(?m)^current:\s*(?<uid>\S+)\s*$")
    if (-not $currentMatch.Success) {
        return [pscustomobject]$result
    }

    $currentUid = $currentMatch.Groups["uid"].Value
    $currentPattern = "(?ms)^\s*-\s+uid:\s*$([regex]::Escape($currentUid))\s*\r?\n(?<block>.*?)(?=^\s*-\s+uid:|\z)"
    $currentItem = [regex]::Match($profilesYaml, $currentPattern)
    if (-not $currentItem.Success) {
        return [pscustomobject]$result
    }

    $block = $currentItem.Groups["block"].Value
    $rulesUidMatch = [regex]::Match($block, "(?m)^\s*rules:\s*(?<uid>\S+)\s*$")
    $mergeUidMatch = [regex]::Match($block, "(?m)^\s*merge:\s*(?<uid>\S+)\s*$")

    if ($rulesUidMatch.Success) {
        $rulesFile = Get-ClashProfileItemFile -ProfilesYaml $profilesYaml -Uid $rulesUidMatch.Groups["uid"].Value
        if ($rulesFile) {
            $result.RulesPath = Join-Path $profilesDir $rulesFile
        }
    }

    if ($mergeUidMatch.Success) {
        $mergeFile = Get-ClashProfileItemFile -ProfilesYaml $profilesYaml -Uid $mergeUidMatch.Groups["uid"].Value
        if ($mergeFile) {
            $result.MergePath = Join-Path $profilesDir $mergeFile
        }
    }

    return [pscustomobject]$result
}

function Send-EnvironmentRefresh {
    if ($WhatIfPreference) {
        Write-Host "What if: broadcast Windows environment and proxy setting refresh"
        return
    }

    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@

    Add-Type -Namespace Win32 -Name InternetOptions -MemberDefinition @"
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@

    [Win32.InternetOptions]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
    [Win32.InternetOptions]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null

    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 0x0002, 5000, [ref]$result) | Out-Null
}

function Test-ProxyEndpoint {
    param([string]$ProxyUrl)

    Write-Step "Testing proxy access to https://api.openai.com/"

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = & curl.exe --silent --show-error --head --location --max-time 20 --proxy $ProxyUrl https://api.openai.com/ 2>&1
        $exitCode = $LASTEXITCODE
        $text = $output | Out-String

        if ($text -match "HTTP/1\.1 200 Connection established" -or $text -match "HTTP/2|HTTP/1\.1") {
            Write-Done "Proxy endpoint responded. Cloudflare 421/403 responses are acceptable for this connectivity test."
        }
        elseif ($exitCode -eq 0) {
            Write-Done "Proxy test command completed."
        }
        else {
            Write-Warn "Proxy test did not show a normal HTTP response. Check Clash node stability and port."
        }
    }
    catch {
        Write-Warn "Proxy test failed, but the configuration changes were already applied."
        Write-Warn $_.Exception.Message
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

if ($AutoDetectPort) {
    Write-Step "Trying to auto-detect local Clash/Mihomo proxy port"
    $detectedPort = Find-LocalProxyPort -ClashDir $ClashVergeDir
    if ($detectedPort) {
        $ProxyPort = [int]$detectedPort
        Write-Done "Detected local proxy port: $ProxyPort"
    }
    else {
        Write-Warn "Could not auto-detect a local proxy port. Falling back to -ProxyPort $ProxyPort."
    }
}

$proxyUrl = "http://$ProxyHost`:$ProxyPort"
$clashPaths = Resolve-ClashEnhancementPaths -ClashDir $ClashVergeDir
$profilesDir = $clashPaths.ProfilesDir
$rulesPath = $clashPaths.RulesPath
$mergePath = $clashPaths.MergePath
$vergePath = $clashPaths.VergePath

Write-Step "Using proxy $proxyUrl"

if (-not (Test-Path -LiteralPath $ClashVergeDir -PathType Container)) {
    Write-Warn "Clash Verge directory was not found: $ClashVergeDir"
    Write-Warn "The script will still set Windows/Codex proxy environment variables."
}

Write-Step "Setting user-level proxy environment variables"
Set-UserProxyEnvironment -ProxyUrl $proxyUrl
Write-Done "User environment variables configured"

Write-Step "Updating Windows local proxy bypass list"
Update-WindowsProxyBypass
Write-Done "Windows proxy bypass list updated"

if (Test-Path -LiteralPath $profilesDir -PathType Container) {
    Write-Step "Backing up Clash Verge enhancement files"
    Backup-File -Path $rulesPath
    Backup-File -Path $mergePath
    Backup-File -Path $vergePath

    Write-Step "Adding OpenAI/Codex domains to Clash rules enhancement"
    Update-ClashRuleEnhancement -RulesPath $rulesPath -Domains $OpenAIDomains
    Write-Done "Rules enhancement updated"

    if ($DisableClashIpv6) {
        Write-Step "Disabling IPv6 in Clash merge enhancement"
        Disable-ClashIpv6InMerge -MergePath $mergePath
        Write-Done "Clash IPv6 disabled in merge enhancement"
    }

    if ($DisableAutoCloseConnection) {
        Write-Step "Disabling Clash Verge auto_close_connection"
        Disable-ClashAutoCloseConnection -VergePath $vergePath
        Write-Done "auto_close_connection disabled"
    }
}
else {
    Write-Warn "Profiles directory was not found: $profilesDir"
}

if ($TryWinHttpImport) {
    Write-Step "Trying to import current Windows proxy into WinHTTP"
    $winHttpOutput = & netsh winhttp import proxy source=ie 2>&1
    $winHttpText = $winHttpOutput | Out-String
    Write-Host $winHttpText
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "WinHTTP import failed. Run PowerShell as Administrator and retry with -TryWinHttpImport if needed."
    }
}

Write-Step "Broadcasting Windows proxy/environment refresh"
Send-EnvironmentRefresh
Write-Done "Refresh broadcast sent"

if (-not $WhatIfPreference) {
    Test-ProxyEndpoint -ProxyUrl $proxyUrl
}

Write-Host ""
Write-Done "Done. Fully exit Clash Verge and Codex, then start Clash Verge first and Codex second."
