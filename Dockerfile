# Stage 1: Main database image
FROM postgres:15.4 AS database

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gettext \
    python3 \
    python3-pip \
    python3-venv \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set locale to C (always available) to avoid PostgreSQL locale issues
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create app directory for Python scripts
RUN mkdir -p /app

# Stage 2: Job runner image (extends main database image)
FROM database AS jobs

# Copy database files and scripts for job operations
COPY db/ /app/sql/
COPY scripts/ /app/scripts/

# Set working directory
WORKDIR /app
