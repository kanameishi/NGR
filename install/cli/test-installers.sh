#!/usr/bin/env bash
# Common regressions use a disposable fixture. An optional library enables the
# enclosing product's installed-interface check without replacing that package.
set -euo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$root_dir/install/cli/r.sh"
rscript_path="$(resolve_rscript)"
"$rscript_path" --vanilla "$root_dir/install/cli/testManager.R" "$root_dir"
"$rscript_path" --vanilla "$root_dir/install/cli/testManager.R" "$root_dir" --native
"$rscript_path" --vanilla "$root_dir/install/cli/testRegression.R" "$root_dir"
"$rscript_path" --vanilla "$root_dir/install/cli/testWrapper.R" "$root_dir/install"
"$rscript_path" --vanilla "$root_dir/install/cli/testPreflight.R" "$root_dir/install"
"$rscript_path" --vanilla "$root_dir/install/cli/testDependencies.R" "$root_dir/install"
"$rscript_path" --vanilla "$root_dir/install/cli/testConsole.R" "$root_dir/install"
if [[ $# -gt 0 ]]; then "$rscript_path" --vanilla "$root_dir/install/cli/testProduct.R" "$root_dir" "$1"; fi
