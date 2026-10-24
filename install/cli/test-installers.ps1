#Requires -Version 5.1
# Run natively on Windows. All destinations are temporary; PATH is not changed.
param([string]$Library = '')
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).ProviderPath
. (Join-Path $PSScriptRoot 'r.ps1')
$Rscript = Resolve-Rscript
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testManager.R') $Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testWrapper.R') (Join-Path $Root 'install')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testRegression.R') $Root
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testPreflight.R') (Join-Path $Root 'install')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testDependencies.R') (Join-Path $Root 'install')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Rscript --vanilla (Join-Path $PSScriptRoot 'testConsole.R') (Join-Path $Root 'install')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($Library) {
    & $Rscript --vanilla (Join-Path $PSScriptRoot 'testProduct.R') $Root $Library
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
