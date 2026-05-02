[CmdletBinding()]
param(
  [ValidateSet("starter", "file", "dir-session", "all")]
  [string]$Scenario = "all",

  [int]$Runs = 10,
  [int]$Warmup = 2,

  [string]$File = "README.md",
  [string]$Directory = ".",
  [string]$Nvim = "nvim",
  [string]$OutputDir = ".startup-benchmarks",

  [switch]$Headless
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Runs -le 0) {
  throw "Runs must be greater than 0."
}

if ($Warmup -lt 0) {
  throw "Warmup must be 0 or greater."
}

if ($Warmup -ge $Runs) {
  throw "Warmup must be smaller than Runs."
}

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$RunRoot = $OutputDir

if (-not [System.IO.Path]::IsPathRooted($RunRoot)) {
  $RunRoot = Join-Path $RepoRoot $RunRoot
}

$RunDir = Join-Path $RunRoot $Timestamp
$LogDir = Join-Path $RunDir "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Resolve-ScenarioPath {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Kind
  )

  $candidate = $Path
  if (-not [System.IO.Path]::IsPathRooted($candidate)) {
    $candidate = Join-Path $RepoRoot $candidate
  }

  $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
  $item = Get-Item -LiteralPath $resolved.Path

  if ($Kind -eq "file" -and -not $item.PSIsContainer) {
    return $item.FullName
  }

  if ($Kind -eq "directory" -and $item.PSIsContainer) {
    return $item.FullName
  }

  throw "Expected $Kind path, got: $($item.FullName)"
}

function Get-Scenarios {
  if ($Scenario -eq "all") {
    return @("starter", "file", "dir-session")
  }

  return @($Scenario)
}

function Get-NvimArgs {
  param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$LogPath
  )

  $args = @()

  if ($Headless) {
    $args += "--headless"
  }

  $args += @("--startuptime", $LogPath)

  switch ($Name) {
    "starter" {
      $args += "+qa"
    }
    "file" {
      $args += @(Resolve-ScenarioPath -Path $File -Kind "file")
      $args += "+qa"
    }
    "dir-session" {
      $args += @(Resolve-ScenarioPath -Path $Directory -Kind "directory")
      $args += "+qa"
    }
    default {
      throw "Unknown scenario: $Name"
    }
  }

  return $args
}

function Get-StartupTime {
  param([Parameter(Mandatory)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  $lines = @(Get-Content -LiteralPath $Path)
  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    $line = $lines[$i]
    if ($line -match '^\s*([0-9]+(?:\.[0-9]+)?)\s+[0-9]+(?:\.[0-9]+)?:\s+NVIM STARTED') {
      return [double]$Matches[1]
    }
  }

  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    $line = $lines[$i]
    if ($line -match '^\s*([0-9]+(?:\.[0-9]+)?)\s+') {
      return [double]$Matches[1]
    }
  }

  return $null
}

