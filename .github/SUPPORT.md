# Support

Thank you for using the Recipe Database! This document provides resources to
help you get support.

## Documentation

Before asking for help, please check our documentation:

### Primary Documentation

- **[README.md](../README.md)** - Complete feature overview and setup
  instructions
- **[CLAUDE.md](../CLAUDE.md)** - Development commands, database architecture,
  and developer guide
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines and
  development workflow
- **[SECURITY.md](SECURITY.md)** - Security features, best practices, and
  vulnerability reporting

### Detailed Documentation

- **[docs/setup.md](../docs/setup.md)** - Detailed installation instructions
- **[docs/operations.md](../docs/operations.md)** - Day-to-day management
  procedures
- **[docs/troubleshooting.md](../docs/troubleshooting.md)** - Common issues and
  solutions
- **[monitoring/README.md](../monitoring/README.md)** - Monitoring setup and
  configuration

### Code Examples

- **[.env.example](../.env.example)** - Configuration examples
- **[k8s/](../k8s/)** - Kubernetes deployment configurations
- **[db/fixtures/](../db/fixtures/)** - Sample data and test fixtures

## Getting Help

### 1. Search Existing Resources

Before creating a new issue, please search:

- [Existing Issues](https://github.com/Recipe-Web-App/recipe-database/issues) -
  Someone may have already asked
- [Closed Issues](https://github.com/Recipe-Web-App/recipe-database/issues?q=is%3Aissue+is%3Aclosed) -
  Your question may already be answered
- [Discussions](https://github.com/Recipe-Web-App/recipe-database/discussions) -
  Community Q&A

### 2. GitHub Discussions (Recommended for Questions)

For general questions, use
[GitHub Discussions](https://github.com/Recipe-Web-App/recipe-database/discussions):

**When to use Discussions:**

- "How do I...?" questions
- Database schema design questions
- Configuration help
- Best practice advice
- PostgreSQL optimization questions
- Kubernetes deployment questions
- Troubleshooting (non-bug)

**Categories:**

- **Q&A** - Ask questions and get answers
- **Ideas** - Share feature ideas and schema proposals
- **Show and Tell** - Share your implementations and use cases
- **General** - Everything else

### 3. GitHub Issues (For Bugs and Features)

Use
[GitHub Issues](https://github.com/Recipe-Web-App/recipe-database/issues/new/choose)
for:

- Bug reports (schema issues, query errors, deployment problems)
- Feature requests (new tables, functions, monitoring features)
- Performance issues (slow queries, indexing problems)
- Documentation problems
- Security vulnerabilities (low severity - use Security Advisories for critical)

**Issue Templates:**

- **Bug Report** - Report unexpected behavior
- **Feature Request** - Suggest new functionality
- **Performance Issue** - Report database or query performance problems
- **Documentation** - Documentation improvements
- **Security Vulnerability** - Low-severity security issues
- **Task** - Track development tasks

### 4. Security Issues

**IMPORTANT:** For security vulnerabilities, use:

- [GitHub Security Advisories](https://github.com/Recipe-Web-App/recipe-database/security/advisories/new)
  (private)
- See [SECURITY.md](SECURITY.md) for details

**Never report security issues publicly through issues or discussions.**

## Common Questions

### Setup and Configuration

**Q: How do I get started?** A: See the Quick Start Workflow section in
[CLAUDE.md](../CLAUDE.md#quick-start-workflow)

**Q: What are the prerequisites?** A: You need Kubernetes (minikube for local),
kubectl, Docker, PostgreSQL client tools, and Python 3.9+. See
[CLAUDE.md](../CLAUDE.md#prerequisites)

**Q: How do I deploy to Kubernetes?** A: Run
`./scripts/containerManagement/deploy-container.sh` followed by
`./scripts/dbManagement/load-schema.sh`. See
[CLAUDE.md](../CLAUDE.md#quick-start-workflow)

**Q: How do I load test data?** A: Run
`./scripts/dbManagement/load-test-fixtures.sh` after loading the schema

### Database Operations

**Q: How do I connect to the database?** A: Use
`./scripts/dbManagement/db-connect.sh` or port-forward with
`kubectl port-forward -n recipe-database svc/recipe-database-service 5432:5432`

**Q: How do I backup the database?** A: Use
`./scripts/dbManagement/backup-db.sh` to create a backup

**Q: How do I modify the schema?** A: Create new SQL files in `db/init/schema/`
with proper numbering, test locally, then submit a PR. See
[CONTRIBUTING.md](CONTRIBUTING.md#database-specific-guidelines)

**Q: What database user should I use?** A: For application access use the
configured app user, for admin use recipe_admin. See `db/init/users/` for role
templates

### Monitoring and Observability

**Q: How do I access metrics?** A: Deploy supporting services with
`./scripts/containerManagement/deploy-supporting-services.sh`, then port-forward
the postgres-exporter service on port 9187

**Q: Where are the Grafana dashboards?** A: Pre-configured dashboards are in
`monitoring/grafana-dashboards/`. Import them into your Grafana instance

**Q: How do I check database health?** A: Use
`./scripts/containerManagement/get-container-status.sh` and check the metrics at
`http://localhost:9187/metrics` after port-forwarding

### Python Data Processing

**Q: How do I import nutritional data?** A: Use
`./scripts/dbManagement/import-nutritional-data.sh` or run the Python importer
directly. See
[CLAUDE.md](../CLAUDE.md#python-development-nutritional-data-importer)

**Q: What CSV format is expected?** A: OpenFoodFacts CSV format. See
`python/nutritional_data_importer/` for details

**Q: How do I run Python tests?** A: `cd python && pytest` - see
[CONTRIBUTING.md](CONTRIBUTING.md#python-code-testing)

### Troubleshooting

**Q: Container fails to start?**

- Check logs: `kubectl logs -n recipe-database deployment/recipe-database`
- Verify PVC exists and is bound
- Check ConfigMaps and Secrets are created
- Review [docs/troubleshooting.md](../docs/troubleshooting.md)

**Q: Schema loading fails?**

- Ensure database is running and accessible
- Check SQL syntax in schema files
- Review logs for specific errors
- Try loading files individually to isolate the issue

**Q: Performance issues with queries?**

- Use `EXPLAIN ANALYZE` to check query plans
- Check if indexes are being used
- Review slow query log
- See [Performance Issue Template](.github/ISSUE_TEMPLATE/performance_issue.yml)

**Q: Monitoring not working?**

- Ensure monitoring user is created:
  `./scripts/dbManagement/setup-monitoring-user.sh`
- Check postgres-exporter logs
- Verify ServiceMonitor is created
- See [monitoring/README.md](../monitoring/README.md)

### Development

**Q: How do I contribute?** A: See [CONTRIBUTING.md](CONTRIBUTING.md) for
complete guidelines

**Q: How do I run tests?** A: `cd python && pytest` for Python tests. SQL
validation is done via SQLFluff. See [CONTRIBUTING.md](CONTRIBUTING.md#testing)

**Q: What's the database schema structure?** A: See
[CLAUDE.md](../CLAUDE.md#database-schema-structure) for schema organization and
[README.md](../README.md#database-architecture) for entity relationships

**Q: How do I add a new database function?** A: Create a `.sql` file in
`db/init/functions/`, test it, then submit a PR. See
[CONTRIBUTING.md](CONTRIBUTING.md#database-specific-guidelines)

## Response Times

We aim to:

- Acknowledge issues/discussions within 48 hours
- Respond to questions within 1 week
- Fix critical bugs as priority
- Review PRs within 1-2 weeks

Note: This is a community project. Response times may vary.

## Commercial Support

This is an open-source project. Commercial support is not currently available.

## Community Guidelines

When asking for help:

- **Be specific** - Include exact error messages, PostgreSQL version, Kubernetes
  version
- **Provide context** - What were you trying to do? What happened instead?
- **Include details** - Environment, deployment method, relevant logs, SQL
  queries
- **Be patient** - Maintainers and community volunteers help in their free time
- **Be respectful** - Follow the [Code of Conduct](CODE_OF_CONDUCT.md)
- **Search first** - Check if your question was already answered
- **Give back** - Help others when you can

## Bug Report Best Practices

When reporting bugs, include:

- PostgreSQL version (e.g., 15.4)
- Kubernetes version
- Python version (for data processing issues)
- Deployment environment (minikube/cloud K8s)
- Exact error messages and stack traces
- Steps to reproduce
- Expected vs actual behavior
- Relevant configuration (redact secrets!)
- Database logs, container logs (redact sensitive info!)
- Query plans for performance issues

Use the [Bug Report Template](.github/ISSUE_TEMPLATE/bug_report.yml) - it helps
ensure you provide all needed information.

## Additional Resources

### PostgreSQL Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/index.html)
- [PostgreSQL Performance](https://www.postgresql.org/docs/15/performance-tips.html)
- [PostgreSQL Security](https://www.postgresql.org/docs/15/security.html)

### Kubernetes Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

### Monitoring Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)

### Python Resources

- [Python Documentation](https://docs.python.org/3/)
- [pytest Documentation](https://docs.pytest.org/)
- [psycopg2 Documentation](https://www.psycopg.org/docs/)

## Still Need Help

If you can't find an answer:

1. Check
   [Discussions](https://github.com/Recipe-Web-App/recipe-database/discussions)
2. Ask a new question in
   [Q&A](https://github.com/Recipe-Web-App/recipe-database/discussions/new?category=q-a)
3. For bugs, create an
   [Issue](https://github.com/Recipe-Web-App/recipe-database/issues/new/choose)

We're here to help!
