# Recipe Database Makefile
# Simplifies running database management commands

.PHONY: help setup schema fixtures import-nutrition import-pricing backup restore export \
        monitoring connect lint test clean

# Default target
help:
	@echo "Recipe Database Management Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup              Install Python dependencies"
	@echo "  make schema             Load database schema"
	@echo "  make fixtures           Load test fixtures"
	@echo ""
	@echo "Nutrition Data:"
	@echo "  make import-nutrition   Download and import USDA nutrition data"
	@echo "  make import-pricing     Import pricing data from USDA/Kaggle"
	@echo ""
	@echo "Database Operations:"
	@echo "  make backup             Full database backup"
	@echo "  make restore            Restore database from backup"
	@echo "  make export             Export schema only"
	@echo "  make connect            Interactive psql session"
	@echo "  make monitoring         Setup monitoring user"
	@echo ""
	@echo "Development:"
	@echo "  make lint               Run all linters (prek)"
	@echo "  make clean              Remove cached/temp files"
	@echo ""
	@echo "Options (pass via environment):"
	@echo "  VERBOSE=1               Enable verbose output"
	@echo "  DATASET=foundation_food Override default dataset (import-nutrition)"
	@echo "  FORCE_DOWNLOAD=1        Force re-download of files"
	@echo "  KEEP_FILES=1            Keep downloaded files after import"
	@echo ""
	@echo "Examples:"
	@echo "  make schema VERBOSE=1"
	@echo "  make import-nutrition DATASET=foundation_food"
	@echo "  make import-pricing"
	@echo "  make import-pricing KEEP_FILES=1 VERBOSE=1"

# Python command with optional flags
PYTHON := PYTHONPATH=python python
VERBOSE_FLAG := $(if $(VERBOSE),-v,)

# Setup
setup:
	pip install -r python/requirements.txt

# Schema and fixtures
schema:
	$(PYTHON) -m db_tools.load_schema $(VERBOSE_FLAG) --admin

fixtures:
	$(PYTHON) -m db_tools.load_fixtures $(VERBOSE_FLAG)

# Nutrition data management
import-nutrition:
	$(PYTHON) -m db_tools.import_nutrition $(VERBOSE_FLAG) $(if $(DATASET),--dataset $(DATASET),)

# Pricing data management
import-pricing:
	$(PYTHON) -m db_tools.import_pricing $(VERBOSE_FLAG) \
		$(if $(FORCE_DOWNLOAD),--force-download,) \
		$(if $(KEEP_FILES),--keep-files,)

# Database operations
backup:
	$(PYTHON) -m db_tools.backup_db $(VERBOSE_FLAG)

restore:
	$(PYTHON) -m db_tools.restore_db $(VERBOSE_FLAG) --admin $(if $(DATE),$(DATE),)

export:
	$(PYTHON) -m db_tools.export_schema $(VERBOSE_FLAG)

monitoring:
	$(PYTHON) -m db_tools.setup_monitoring $(VERBOSE_FLAG)

# Interactive connection (still uses shell script)
connect:
	./scripts/dbManagement/db-connect.sh

# Development
lint:
	prek

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	find . -type f -name ".coverage" -delete 2>/dev/null || true
	rm -rf .pytest_cache .mypy_cache .ruff_cache 2>/dev/null || true

# Compound targets
init: schema fixtures
	@echo "Database initialized with schema and fixtures"

full-setup: setup schema fixtures
	@echo "Full setup complete"
