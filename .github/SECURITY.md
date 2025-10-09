# Security Policy

## Supported Versions

We release security updates for the following versions:

| Version  | Supported          |
| -------- | ------------------ |
| latest   | :white_check_mark: |
| < latest | :x:                |

We recommend always running the latest version for security patches.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

### Private Reporting (Preferred)

Report security vulnerabilities using
[GitHub Security Advisories](https://github.com/Recipe-Web-App/recipe-database/security/advisories/new).

This allows us to:

- Discuss the vulnerability privately
- Develop and test a fix
- Coordinate disclosure timing
- Issue a CVE if necessary

### What to Include

When reporting a vulnerability, please include:

1. **Description** - Clear description of the vulnerability
2. **Impact** - What can an attacker achieve?
3. **Reproduction Steps** - Step-by-step instructions to reproduce
4. **Affected Components** - Which parts of the database are affected (schema,
   functions, K8s manifests, etc.)
5. **Suggested Fix** - If you have ideas for remediation
6. **Environment** - PostgreSQL version, K8s version, configuration details
7. **Proof of Concept** - SQL queries or configuration demonstrating the issue
   (if safe to share)

### Example Report

```text
Title: SQL Injection in recipe_search Function

Description: The recipe_search function does not properly sanitize user input...

Impact: An attacker can execute arbitrary SQL commands and access/modify database data...

Steps to Reproduce:
1. Call recipe_manager.recipe_search() with payload: "'; DROP TABLE users; --"
2. Function executes the malicious SQL
3. Data loss or unauthorized access occurs

Affected: db/init/functions/recipe_search.sql line 25

Suggested Fix: Use parameterized queries and proper input validation

Environment: PostgreSQL 15.4, Kubernetes 1.28
```

## Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Varies by severity (critical: days, high: weeks, medium:
  months)

## Severity Levels

### Critical

- SQL injection allowing database takeover
- Privilege escalation to database superuser
- Mass data exposure or deletion
- Remote code execution in database or containers
- Kubernetes cluster compromise

### High

- SQL injection with limited scope
- Unauthorized access to sensitive user data
- Privilege escalation within application
- Container escape vulnerabilities
- Kubernetes secret exposure

### Medium

- Information disclosure (limited)
- Weak cryptography in stored data
- Missing security headers in monitoring
- Session fixation issues
- CSRF vulnerabilities in monitoring dashboards

### Low

- Verbose error messages revealing schema
- Security configuration weaknesses
- Best practice violations
- Missing security headers

## Security Features

This database implements multiple security layers:

### Database Security

- **Role-Based Access Control** - Separate roles for admin, app, monitoring
- **Row-Level Security** - User data isolation where applicable
- **Parameterized Queries** - All functions use safe query patterns
- **Input Validation** - CHECK constraints and triggers validate data
- **Audit Logging** - Comprehensive logging of database changes
- **Encrypted Connections** - TLS support for database connections

### Kubernetes Security

- **Namespace Isolation** - Dedicated namespace for database resources
- **Resource Limits** - CPU and memory constraints
- **Secret Management** - Kubernetes secrets for credentials
- **Network Policies** - Pod-to-pod communication controls (optional)
- **Security Contexts** - Non-root containers where possible
- **Image Scanning** - Regular vulnerability scans of container images

### Application Security

- **Principle of Least Privilege** - Minimal permissions for all users
- **Secure Defaults** - Security-first default configuration
- **Regular Updates** - Automated dependency updates via Dependabot
- **Code Scanning** - Automated security scans in CI/CD
- **Secret Detection** - Pre-commit hooks prevent secret commits

### Monitoring Security

- **Separate Service Account** - Dedicated monitoring user with read-only access
- **Metric Security** - No sensitive data in Prometheus metrics
- **Access Control** - Grafana dashboard authentication
- **Audit Trails** - Monitoring access logged

## Security Best Practices

### For Operators

1. **Use Strong Passwords** - Generate secure passwords for database users
2. **Enable TLS** - Always encrypt database connections in production
3. **Rotate Credentials** - Regularly rotate database passwords
4. **Monitor Logs** - Watch for suspicious patterns and failed login attempts
5. **Update Dependencies** - Keep PostgreSQL and container images current
6. **Limit Network Access** - Use Kubernetes NetworkPolicies
7. **Backup Encryption** - Encrypt database backups
8. **Secure Secrets** - Use sealed secrets or external secret management
9. **Resource Limits** - Set appropriate CPU/memory limits
10. **Regular Audits** - Periodically review database permissions and access
    logs

### For Developers

1. **Never Commit Secrets** - Use `.env` files (gitignored)
2. **Parameterized Queries** - Always use prepared statements
3. **Input Validation** - Validate all data before database insertion
4. **Schema Comments** - Document security-sensitive fields
5. **Test Security** - Include security test cases
6. **Review Dependencies** - Check Python packages for vulnerabilities
7. **Follow Standards** - Adhere to PostgreSQL security best practices
8. **Code Review** - Require reviews for database schema changes

## Security Checklist

Before deploying:

- [ ] Strong database passwords configured
- [ ] TLS/SSL configured for database connections
- [ ] Kubernetes secrets properly configured
- [ ] Database user roles follow least privilege
- [ ] Row-level security enabled where needed
- [ ] Audit logging enabled
- [ ] Backup encryption configured
- [ ] Network policies applied (optional but recommended)
- [ ] Resource limits set on pods
- [ ] Container images scanned for vulnerabilities
- [ ] Monitoring credentials secured
- [ ] No secrets in code or K8s manifests
- [ ] Security scans passed (detect-secrets, bandit, trivy)
- [ ] Database firewall rules configured

## Known Security Considerations

### Database Access

- PostgreSQL connections use password authentication
- Credentials stored in Kubernetes secrets
- Optional TLS for encrypted connections
- Connection pooling limits concurrent connections
- Failed login attempts logged

### Container Security

- Base PostgreSQL image: `postgres:15.4` (official image)
- Regular updates via Dependabot
- Image scanned with Trivy
- Non-root user in postgres-exporter container
- Read-only root filesystem where possible

### Kubernetes Configuration

- Namespace: `recipe-database`
- Service accounts with minimal permissions
- Secrets for credentials
- ConfigMaps for non-sensitive configuration
- Optional network policies for pod isolation

### Data Protection

- Sensitive user data (passwords) hashed with bcrypt
- PII fields clearly marked in schema
- Optional encryption at rest (PostgreSQL TDE)
- Backup encryption recommended
- Audit log retention policies

## Disclosure Policy

We follow **coordinated disclosure**:

1. Vulnerability reported privately
2. We confirm and develop fix
3. Fix tested and released
4. Public disclosure after fix is deployed
5. Credit given to reporter (if desired)

## Security Updates

Subscribe to:

- [GitHub Security Advisories](https://github.com/Recipe-Web-App/recipe-database/security/advisories)
- [Release Notes](https://github.com/Recipe-Web-App/recipe-database/releases)
- Watch repository for security patches

## Contact

For security concerns: Use
[GitHub Security Advisories](https://github.com/Recipe-Web-App/recipe-database/security/advisories/new)

For general questions: See [SUPPORT.md](SUPPORT.md)

## Acknowledgments

We thank security researchers who responsibly disclose vulnerabilities.
Contributors will be acknowledged (with permission) in:

- Security advisories
- Release notes
- This document

Thank you for helping keep this project secure!
