[CmdletBinding()]
param(
    [string] $EnvFile
)

$ErrorActionPreference = 'Stop'
$backendDirectory = Split-Path $PSScriptRoot -Parent
$repositoryDirectory = Split-Path $backendDirectory -Parent
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $EnvFile = Join-Path $repositoryDirectory '.secrets/real.env'
}
if (-not (Test-Path -LiteralPath $EnvFile -PathType Leaf)) {
    throw 'Missing the selected local API-key env file; no cloud request was made.'
}

$resolvedEnvFile = (Resolve-Path -LiteralPath $EnvFile).Path
$apiKeyValues = [System.Collections.Generic.List[string]]::new()
foreach ($line in [System.IO.File]::ReadLines($resolvedEnvFile)) {
    $match = [regex]::Match($line, '^\s*(?:export\s+)?APPWRITE_API_KEY\s*=\s*(.*?)\s*$')
    if (-not $match.Success) { continue }

    $value = $match.Groups[1].Value.Trim()
    if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[-1] -eq '"') -or ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    $apiKeyValues.Add($value)
}
if ($apiKeyValues.Count -ne 1 -or [string]::IsNullOrWhiteSpace($apiKeyValues[0])) {
    throw 'Expected exactly one non-empty APPWRITE_API_KEY in the local env file; no cloud request was made.'
}

$environmentNames = @(
    'APPWRITE_API_KEY',
    'APPWRITE_ENDPOINT',
    'APPWRITE_PROJECT_ID',
    'APPWRITE_PROJECT_ENV',
    'COC_DATABASE_ID',
    'ALLOW_LIVE_PROBE',
    'COC_DOTNET_APPWRITE_LIVE'
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
}

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$resultsDirectory = [System.IO.Path]::GetFullPath((Join-Path $temporaryRoot ("cocenglish-appwrite-live-" + [guid]::NewGuid().ToString('N'))))
if (-not $resultsDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Temporary results directory escaped the system temp folder; no cloud request was made.'
}
$null = New-Item -ItemType Directory -Path $resultsDirectory
$outboxExitCode = 1

try {
    $env:APPWRITE_API_KEY = $apiKeyValues[0]
    $env:APPWRITE_ENDPOINT = 'https://sgp.cloud.appwrite.io/v1'
    $env:APPWRITE_PROJECT_ID = '6acc656d0025cc57bd81'
    $env:APPWRITE_PROJECT_ENV = 'test'
    $env:COC_DATABASE_ID = 'cocenglish'
    $env:ALLOW_LIVE_PROBE = 'reviewed-test-project'
    $env:COC_DOTNET_APPWRITE_LIVE = '1'

    Push-Location -LiteralPath $backendDirectory
    try {
        & dotnet test tests/CocEnglish.Shared.Tests/CocEnglish.Shared.Tests.csproj --no-restore --configuration Release --filter 'FullyQualifiedName~AppwriteLiveTests' --results-directory $resultsDirectory --logger 'console;verbosity=minimal' --logger 'trx;LogFileName=AppwriteRows.trx'
        $rowExitCode = $LASTEXITCODE
        if ($rowExitCode -eq 0) {
            & dotnet test tests/CocEnglish.IntegrationTests/CocEnglish.IntegrationTests.csproj --no-restore --configuration Release --filter 'FullyQualifiedName~AppwriteStorageLiveTests' --results-directory $resultsDirectory --logger 'console;verbosity=minimal' --logger 'trx;LogFileName=AppwriteStorage.trx'
            $storageExitCode = $LASTEXITCODE
            if ($storageExitCode -eq 0) {
                & dotnet test tests/CocEnglish.IntegrationTests/CocEnglish.IntegrationTests.csproj --no-restore --configuration Release --filter 'FullyQualifiedName~AppwriteOutboxLiveTests' --results-directory $resultsDirectory --logger 'console;verbosity=minimal' --logger 'trx;LogFileName=AppwriteOutbox.trx'
                $outboxExitCode = $LASTEXITCODE
            }
        }
        else {
            $storageExitCode = 1
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    foreach ($name in $environmentNames) {
        $previousValue = $previousEnvironment[$name]
        if ($null -eq $previousValue) {
            Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item -Path "Env:$name" -Value $previousValue
        }
    }
    $apiKeyValues.Clear()
    $value = $null
}

if ($rowExitCode -ne 0 -or $storageExitCode -ne 0 -or $outboxExitCode -ne 0) {
    throw 'Appwrite live probes failed; response content and credentials are withheld.'
}
$rowResultFile = Join-Path $resultsDirectory 'AppwriteRows.trx'
$storageResultFile = Join-Path $resultsDirectory 'AppwriteStorage.trx'
$outboxResultFile = Join-Path $resultsDirectory 'AppwriteOutbox.trx'
if (-not (Test-Path -LiteralPath $rowResultFile -PathType Leaf) -or -not (Test-Path -LiteralPath $storageResultFile -PathType Leaf) -or -not (Test-Path -LiteralPath $outboxResultFile -PathType Leaf)) {
    throw 'Appwrite live probes did not produce all three test result files.'
}
[xml] $rowTrx = [System.IO.File]::ReadAllText($rowResultFile)
$rowCounters = $rowTrx.TestRun.ResultSummary.Counters
if ([int]$rowCounters.total -ne 5 -or [int]$rowCounters.passed -ne 5 -or [int]$rowCounters.failed -ne 0 -or [int]$rowCounters.notExecuted -ne 0) {
    throw 'Expected all five gated Appwrite row probes to execute and pass.'
}
[xml] $storageTrx = [System.IO.File]::ReadAllText($storageResultFile)
$storageCounters = $storageTrx.TestRun.ResultSummary.Counters
if ([int]$storageCounters.total -ne 1 -or [int]$storageCounters.passed -ne 1 -or [int]$storageCounters.failed -ne 0 -or [int]$storageCounters.notExecuted -ne 0) {
    throw 'Expected the gated Appwrite Storage round-trip probe to execute and pass.'
}
[xml] $outboxTrx = [System.IO.File]::ReadAllText($outboxResultFile)
$outboxCounters = $outboxTrx.TestRun.ResultSummary.Counters
if ([int]$outboxCounters.total -ne 1 -or [int]$outboxCounters.passed -ne 1 -or [int]$outboxCounters.failed -ne 0 -or [int]$outboxCounters.notExecuted -ne 0) {
    throw 'Expected the gated Appwrite outbox lease recovery probe to execute and pass.'
}
Write-Host 'Appwrite row, Storage and outbox lease probes passed against the pinned coccoc-test target.'

$resolvedResultsDirectory = (Resolve-Path -LiteralPath $resultsDirectory).Path
if (-not $resolvedResultsDirectory.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to remove a results directory outside the system temp folder.'
}
Remove-Item -LiteralPath $resolvedResultsDirectory -Recurse -Force
