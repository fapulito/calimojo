#!/bin/bash

echo "Running Migration Script Tests"
echo "==============================="

# Unit tests (no external dependencies)
echo -e "\n[1/3] Running unit tests..."
prove -v t/migrate.t t/migrate_options.t

# Integration tests (requires PostgreSQL)
if [ -n "$DATABASE_URL" ]; then
    echo -e "\n[2/3] Running integration tests..."
    RUN_INTEGRATION_TESTS=1 prove -v t/migrate_integration.t
else
    echo -e "\n[2/3] Skipping integration tests (DATABASE_URL not set)"
fi

# Run all tests with coverage (if Devel::Cover is installed)
if command -v cover &> /dev/null; then
    echo -e "\n[3/3] Running coverage report..."
    cover -test -report html
    echo "Coverage report generated in cover_db/coverage.html"
else
    echo -e "\n[3/3] Skipping coverage (Devel::Cover not installed)"
fi

echo -e "\n==============================="
echo "Tests completed!"
