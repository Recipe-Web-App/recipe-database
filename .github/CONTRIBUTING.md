# Contributing to Recipe Database

Welcome! We're excited that you're interested in contributing to the Recipe
Database project. This document provides guidelines and information for
contributors.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our Code of
Conduct. By participating, you are expected to uphold this code. Please report
unacceptable behavior to the project maintainers.

### Our Standards

**Positive behavior includes:**

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**

- The use of sexualized language or imagery and unwelcome sexual attention or
  advances
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a
  professional setting

## Getting Started

### Prerequisites

Before you start contributing, make sure you have:

- **Git** installed and configured
- **Docker** for containerized development
- **kubectl** and access to a Kubernetes cluster (minikube for local
  development)
- **Python 3.8+** for data processing components
- **PostgreSQL client tools** for database interaction

### Development Environment Setup

1. **Fork and Clone**

   ```bash
   git clone https://github.com/your-username/recipe-database.git
   cd recipe-database
   ```

2. **Set up Environment**

   ```bash
   cp .env.example .env
   # Edit .env with your local configuration
   ```

3. **Deploy Development Database**

   ```bash
   ./scripts/containerManagement/deploy-container.sh
   ./scripts/dbManagement/load-schema.sh
   ./scripts/dbManagement/load-test-fixtures.sh
   ```

4. **Set up Monitoring (Optional)**

   ```bash
   ./scripts/dbManagement/setup-monitoring-user.sh
   ./scripts/containerManagement/deploy-supporting-services.sh
   ```

## Development Setup

### Project Structure

```text
recipe-database/
├── db/                          # Database schema and configuration
│   ├── init/                    # Database initialization files
│   │   ├── schema/             # Schema creation scripts (numbered)
│   │   ├── functions/          # Stored procedures and functions
│   │   ├── triggers/           # Database triggers
│   │   ├── views/              # Database views
│   │   └── users/              # User creation templates
│   ├── fixtures/               # Test data
│   └── queries/                # Common queries and monitoring
├── k8s/                        # Kubernetes manifests
├── python/                     # Python data processing tools
├── scripts/                    # Management scripts
│   ├── containerManagement/   # Container lifecycle scripts
│   ├── dbManagement/          # Database operation scripts
│   └── jobHelpers/            # Kubernetes job helpers
├── monitoring/                 # Monitoring configuration
└── docs/                       # Documentation
```

### Local Development Workflow

1. **Make your changes** in a feature branch
2. **Test locally** using the development database
3. **Run quality checks** before committing
4. **Submit a pull request** with clear description

## Making Changes

### Branch Naming Convention

Use descriptive branch names with prefixes:

- `feature/add-recipe-versioning` - New features
- `fix/database-connection-timeout` - Bug fixes
- `docs/update-api-reference` - Documentation updates
- `refactor/optimize-queries` - Code refactoring
- `test/add-integration-tests` - Test additions

### Commit Message Guidelines

