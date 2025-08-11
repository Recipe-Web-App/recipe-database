# Security Policy

## Supported Versions

We take security seriously and provide security updates for the following
versions:

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Security Features

### Database Security

#### Access Control

- **Role-based access control (RBAC)**: Separate roles for admin, recipe
  managers, and regular users
- **Principle of least privilege**: Each user role has minimal required
  permissions
- **Row-level security (RLS)**: Data isolation based on user ownership and
  privacy settings
- **Monitoring user isolation**: Dedicated read-only user for metrics collection

#### Data Protection

- **Encrypted connections**: TLS encryption for all database connections
- **Password hashing**: Secure password storage using industry-standard hashing
- **Audit logging**: Comprehensive logging of all database modifications
- **Data sanitization**: Input validation and SQL injection prevention

#### Network Security

- **Private networking**: Database accessible only within Kubernetes cluster by
  default
- **Network policies**: Kubernetes network policies restrict inter-pod
  communication
- **Port security**: Only necessary ports exposed (5432 for PostgreSQL, 9187 for
  metrics)
- **Service isolation**: Monitoring services isolated from main database
  operations

### Container Security

#### Image Security

- **Base image**: Official PostgreSQL images with security updates
- **Minimal attack surface**: Only necessary packages installed
- **Regular updates**: Automated dependency updates and security patches
- **Image scanning**: Container images scanned for known vulnerabilities

#### Runtime Security

- **Non-root execution**: Containers run as non-privileged users where possible
- **Resource limits**: CPU and memory limits prevent resource exhaustion attacks
- **Health checks**: Proper liveness and readiness probes
- **Secret management**: Sensitive data stored in Kubernetes secrets, not
  environment variables

### Kubernetes Security

#### RBAC and Access Control

- **Service accounts**: Dedicated service accounts with minimal permissions
- **RBAC policies**: Fine-grained role-based access control
- **Namespace isolation**: Resources isolated within dedicated namespace
- **Secret management**: Encrypted secret storage with restricted access

#### Network Security Policies

- **Network policies**: Traffic restrictions between pods and namespaces
- **Service mesh ready**: Compatible with Istio/Linkerd for advanced security
- **TLS termination**: Proper TLS configuration for external access
- **Ingress security**: Security headers and rate limiting where applicable

## Security Best Practices

### Deployment Security

#### Production Checklist

- [ ] Change all default passwords and credentials
- [ ] Enable TLS for all database connections
- [ ] Configure network policies to restrict traffic
- [ ] Set up monitoring and alerting for security events
- [ ] Regular backup and disaster recovery testing
- [ ] Keep all components updated with security patches

#### Environment Variables

Never commit sensitive information to version control:

```bash
# ❌ BAD - Don't do this
POSTGRES_PASSWORD=hardcoded_password

# ✅ GOOD - Use environment variables
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# ✅ BETTER - Use Kubernetes secrets
valueFrom:
  secretKeyRef:
    name: recipe-database-secret
    key: POSTGRES_PASSWORD
```

#### Secret Management

```yaml
# Use Kubernetes secrets for sensitive data
apiVersion: v1
kind: Secret
metadata:
  name: recipe-database-secret
  namespace: recipe-database
type: Opaque
data:
  POSTGRES_PASSWORD: <base64-encoded-password>
  DB_MAINT_PASSWORD: <base64-encoded-password>
  POSTGRES_EXPORTER_DATA_SOURCE_NAME: <base64-encoded-connection-string>
```

### Database Security Configuration

#### User Management

```sql
-- Create users with minimal privileges
CREATE USER recipe_app WITH PASSWORD 'secure_password'; <!-- pragma: allowlist secret -->
GRANT CONNECT ON DATABASE recipe_database TO recipe_app;
GRANT USAGE ON SCHEMA recipe_manager TO recipe_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA recipe_manager TO recipe_app;

-- Monitoring user with read-only access
CREATE USER postgres_exporter WITH PASSWORD 'monitoring_password';  <!-- pragma: allowlist secret -->
GRANT CONNECT ON DATABASE recipe_database TO postgres_exporter;
GRANT SELECT ON pg_stat_database TO postgres_exporter;
-- ... (see monitoring user template for complete permissions)
```

#### Row-Level Security

```sql
-- Enable RLS for user data privacy
ALTER TABLE recipe_manager.recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_privacy_policy ON recipe_manager.recipes
FOR ALL TO recipe_app
USING (
  user_id = current_setting('app.current_user_id')::uuid OR
  recipe_id IN (
    SELECT recipe_id FROM recipe_manager.recipes
    WHERE privacy_level = 'PUBLIC'
  )
);
```

### Monitoring Security

#### Metrics Security

- Monitoring user has read-only access to system tables only
- Custom metrics queries are vetted for security implications
- Metrics endpoints protected by authentication in production
- No sensitive data exposed in metric labels or values

#### Alerting Security

```yaml
# Example: Alert on potential security issues
- alert: PostgreSQLUnauthorizedConnections
  expr: increase(pg_stat_database_xact_rollback[5m]) > 10
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High rollback rate may indicate attack attempts"
```

