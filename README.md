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

A reference implementation showing how to integrate security tooling into a Flutter CI/CD pipeline. The repo contains a minimal Flutter hello-world app (`hello_app`) and a GitHub Actions pipeline that demonstrates practical security measures for mobile app development. See [zephyr-appsec-lab](https://github.com/mmmaction/zephyr-appsec-lab) for the embedded firmware counterpart.

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
| **SAST · Semgrep** | Pattern-based security analysis (Dart/Flutter rules) | Semgrep (`config: auto`) |
| **Scan · osv-scanner** | Dart/pub CVE scan — **primary CVE gate** | osv-scanner (OSV database) |
| **Scan · trivy** | CVE scan via SBOM (documented gap) + SARIF → GitHub Security tab | Trivy |
| **Scan · license_finder** | Dart/pub license compliance (`unknown` = package has no LICENSE file in pub cache) | `license_finder` (Pivotal) |
| **Scan · Gitleaks** | Secret scanning (full git history) | Gitleaks |
| **Package** | Archive SBOM + build artifacts for audit trail | GitHub Actions artifacts (365-day retention) |

### SBOM Flow

```
Build stage
  └─ Trivy generates SBOM (CycloneDX JSON)
        │
        ▼  (all 5 run in parallel after build + test)
  ┌───────────────────────────────────────────────────────────────────────┐
  │  sast-semgrep        Semgrep pattern-based SAST (source)              │
  │  scan-osv            osv-scanner Dart/pub CVE scan (lockfile)         │
  │  scan-trivy          Trivy SBOM vulnerability scan (documented gap)   │
  │  scan-license-finder license_finder Dart/pub license report           │
  │  scan-gitleaks       Gitleaks secret scanning (full git history)      │
  └───────────────────────────────────────────────────────────────────────┘
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
| **Trivy** (sbom scan) | 0 | — | ❌ No Dart/pub CVE coverage — GHSA-vm9r-h74p-hg97 not in Trivy pub DB. Also no license data (`-` / Not scanned). Kept for SARIF upload to GitHub Security tab. **Not a security gate for Dart/pub.** |
| **Dependency-Track** | 0 | — | ❌ Advisory not in NVD/OSS Index with a matching `pkg:pub` PURL. Processing confirmed complete (42 components ingested). Same gap as Trivy; will self-update when NVD/OSS Index propagates the advisory. |
| **Snyk** | not tested | — | Not tested in this lab (requires account + `snyk auth`). Snyk maintains its own **proprietary, closed vulnerability database** — this is its core differentiator and not publicly auditable. CLI is open source (Apache 2.0) but is just a client to Snyk's backend. Limited free tier for open-source; paid subscription required for private repos and team features. Widely adopted in enterprise environments; worth evaluating if a commercial SLA and unified multi-language dashboard are required. |

**Key finding:** Both osv-scanner and grype detect `GHSA-vm9r-h74p-hg97` — but from different databases (OSV vs GitHub Advisories). Trivy and Dependency-Track both miss it due to NVD/OSS Index propagation lag for Dart/pub advisories. **osv-scanner remains the recommended gate** as it has first-class Dart/pub coverage; grype is a good secondary check.

The tools are kept in the pipeline for distinct reasons:
- **osv-scanner** → Dart/pub CVE detection (primary security gate)
- **Trivy** → SARIF upload to GitHub Security tab for comparison; no pub CVE or license coverage
- **license_finder** → Dart/pub license compliance; `unknown` entries mean the package has no LICENSE file in its pub cache dir (package metadata quality issue)
- **Dependency-Track** → continuous re-scanning without a new build; catches new CVEs for already-shipped versions

### Notable osv-scanner findings

| Advisory | CVSS | Package | Version | Description |
|---|---|---|---|---|
| [GHSA-vm9r-h74p-hg97](https://osv.dev/GHSA-vm9r-h74p-hg97) | 7.5 (High) | `jose` | 0.3.5 | JWT token forgery via attacker-controlled JWK in JOSE header — fix: `^0.3.5+1` |

> **Note:** `jose 0.3.5` is intentionally pinned in `pubspec.yaml` as a demo finding. See [Demo Findings](#demo-findings) above.

---

## SAST Comparison (lab results — Flutter/Dart)

> **Scan date: 2026-05-08.** Findings reflect the demo hello_app codebase. Real-world apps with auth, crypto, or network code will produce more findings.

| Tool | Findings | Type | Notes |
|---|---|---|---|
| `flutter analyze` | — | Semantic (AST) | Dart's native analyzer. First-class Dart support. Security lint rules via `flutter_lints`. Runs in Lint stage as fast-fail gate — not a separate SAST job. |
| **Semgrep** | **0** | Pattern SAST | `config: auto` selects Dart/Flutter community rules. Sparse Dart ruleset — minimal findings on typical Flutter code. `continue-on-error`. |
| ~~CodeQL~~ | ~~N/A~~ | ~~Dataflow SAST~~ | ❌ CodeQL does not support Dart — removed from pipeline. Supported languages: cpp, csharp, go, java, javascript, python, ruby, swift. |

**Key finding:** 0 findings is expected for the minimal demo code. `flutter analyze` remains the primary semantic quality gate; Semgrep adds lightweight security pattern matching on top.

---

## Local Development

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

### SCA – License Check (license_finder)

```bash
# Install (Ruby pre-installed on macOS/Linux)
gem install license_finder

# Run from hello_app directory (needs flutter pub get first)
cd hello_app && flutter pub get
export PUB_CACHE="$HOME/.pub-cache"
license_finder report --format=csv
# 'unknown' = package has no LICENSE file in pub cache dir (package metadata gap)
```

### SCA – License Check (Trivy — documented gap)

```bash
# NOTE: Trivy reports '-' (Not scanned) for pub packages — no pub license support.
trivy sbom --scanners license sbom.cdx.json
```

### Secret Scanning (Gitleaks)

```bash
# Scan full git history
gitleaks detect --source . -v
```

---

## Security Tools Used

| Tool | Stage | Type |
|---|---|---|
| `flutter analyze` | Lint | SAST / linting |
| `dart format --set-exit-if-changed` | Lint | Formatting |
| `dart_code_metrics` | Lint | Extended lint rules (`continue-on-error`) |
| Trivy | Build | SBOM generation (CycloneDX JSON) |
| Semgrep | SAST · Semgrep | Pattern-based security analysis (`config: auto`, `continue-on-error`) |
| osv-scanner | Scan · osv-scanner | Dart/pub vulnerability scan (OSV database) |
| Trivy | Scan · trivy | CVE scan via SBOM + SARIF → GitHub Security tab (no pub coverage — documented) |
| license_finder | Scan · license-finder | Dart/pub license compliance (`unknown` = missing LICENSE file in pub cache) |
| Gitleaks | Scan · Gitleaks | Secret scanning (full git history) |