Follow the [Conventional Commits](https://www.conventionalcommits.org/)
specification:

```text
type(scope): description

[optional body]

[optional footer]
```

**Examples:**

```text
feat(database): add recipe versioning support

Add table and functions to track recipe revisions with
full history of changes including ingredients and steps.

Closes #123
```

```text
fix(monitoring): resolve postgres_exporter connection issue

Update connection string format to handle special characters
in passwords properly.

Fixes #456
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## Coding Standards

### SQL Guidelines

1. **Schema Files**
   - Use numbered prefixes for execution order (001*, 002*, etc.)
   - Include descriptive comments for complex logic
   - Use consistent naming conventions (snake_case)
   - Add proper constraints and indexes

2. **Functions and Procedures**
   - Include comprehensive parameter documentation
   - Use proper error handling with exceptions
   - Return meaningful error messages
   - Add performance considerations in comments

3. **Example SQL Style**

   ```sql
   -- db/init/functions/example_function.sql
   CREATE OR REPLACE FUNCTION recipe_manager.example_function(
     p_user_id BIGINT,
     p_recipe_title VARCHAR(255)
   ) RETURNS TABLE (
     recipe_id BIGINT,
     created_at TIMESTAMPTZ
   ) LANGUAGE plpgsql AS $$
   DECLARE
     v_count INTEGER;
   BEGIN
     -- Validate input parameters
     IF p_user_id IS NULL OR p_user_id <= 0 THEN
       RAISE EXCEPTION 'Invalid user_id: %', p_user_id;
     END IF;

     -- Main logic with clear comments
     RETURN QUERY
     SELECT r.recipe_id, r.created_at
     FROM recipe_manager.recipes r
     WHERE r.user_id = p_user_id
       AND r.title ILIKE '%' || p_recipe_title || '%'
     ORDER BY r.created_at DESC;
   END;
   $$;
   ```

### Python Guidelines

1. **Code Style**
   - Follow [PEP 8](https://pep8.org/) style guidelines
   - Use type hints for function parameters and returns
   - Maximum line length of 88 characters (Black formatter)
   - Use descriptive variable and function names

2. **Documentation**
   - Include docstrings for all functions and classes
   - Use Google-style docstrings
   - Add inline comments for complex logic

3. **Example Python Style**

   ```python
   def import_nutritional_data(
       csv_file_path: str,
       batch_size: int = 1000,
       validate_data: bool = True
   ) -> Dict[str, int]:
       """Import nutritional data from CSV file into database.

       Args:
           csv_file_path: Path to the CSV file containing nutritional data
           batch_size: Number of records to process in each batch
           validate_data: Whether to validate data before import

       Returns:
           Dictionary containing import statistics:
           - rows_processed: Total rows processed
           - rows_imported: Successfully imported rows
           - rows_skipped: Skipped rows due to validation

       Raises:
           FileNotFoundError: If CSV file doesn't exist
           ValidationError: If data validation fails
       """
       # Implementation details...
   ```

### Shell Script Guidelines

1. **Best Practices**
   - Use `set -euo pipefail` for error handling
   - Include descriptive comments and section separators
   - Use consistent variable naming (UPPER_CASE for constants)
   - Provide helpful error messages and usage information

2. **Example Script Style**

   ```bash
   #!/bin/bash
   # scripts/example/example-script.sh

   set -euo pipefail

   # Script configuration
   NAMESPACE="recipe-database"
   LOCAL_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

   # Utility functions
   print_separator() {
     local char="${1:-=}"
     printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' "$char"
   }

   # Main logic with clear sections
   print_separator "="
   echo "🚀 Starting example operation..."
   print_separator "-"
   ```

## Testing

### Database Testing

1. **Schema Testing**
   - Verify all schema files execute without errors
   - Test constraints and triggers work correctly
   - Validate indexes are created and used properly

2. **Function Testing**
   - Test all code paths including error conditions
   - Verify return values and side effects
   - Test with edge cases and invalid inputs

3. **Performance Testing**
   - Test with realistic data volumes
   - Verify query performance meets requirements
   - Check resource usage under load

### Python Testing

1. **Unit Tests**
   - Use pytest for test framework
   - Test individual functions and classes
   - Mock external dependencies

2. **Integration Tests**
   - Test end-to-end data processing workflows
   - Verify database integration works correctly
   - Test error handling and recovery

### Running Tests

```bash
# Python tests
cd python/
pytest tests/ -v --cov=nutritional_data_importer

# Database tests (manual for now)
./scripts/dbManagement/load-test-fixtures.sh
# Run manual validation queries

# Script tests
shellcheck scripts/**/*.sh
```

## Documentation

### Requirements

- Update documentation for any user-facing changes
- Include code examples for new features
- Update API documentation for database changes
- Add troubleshooting information for common issues

### Documentation Types

1. **README Updates**
   - Update main README.md for major features
   - Update monitoring/README.md for monitoring changes
   - Keep CLAUDE.md updated for development guidance

2. **Code Documentation**
   - Inline comments for complex logic
   - Function/procedure documentation
   - Schema documentation for new tables

3. **User Guides**
   - Step-by-step setup instructions
   - Configuration options and examples
   - Troubleshooting guides

## Pull Request Process

### Before Submitting

1. **Code Quality**

   ```bash
   # Python formatting and linting
   black python/
   isort python/
   flake8 python/
   mypy python/

   # Shell script checking
   shellcheck scripts/**/*.sh

   # SQL formatting (if using SQLFluff)
   sqlfluff fix db/init/schema/ --dialect postgres
   ```

2. **Testing**
   - Test your changes in a local environment
   - Verify existing functionality still works
   - Add new tests for new functionality

3. **Documentation**
   - Update relevant documentation
   - Add/update code comments
   - Update CHANGELOG.md if applicable

### Pull Request Template

When submitting a PR, include:

```markdown
## Description

Brief description of changes and motivation.

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to
      not work as expected)
- [ ] Documentation update

## Testing

- [ ] Local testing completed
- [ ] New tests added (if applicable)
- [ ] All existing tests pass

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)
```

### Review Process

1. **Automated Checks**
   - All CI/CD checks must pass
   - Code quality tools must pass
   - Security scans must pass

2. **Code Review**
   - At least one maintainer review required
   - Address all review comments
   - Maintain clean commit history

3. **Testing**
   - Functional testing in review environment
   - Performance impact assessment
   - Security review for sensitive changes

## Issue Guidelines

### Bug Reports

Include the following information:

```markdown
**Bug Description** A clear description of what the bug is.

**Steps to Reproduce**

1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected Behavior** What you expected to happen.

**Actual Behavior** What actually happened.

**Environment**

- OS: [e.g. Ubuntu 20.04]
- Kubernetes version: [e.g. 1.25]
- PostgreSQL version: [e.g. 15.4]
- Docker version: [e.g. 20.10]

**Additional Context** Add any other context about the problem here.
```

### Feature Requests

Include the following information:

```markdown
**Feature Summary** A clear and concise description of the feature.

**Problem Statement** What problem does this feature solve?

**Proposed Solution** Describe the solution you'd like to see.

**Alternative Solutions** Describe alternative solutions you've considered.

**Additional Context** Add any other context or screenshots about the feature
request.
```

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community discussion
- **Pull Requests**: Code contributions and reviews

### Getting Help

- Check existing issues and discussions first
- Provide clear, detailed information when asking questions
- Be patient and respectful in all interactions
- Help others when you can

### Recognition

Contributors are recognized in:

- [Contributors file](contributors.md)
- Release notes and changelogs
- GitHub contributor statistics

## Questions

If you have questions about contributing, please:

1. Check this document first
2. Search existing GitHub issues and discussions
3. Create a new GitHub discussion with the 'question' label
4. Tag maintainers if needed (but please be respectful of their time)

Thank you for contributing to Recipe Database! 🎉