## Reporting Security Vulnerabilities

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by email to:
**<security@yourcompany.com>** (replace with your actual security contact)

Include the following information:

- Type of issue (e.g. buffer overflow, SQL injection, cross-site scripting,
  etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit the issue

### Response Timeline

- **Within 24 hours**: Acknowledgment of your report
- **Within 7 days**: Initial assessment and severity classification
- **Within 30 days**: Resolution plan or mitigation steps
- **Within 90 days**: Public disclosure (after fix is available)

### Disclosure Policy

- Security researchers are acknowledged (unless they prefer to remain anonymous)
- We follow responsible disclosure practices
- Public disclosure only after fixes are available and users have time to update
- Security advisories published through GitHub Security Advisories

## Security Audit Trail

### Recent Security Reviews

| Date    | Type             | Scope                | Status      |
| ------- | ---------------- | -------------------- | ----------- |
| 2024-01 | Internal Review  | Database permissions | ✅ Complete |
| 2024-01 | Dependency Audit | Python packages      | ✅ Complete |
| 2024-01 | Container Scan   | Docker images        | ✅ Complete |

### Security Updates Log

- **2024-01-15**: Updated PostgreSQL to version 15.4 (security patches)
- **2024-01-10**: Updated Python dependencies (vulnerability fixes)
- **2024-01-05**: Enhanced monitoring user permissions (principle of least
  privilege)

## Security Compliance

### Standards Compliance

This project follows industry security standards:

- **OWASP Top 10**: Protection against common web application vulnerabilities
- **CIS Benchmarks**: Container and Kubernetes security benchmarks
- **NIST Framework**: Cybersecurity framework alignment
- **SOC 2**: Control framework compliance considerations

### Compliance Checklist

#### Data Protection Compliance

- [ ] Data encrypted in transit (TLS)
- [ ] Data encrypted at rest (Kubernetes secrets, PVC encryption)
- [ ] Access logging enabled
- [ ] Data retention policies implemented
- [ ] Backup encryption enabled

#### Access Control Compliance

- [ ] Multi-factor authentication available
- [ ] Role-based access control implemented
- [ ] Regular access reviews conducted
- [ ] Privileged access monitoring
- [ ] Account lockout policies

#### Security Monitoring Compliance

- [ ] Security event logging
- [ ] Anomaly detection
- [ ] Incident response procedures
- [ ] Regular security assessments
- [ ] Vulnerability management program

## Secure Configuration Examples

### Production Deployment

```yaml
# Secure deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recipe-database
  namespace: recipe-database
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 70 # postgres user
        fsGroup: 70
      containers:
        - name: recipe-database
          image: postgres:15.4
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false # PostgreSQL needs write access
            capabilities:
              drop:
                - ALL
          resources:
            limits:
              memory: "1Gi"
              cpu: "1000m"
            requests:
              memory: "512Mi"
              cpu: "500m"
```

### Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: recipe-database-network-policy
  namespace: recipe-database
spec:
  podSelector:
    matchLabels:
      app: recipe-database
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: application-namespace
      ports:
        - protocol: TCP
          port: 5432
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring-namespace
      ports:
        - protocol: TCP
          port: 9187
  egress:
    - {} # Allow all egress (can be restricted further)
```

## Security Tools and Dependencies

### Automated Security Scanning

- **Container Scanning**: Integrated with container registries
- **Dependency Scanning**: Automated vulnerability scanning for Python packages
- **Static Analysis**: Code quality and security analysis
- **Infrastructure Scanning**: Kubernetes configuration security scanning

### Security Dependencies

```txt
# Python security dependencies
bandit>=1.7.0       # Security linting
safety>=2.0.0       # Dependency vulnerability checking
```

### Security Monitoring

- **Database Activity Monitoring**: Track unusual database access patterns
- **Resource Monitoring**: Detect resource exhaustion attacks
- **Network Monitoring**: Monitor for suspicious network activity
- **Audit Logging**: Comprehensive audit trail for all operations

## Emergency Response

### Security Incident Response

1. **Immediate Response**
   - Isolate affected systems
   - Preserve evidence
   - Assess impact and scope
   - Notify stakeholders

2. **Investigation**
   - Analyze logs and evidence
   - Determine root cause
   - Document findings
   - Develop remediation plan

3. **Recovery**
   - Apply fixes and patches
   - Restore from clean backups if necessary
   - Implement additional controls
   - Monitor for recurring issues

4. **Post-Incident**
   - Update security procedures
   - Conduct lessons learned session
   - Update documentation
   - Implement preventive measures

### Emergency Contacts

- **Security Team**: <security@yourcompany.com>
- **DevOps Team**: <devops@yourcompany.com>
- **Management**: <management@yourcompany.com>

## Questions

For security-related questions that are not sensitive:

- Create a GitHub discussion with the 'security' label
- Review this security policy and existing documentation
- Check with your security team or organization's security policies

For sensitive security matters, always use the security email address provided
above.

---

**Security is everyone's responsibility. Thank you for helping keep Recipe
Database secure!** 🔒