function Get-Median {
  param([double[]]$Values)

  $sorted = @($Values | Sort-Object)
  $count = $sorted.Count
  if ($count -eq 0) {
    return $null
  }

  $middle = [int][Math]::Floor($count / 2)
  if ($count % 2 -eq 1) {
    return [double]$sorted[$middle]
  }

  return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Get-Percentile {
  param(
    [double[]]$Values,
    [double]$Percent
  )

  $sorted = @($Values | Sort-Object)
  $count = $sorted.Count
  if ($count -eq 0) {
    return $null
  }

  $index = [int][Math]::Ceiling(($Percent / 100.0) * $count) - 1
  $index = [Math]::Max(0, [Math]::Min($index, $count - 1))
  return [double]$sorted[$index]
}

function Format-Ms {
  param($Value)

  if ($null -eq $Value) {
    return ""
  }

  return "{0:N2}" -f ([double]$Value)
}

function Get-ScenarioSummary {
  param(
    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [object[]]$Records
  )

  $samples = @(
    $Records |
      Where-Object { $_.scenario -eq $Name -and -not $_.warmup -and $_.exit_code -eq 0 -and $null -ne $_.startup_ms } |
      ForEach-Object { [double]$_.startup_ms }
  )

  if ($samples.Count -eq 0) {
    return [pscustomobject]@{
      scenario = $Name
      samples = 0
      min_ms = $null
      median_ms = $null
      p75_ms = $null
      p90_ms = $null
      max_ms = $null
      mean_ms = $null
    }
  }

  $sum = 0.0
  foreach ($sample in $samples) {
    $sum += $sample
  }

  return [pscustomobject]@{
    scenario = $Name
    samples = $samples.Count
    min_ms = [double]($samples | Measure-Object -Minimum).Minimum
    median_ms = Get-Median -Values $samples
    p75_ms = Get-Percentile -Values $samples -Percent 75
    p90_ms = Get-Percentile -Values $samples -Percent 90
    max_ms = [double]($samples | Measure-Object -Maximum).Maximum
    mean_ms = $sum / $samples.Count
  }
}

Set-Location $RepoRoot

$scenarios = Get-Scenarios
$records = @()

foreach ($scenarioName in $scenarios) {
  Write-Host "== $scenarioName =="

  for ($run = 1; $run -le $Runs; $run++) {
    $isWarmup = $run -le $Warmup
    $label = if ($isWarmup) { "warmup" } else { "sample" }
    $logPath = Join-Path $LogDir ("{0}-{1:D2}.log" -f $scenarioName, $run)
    $args = Get-NvimArgs -Name $scenarioName -LogPath $logPath

    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    & $Nvim @args
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    $wall.Stop()

    $startupMs = Get-StartupTime -Path $logPath
    Write-Host ("{0,2}/{1} {2,-6} startup={3}ms wall={4}ms exit={5}" -f $run, $Runs, $label, (Format-Ms $startupMs), (Format-Ms $wall.Elapsed.TotalMilliseconds), $exitCode)

    $records += [pscustomobject]@{
      scenario = $scenarioName
      run = $run
      warmup = $isWarmup
      startup_ms = $startupMs
      wall_ms = [Math]::Round($wall.Elapsed.TotalMilliseconds, 2)
      exit_code = $exitCode
      log = $logPath
    }
  }
}

$summary = @()
foreach ($scenarioName in $scenarios) {
  $summary += Get-ScenarioSummary -Name $scenarioName -Records $records
}

$samplesCsv = Join-Path $RunDir "samples.csv"
$summaryCsv = Join-Path $RunDir "summary.csv"
$summaryJson = Join-Path $RunDir "summary.json"
$summaryMd = Join-Path $RunDir "summary.md"

$records | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $samplesCsv
$summary | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $summaryCsv
$summary | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $summaryJson

$markdown = @()
$markdown += "# Neovim Startup Benchmark"
$markdown += ""
$markdown += "- Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
$markdown += "- Runs: $Runs"
$markdown += "- Warmup discarded: $Warmup"
$markdown += "- Headless: $($Headless.IsPresent)"
$markdown += "- Nvim: $Nvim"
$markdown += ""
$markdown += "| Scenario | Samples | Min | Median | P75 | P90 | Max | Mean |"
$markdown += "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"

foreach ($row in $summary) {
  $markdown += "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f `
    $row.scenario,
    $row.samples,
    (Format-Ms $row.min_ms),
    (Format-Ms $row.median_ms),
    (Format-Ms $row.p75_ms),
    (Format-Ms $row.p90_ms),
    (Format-Ms $row.max_ms),
    (Format-Ms $row.mean_ms)
}

$markdown += ""
$markdown += "Raw samples: ``samples.csv``"
$markdown += "Raw logs: ``logs/``"
$markdown | Set-Content -Encoding UTF8 -Path $summaryMd

Write-Host ""
Write-Host "Summary"
$summary | Format-Table scenario, samples, @{ Label = "min"; Expression = { Format-Ms $_.min_ms } }, @{ Label = "median"; Expression = { Format-Ms $_.median_ms } }, @{ Label = "p75"; Expression = { Format-Ms $_.p75_ms } }, @{ Label = "p90"; Expression = { Format-Ms $_.p90_ms } }, @{ Label = "max"; Expression = { Format-Ms $_.max_ms } }, @{ Label = "mean"; Expression = { Format-Ms $_.mean_ms } }

Write-Host "Wrote benchmark output to: $RunDir"
