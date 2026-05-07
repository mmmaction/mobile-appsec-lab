# mobile-appsec-lab

A reference implementation showing how to integrate security tooling into a Flutter CI/CD pipeline. The repo contains a minimal Flutter hello-world app (`hello_app`) and a GitHub Actions pipeline that demonstrates practical security measures for mobile app development.

---

## Purpose

This repo is an **example** for CI/CD security recommendations for Flutter mobile apps (Android, iOS, Web). It is used to:

- Demonstrate which security tools fit where in a pipeline
- Show how an SBOM (Software Bill of Materials) flows from build to verification to archival
- Serve as a reference aligned with the **CRA Annex I** requirement for SBOM delivery alongside software products

---

## Pipeline Stages

The GitHub Actions pipeline (`.github/workflows/pipeline.yml`) is structured according to an internal CI/CD reference pipeline recommendation for Flutter mobile apps:

| Stage | What it does | Key tools |
|---|---|---|
| **Lint** | Code style & static analysis (fast-fail) | `flutter analyze`, `dart format --check`, `dart_code_metrics` |
| **Build + SBOM** | Compile app for Web & Android, generate SBOM | `flutter build`, Trivy (CycloneDX JSON) |
| **Unit Test** | Run tests with code coverage | `flutter test --coverage`, lcov |
| **SAST / SCA** | Static analysis + vulnerability/license/secret scan via SBOM | Semgrep, Trivy SCA, Gitleaks |
| **Package** | Archive SBOM + build artifacts for audit trail | GitHub Actions artifacts (365-day retention) |

### SBOM Flow

```
Build stage
  └─ Trivy generates SBOM (CycloneDX JSON)
        │
        ▼
  SAST/SCA stage consumes SBOM
    ├─ Trivy: vulnerability scan
    ├─ Trivy: license compliance check
    └─ Gitleaks: secret scanning
        │
        ▼
  Package stage archives SBOM alongside build artifacts
```

### Pipeline Triggers

| Trigger | When |
|---|---|
| Push to `main` | On every commit |
| Pull Request to `main` | On every PR |
| Scheduled (cron) | Every Monday 07:00 UTC — Trivy re-scan for new CVEs |
| Manual | Via GitHub Actions → "Run workflow" button |


