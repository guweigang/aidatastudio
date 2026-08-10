# CI workflow structure

The GitHub Actions configuration is split into three layers:

1. `.github/workflows/build.yml` owns manual inputs, permissions, concurrency,
   platform selection, and cross-platform job ordering.
2. Reusable workflows in `.github/workflows/_*.yml` own platform or publishing
   steps.
3. Scripts in `scripts/ci/<platform>/` own non-trivial shell implementation.

Keep orchestration in YAML and move command blocks that are long enough to test
independently into scripts. Pass GitHub expression values to scripts through
explicit environment variables instead of embedding `${{ ... }}` expressions in
script files.

The macOS scripts are POSIX shell scripts and can be syntax-checked with:

```sh
for script in scripts/ci/macos/*.sh; do sh -n "$script"; done
```

The Windows scripts are PowerShell scripts. From PowerShell, parse all scripts
without running them with:

```powershell
Get-ChildItem scripts/ci/windows/*.ps1 | ForEach-Object {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $_.FullName,
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors) { throw ($parseErrors | Out-String) }
}
```

Reusable workflow files must remain directly under `.github/workflows`; GitHub
does not discover reusable workflows from nested directories.
