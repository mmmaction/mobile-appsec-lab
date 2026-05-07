// ============================================================
// DEMO FILE – INTENTIONAL GITLEAKS FINDING
// ============================================================
// This file intentionally contains fake credentials to
// demonstrate how Gitleaks detects secrets in source code.
//
// These are NOT real credentials. Do NOT use real secrets
// in source code – use environment variables or a secrets
// manager (e.g. GitHub Actions secrets, HashiCorp Vault).
// ============================================================

// ignore_for_file: unused_field

class DemoApiConfig {
  // DEMO: hardcoded API key – Gitleaks will flag this
  // In production: load from environment / secure vault
  static const String apiKey = 'AKIAIOSFODNN7DEMOKEY';
  static const String apiSecret = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYDEMOKEY1';

  // DEMO: GitHub Personal Access Token format – also caught by Gitleaks
  // In production: use GitHub Actions secrets (${{ secrets.MY_TOKEN }})
  static const String githubToken = 'ghp_DemoFakeTokenForGitleaksDemo1234567';
}
