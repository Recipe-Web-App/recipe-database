# Changelog

All notable changes to the Recipe Database project will be documented in this
file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Comprehensive PostgreSQL monitoring with Prometheus and Grafana integration
- postgres_exporter sidecar container for metrics collection
- Custom recipe-specific business metrics and performance monitoring
- Automated database user management for monitoring
- Pre-configured Grafana dashboards for database visualization
- ServiceMonitor and PrometheusRule for Kubernetes-native monitoring
- Complete set of management scripts for monitoring infrastructure
- Health check and diagnostic queries for database maintenance

### Changed

- Enhanced Kubernetes deployment with monitoring support
- Updated service configuration to expose metrics endpoint
- Improved documentation with comprehensive setup guides
- Enhanced security with dedicated monitoring user permissions

### Security

- Added dedicated monitoring user with minimal read-only permissions
- Implemented secure secret management for monitoring credentials
- Enhanced RBAC configuration for monitoring components

## [1.0.0] - 2024-01-20

### Features Added

- Complete PostgreSQL database schema for recipe management
- User management system with role-based access control
- Recipe storage with ingredients, steps, and metadata
- Advanced user preference system (9 categories of preferences)
- Social features: user follows, notifications, favorites
- Meal planning functionality with calendar integration
- Nutritional data integration with OpenFoodFacts support
- Recipe versioning and revision tracking system
- Comprehensive review and rating system
- Tag-based recipe categorization
- Kubernetes-native deployment with persistent storage
- Docker containerization with PostgreSQL 15.4
- Python-based nutritional data importer
- Complete set of database management scripts
- Automated schema loading and test data fixtures
- Database backup and restore functionality

### Database Schema

- `users` table with comprehensive profile management
- `recipes` table with full recipe metadata
- `ingredients` table with nutritional information
- `recipe_ingredients` junction table with quantities and units
- `recipe_steps` table for cooking instructions
- `reviews` table for user-generated feedback
- `recipe_favorites` for user bookmarking
- `meal_plans` and `meal_plan_recipes` for meal planning
- `user_follows` for social networking features
- `user_notifications` for activity notifications
- 9 user preference tables for customization
- `nutritional_info` for ingredient nutrition data
- `recipe_revisions` for version tracking
- `recipe_tags` and junction table for categorization

### Database Functions

- `create_recipe()` - Complete recipe creation with ingredients
- `get_average_rating()` - Recipe rating calculations
- `get_followed_users()` - Social network queries
- `get_meal_plan_summary()` - Meal planning aggregations
- `get_recipe_tags()` - Tag management
- `get_user_meal_plans()` - User meal plan queries
- `update_timestamp()` - Automated timestamp management

### Database Views

- `recipe_summary` - Comprehensive recipe overview
- `vw_recent_recipes` - Recently created recipes
- `vw_recipe_full_details` - Complete recipe information
- `vw_top_rated_recipes` - Highest rated recipes
- `vw_user_favorite_recipes` - User bookmarked recipes

### Database Triggers

- `create_default_preferences_trigger` - Auto-create user preferences
- `enforce_rating_bounds_trigger` - Validate rating values
- `prevent_duplicate_follow_trigger` - Prevent duplicate follows
- `prevent_review_self` - Prevent self-reviews
- `set_preferences_updated_at_trigger` - Update preference timestamps
- `set_updated_at_trigger` - Auto-update modified timestamps

### Scripts and Automation

- Container management scripts for deployment lifecycle
- Database management scripts for operations
- Kubernetes job helpers for automated tasks
- Python data processing tools for nutritional data
- Environment variable management and configuration
- Automated backup and restore procedures

### Documentation

- Comprehensive README with setup instructions
- CLAUDE.md for development guidance
- Inline documentation for all database objects
- Script documentation with usage examples

### Security Features

- Role-based user management with admin/user roles
- Password hashing and secure authentication
- Database connection security
- Kubernetes secret management
- Network isolation and security policies

## [0.1.0] - 2024-01-01

### Initial Release

- Initial project structure
- Basic PostgreSQL container setup
- Kubernetes deployment manifests
- Initial database schema design
- Development environment setup

---

## Release Notes

### Version 1.0.0 - "Foundation Release"

This is the foundational release of the Recipe Database, providing a complete,
production-ready PostgreSQL database system for recipe management applications.
The release includes:

**🎯 Key Features:**

- Complete recipe management with ingredients, steps, and metadata
- Advanced user system with social features and preferences
- Meal planning with nutritional tracking
- Kubernetes-native deployment with monitoring
- Python-based data processing tools

**🔧 Technical Excellence:**

- PostgreSQL 15.4 with advanced features and performance optimization
- Comprehensive database schema with proper constraints and indexes
- Automated deployment and management scripts
- Security-first design with RBAC and secure secrets

**📊 Data Integration:**

- OpenFoodFacts nutritional data import capability
- Flexible ingredient and recipe data model
- Comprehensive user preference management
- Social networking and engagement features

**🚀 Production Ready:**

- Kubernetes deployment with persistent storage
- Automated backup and restore procedures
- Health checks and monitoring setup
- Complete documentation and setup guides

### Monitoring Enhancement (Latest)

The latest updates focus on operational excellence with comprehensive
monitoring:

**📊 Monitoring Features:**

- Real-time PostgreSQL metrics collection
- Recipe-specific business intelligence metrics
- Performance monitoring and alerting
- Grafana dashboards for visualization

**🔧 Operational Tools:**

- Dedicated management scripts for monitoring
- Automated user setup for metrics collection
- Health checks and diagnostic queries
- Complete monitoring documentation

**🔒 Security Enhancements:**

- Dedicated monitoring user with minimal permissions
- Secure credential management for monitoring
- Network isolation for monitoring components
- Comprehensive security documentation

---

## Migration Notes

### Upgrading to Latest (with Monitoring)

If you're upgrading from version 1.0.0 to the latest version with monitoring:

1. **Deploy monitoring infrastructure:**

   ```bash
   ./scripts/dbManagement/setup-monitoring-user.sh
   ./scripts/containerManagement/deploy-supporting-services.sh
   ```

2. **Import Grafana dashboard:**
   - Use the dashboard from
     `monitoring/grafana-dashboards/postgresql-overview.json`

3. **Verify monitoring:**

   ```bash
   ./scripts/containerManagement/get-supporting-services-status.sh
   ```

No database schema changes are required for the monitoring upgrade.

### Fresh Installation

For new installations, follow the complete setup process in the README.md:

1. Deploy main database
2. Load schema and test data
3. Setup monitoring (recommended)
4. Configure Grafana dashboards

---

## Contributors

Special thanks to all contributors who helped make this project possible:

- Initial database schema design and implementation
- Kubernetes deployment and operational scripts
- Python data processing tools
- Comprehensive monitoring integration
- Documentation and user guides

---

## Support

For questions about releases or upgrade procedures:

- Check the [README.md](README.md) for setup instructions
- Review the [documentation](docs/) for detailed guides
- Create an issue on GitHub for bug reports
- Use GitHub Discussions for general questions

For security-related issues, please follow our [Security Policy](SECURITY.md).
