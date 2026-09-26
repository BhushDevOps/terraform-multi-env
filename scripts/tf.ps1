<#
    tf.ps1 - run Terraform for one environment inside one AWS account.

    Usage:
        .\scripts\tf.ps1 dev  env1 plan
        .\scripts\tf.ps1 dev  env1 apply
        .\scripts\tf.ps1 prod env2 plan
        .\scripts\tf.ps1 test env3 output

    Why a wrapper?
    All environments in one account share ONE stack folder, so every run must
    be told three things:
      1. which backend config to init with   -> live/<acct>/<env>/backend.hcl
      2. which values to use                 -> account.tfvars + env tfvars
      3. where to keep its own .terraform    -> TF_DATA_DIR

    Point 3 is the important one. Without a separate TF_DATA_DIR, env1 and env2
    would share the same .terraform folder and the same cached backend, and you
    could apply env1's plan onto env2's state. The wrapper makes that impossible.
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Account,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Environment,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateSet('init', 'validate', 'plan', 'apply', 'destroy', 'output', 'fmt')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$stackDir = Join-Path $repoRoot "live\$Account\stack"
$envDir   = Join-Path $repoRoot "live\$Account\$Environment"

if (-not (Test-Path $envDir)) {
    throw "No such environment: live\$Account\$Environment"
}

# Paths below are relative to $stackDir, because terraform -chdir moves there.
$backendCfg  = "..\$Environment\backend.hcl"
$accountVars = "..\account.tfvars"
$envVars     = "..\$Environment\terraform.tfvars"
$planFile    = "..\$Environment\tfplan"

# Each environment gets its own provider cache and backend state pointer.
$env:TF_DATA_DIR = "..\$Environment\.terraform"

function Invoke-Init {
    Write-Host "==> init  $Account/$Environment" -ForegroundColor Cyan
    terraform -chdir="$stackDir" init -reconfigure -backend-config="$backendCfg"
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }
}

switch ($Action) {
    'fmt' {
        terraform -chdir="$repoRoot" fmt -recursive
    }
    'init' {
        Invoke-Init
    }
    'validate' {
        Invoke-Init
        terraform -chdir="$stackDir" validate
    }
    'plan' {
        Invoke-Init
        Write-Host "==> plan  $Account/$Environment" -ForegroundColor Cyan
        terraform -chdir="$stackDir" plan `
            -var-file="$accountVars" `
            -var-file="$envVars" `
            -out="$planFile"
    }
    'apply' {
        # Applies the saved plan, so what you reviewed is exactly what runs.
        if (-not (Test-Path (Join-Path $envDir 'tfplan'))) {
            throw "No saved plan. Run: .\scripts\tf.ps1 $Account $Environment plan"
        }
        Write-Host "==> apply $Account/$Environment" -ForegroundColor Yellow
        terraform -chdir="$stackDir" apply "$planFile"
    }
    'destroy' {
        Invoke-Init
        Write-Host "==> DESTROY $Account/$Environment" -ForegroundColor Red
        terraform -chdir="$stackDir" destroy `
            -var-file="$accountVars" `
            -var-file="$envVars"
    }
    'output' {
        terraform -chdir="$stackDir" output
    }
}
