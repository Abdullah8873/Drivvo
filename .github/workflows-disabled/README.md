# Parked CI/CD workflows

These GitHub Actions workflows are intentionally disabled during early
development (GitHub only runs files inside `.github/workflows/`).

To re-enable later:

    git mv .github/workflows-disabled/*.yml .github/workflows/

- `ci.yml` — format check, analyze, tests, web + debug APK builds on PRs
- `release.yml` — signed release APK → GitHub Release, web → GitHub Pages
