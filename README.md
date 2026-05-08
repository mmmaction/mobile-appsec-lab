# mobile-appsec-lab

<!-- CI/CD -->
![Pipeline](https://github.com/mmmaction/mobile-appsec-lab/actions/workflows/pipeline.yml/badge.svg)
<!-- Coverage (activate after adding CODECOV_TOKEN secret at codecov.io) -->
[![codecov](https://codecov.io/gh/mmmaction/mobile-appsec-lab/branch/main/graph/badge.svg)](https://codecov.io/gh/mmmaction/mobile-appsec-lab)
<!-- Security -->
[![Gitleaks](https://img.shields.io/badge/security-gitleaks-blue)](https://github.com/gitleaks/gitleaks)
[![SBOM](https://img.shields.io/badge/SBOM-CycloneDX-blue)](https://cyclonedx.org/)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/mmmaction/mobile-appsec-lab/badge)](https://scorecard.dev/viewer/?uri=github.com/mmmaction/mobile-appsec-lab)
<!-- Flutter -->
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
<!-- License -->
[![License](https://img.shields.io/github/license/mmmaction/mobile-appsec-lab)](LICENSE)

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

---

## Demo Findings

This repo intentionally contains two security findings to make the pipeline results visible and educational.

### 1. Known Vulnerability – `jose 0.3.5` (CVE-2026-34240)

**File:** `hello_app/pubspec.yaml`

The package `jose` is pinned to version `0.3.5`, which contains a **High severity** vulnerability (CVSS 7.5):

> An attacker can forge valid JWS/JWT tokens by embedding an attacker-controlled public key in the JOSE header (`jwk`). Because the vulnerable version treats header-provided keys as valid verification candidates, the signature check can be bypassed entirely.

**Detected by:** osv-scanner (same OSV database that Flutter uses internally for advisory warnings)  
**Fix:** Upgrade to `jose: ^0.3.5+1`

This demonstrates:
- How a single outdated dependency can introduce a critical auth bypass
- That `flutter pub get` itself warns about advisories — reinforcing why dependency scanning belongs in CI
- The difference between tools: osv-scanner catches this, Trivy's Pub DB may lag behind — **no single tool is complete**

---

### 2. Hardcoded Secrets – `demo_secrets.dart` (Gitleaks)

**File:** `hello_app/lib/demo_secrets.dart`

The file contains fake credentials in source code — an AWS access key and a GitHub Personal Access Token — to demonstrate secret scanning:

```dart
static const String apiKey = 'AKIAIOSFODNN7DEMOKEY';
static const String githubToken = 'ghp_DemoFakeTokenForGitleaksDemo1234567';
```

**These are not real credentials.** They follow the format of real secrets so that Gitleaks' pattern matching triggers.

**Detected by:** Gitleaks  
**Fix:** Never commit secrets to source code. Use environment variables, GitHub Actions secrets (`${{ secrets.MY_TOKEN }}`), or a secrets manager (HashiCorp Vault, AWS Secrets Manager, etc.).

This demonstrates:
- How easy it is to accidentally commit secrets
- That secret scanning catches these patterns even when the values are "obviously fake" — because the tool cannot know the difference at scan time

---

## CVE Scanner Comparison (lab results — Flutter pub dependencies)

> **Scan date: 2026-05-08.** Results reflect the vulnerability databases at that date. Re-run `osv-scanner scan --lockfile=hello_app/pubspec.lock` to get current numbers.

| Tool | CVEs found | High | Notes |
|---|---|---|---|
| **osv-scanner** | **1** | **1** | GHSA-vm9r-h74p-hg97 (`jose 0.3.5`). Same OSV database as `flutter pub get` advisory warnings. **Recommended for Dart/pub CVE gate.** |
| **grype** | **1** | **1** | GHSA-vm9r-h74p-hg97 (`jose 0.3.5`). Uses GitHub Advisory Database. Correctly reports `FIXED IN: 0.3.5+1`. |
| **Trivy** (sbom scan) | 0 | — | ❌ Limited Dart/pub ecosystem coverage — GHSA-vm9r-h74p-hg97 is not yet in Trivy's DB. Use for license compliance only. |
| **Dependency-Track** | 0 | — | ❌ Advisory not in NVD/OSS Index with a matching `pkg:pub` PURL. Processing confirmed complete (42 components ingested). Same gap as Trivy; will self-update when NVD/OSS Index propagates the advisory. |
| **Snyk** | not tested | — | Not tested in this lab (requires account + `snyk auth`). Snyk maintains its own **proprietary, closed vulnerability database** — this is its core differentiator and not publicly auditable. CLI is open source (Apache 2.0) but is just a client to Snyk's backend. Limited free tier for open-source; paid subscription required for private repos and team features. Widely adopted in enterprise environments; worth evaluating if a commercial SLA and unified multi-language dashboard are required. |

**Key finding:** Both osv-scanner and grype detect `GHSA-vm9r-h74p-hg97` — but from different databases (OSV vs GitHub Advisories). Trivy and Dependency-Track both miss it due to NVD/OSS Index propagation lag for Dart/pub advisories. **osv-scanner remains the recommended gate** as it has first-class Dart/pub coverage; grype is a good secondary check.

The three tools are kept in the pipeline for distinct reasons:
- **osv-scanner** → Dart/pub CVE detection (primary security gate)
- **Trivy** → license compliance scanning via SBOM (separate concern, not a CVE tool here)
- **Dependency-Track** → continuous re-scanning without a new build; catches new CVEs for already-shipped versions

### Notable osv-scanner findings

| Advisory | CVSS | Package | Version | Description |
|---|---|---|---|---|
| [GHSA-vm9r-h74p-hg97](https://osv.dev/GHSA-vm9r-h74p-hg97) | 7.5 (High) | `jose` | 0.3.5 | JWT token forgery via attacker-controlled JWK in JOSE header — fix: `^0.3.5+1` |

> **Note:** `jose 0.3.5` is intentionally pinned in `pubspec.yaml` as a demo finding. See [Demo Findings](#demo-findings) above.

---

## Running Locally

### Prerequisites

```bash
# Install Flutter (macOS)
brew install --cask flutter

# Install Trivy (SBOM + SCA)
brew install trivy

# Install Gitleaks (secret scanning)
brew install gitleaks
```

### Lint

```bash
cd hello_app

# Static analysis
flutter analyze --no-pub

# Formatting check
dart format --set-exit-if-changed .
```

### Build

```bash
cd hello_app

# Web
flutter build web --release

# Android (debug, no signing required)
flutter build apk --debug
```

### Unit Tests + Coverage

```bash
cd hello_app
flutter test --coverage
# Coverage report written to coverage/lcov.info
```

### SBOM Generation (Trivy)

```bash
# Run from repo root
trivy fs --format cyclonedx --output sbom.cdx.json hello_app
```

### SCA – Vulnerability Scan (via SBOM)

```bash
# Generate SBOM first (see above), then:
trivy sbom --severity CRITICAL,HIGH,MEDIUM sbom.cdx.json
```

### SCA – License Check (via SBOM)

```bash
trivy sbom --scanners license sbom.cdx.json
```

### Secret Scanning (Gitleaks)

```bash
# Scan full git history
gitleaks detect --source . -v
```

### SAST (Semgrep)

```bash
# Install semgrep
pip install semgrep

# Run with open-source rules (no account needed)
semgrep scan --config auto hello_app/lib
```

---

## Security Tools Used

| Tool | Stage | Type | Priority |
|---|---|---|---|
| `flutter analyze` | Lint | SAST / linting | Standard |
| `dart format --set-exit-if-changed` | Lint | Formatting | Standard |
| `dart_code_metrics` | Lint | Extended lint rules | Nice-to-have |
| Trivy | Build | SBOM generation (CycloneDX JSON) | **Recommended** |
| osv-scanner | SAST/SCA | Dart/pub vulnerability scan (OSV database) | **Recommended** |
| Trivy | SAST/SCA | Vulnerability + license scan via SBOM | **Recommended** |
| Gitleaks | SAST/SCA | Secret scanning | **Recommended** |
| Semgrep | SAST/SCA | SAST (open-source rules) | Nice-to-have |

> **Recommended** = security-relevant, strongly advised  
> **Nice-to-have** = security-relevant, optional (`continue-on-error: true` in pipeline)


