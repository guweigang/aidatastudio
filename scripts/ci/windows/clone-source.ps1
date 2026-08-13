param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$SourceRef,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 3
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Destination) -or $Destination -in @(".", "..")) {
    throw "Refusing unsafe clone destination: '$Destination'"
}

function Invoke-GitCloneWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-Path -LiteralPath $Destination) {
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }

        Write-Host "$Description (attempt $attempt/$MaxAttempts)"
        & git @Arguments
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            return $true
        }

        if ($attempt -lt $MaxAttempts) {
            $delaySeconds = 10 * $attempt
            Write-Warning "git clone exited with code $exitCode; retrying in $delaySeconds seconds"
            Start-Sleep -Seconds $delaySeconds
        }
    }

    return $false
}

$shallowArguments = @(
    "clone",
    "--depth", "1",
    "--branch", $SourceRef,
    $Repository,
    $Destination
)

if (Invoke-GitCloneWithRetry -Arguments $shallowArguments -Description "Cloning source ref '$SourceRef'") {
    exit 0
}

Write-Warning "Shallow branch/tag clone failed; falling back to a full clone for commit refs"
$fullArguments = @("clone", $Repository, $Destination)
if (-not (Invoke-GitCloneWithRetry -Arguments $fullArguments -Description "Cloning full source repository")) {
    throw "Failed to clone '$Repository' after retrying shallow and full clones"
}

Push-Location $Destination
try {
    git checkout $SourceRef
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to check out source ref '$SourceRef'"
    }
}
finally {
    Pop-Location
}
