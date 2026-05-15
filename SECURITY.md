# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in Value Compass, please report it responsibly:

### How to Report

- **GitHub Security Advisory**: Use GitHub's built-in [private vulnerability reporting](https://github.com/yashasg/value-compass/security/advisories/new) feature
- **Email**: Contact the maintainer directly with the subject line `[SECURITY] Value Compass Vulnerability Report`

**Please do not** open public GitHub issues for security vulnerabilities until they have been reviewed and addressed.

### What to Include

- A clear description of the vulnerability
- Steps to reproduce the issue
- The potential impact (e.g., data exposure, unauthorized access)
- Any suggested mitigations or fixes (if known)

### Response Timeline

- We will acknowledge your report within **48 hours**
- We will provide an estimated resolution timeline within **5 business days**
- Security patches will be released as soon as possible

### Scope

| In Scope | Out of Scope |
|----------|--------------|
| Server-side vulnerabilities (FastAPI backend) | Issues in third-party dependencies (report upstream) |
| Client-side vulnerabilities (iOS app) | User device configuration issues |
| Data handling / privacy concerns | Social engineering attacks |
| Authentication / authorization bypasses | Denial of service |

### Disclosure Policy

We follow **coordinated vulnerability disclosure**. Please give us reasonable time to address the issue before any public disclosure.

Thank you for helping keep Value Compass secure!