<#
.SYNOPSIS
Shows likely local Clash / Mihomo proxy ports on Windows.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\Check-ClashPort.ps1
#>

$ErrorActionPreference = "Stop"

$clashVergeDir = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev"
$knownPorts = @(7897, 7890, 7891, 7893, 7894, 7895, 7896, 7898, 7899, 1080, 10808, 10809)

function Get-ConfiguredMixedPort {
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

$listeners = Get-NetTCPConnection -LocalAddress 127.0.0.1 -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $_.LocalPort -in $knownPorts } |
    Select-Object LocalAddress, LocalPort, OwningProcess, @{ Name = "ProcessName"; Expression = { (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName } } |
    Sort-Object @{ Expression = { [array]::IndexOf($knownPorts, [int]$_.LocalPort) } }

if (-not $listeners) {
    Write-Host "No common local proxy ports were found on 127.0.0.1." -ForegroundColor Yellow
    Write-Host "Open Clash Verge and look for: Settings / Network / Mixed Port."
    exit 1
}

Write-Host "Configured Clash/Mihomo mixed port:" -ForegroundColor Green
$configuredPort = Get-ConfiguredMixedPort -ClashDir $clashVergeDir
if ($configuredPort) {
    Write-Host $configuredPort
}
else {
    Write-Host "Not found in Clash Verge config files." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Possible local proxy ports:" -ForegroundColor Green
$listeners | Format-Table -AutoSize

$bestPort = $configuredPort
if (-not $bestPort) {
    $best = $listeners |
        Where-Object { $_.ProcessName -match "clash|mihomo|verge|v2ray|sing-box" } |
        Select-Object -First 1

    if (-not $best) {
        $best = $listeners | Select-Object -First 1
    }

    $bestPort = $best.LocalPort
}

Write-Host ""
Write-Host "Suggested command:" -ForegroundColor Green
Write-Host "powershell -ExecutionPolicy Bypass -File .\Fix-CodexReconnect5.ps1 -ProxyPort $bestPort"
