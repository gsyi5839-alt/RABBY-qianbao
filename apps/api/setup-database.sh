#!/bin/bash

# Rabby API Database Setup Script
# This script initializes PostgreSQL database for Rabby Wallet backend

set -e

echo "🚀 Rabby API Database Setup"
echo "=============================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DB_HOST="${DATABASE_HOST:-localhost}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_NAME="${DATABASE_NAME:-rabby_db}"
DB_USER="${DATABASE_USER:-rabby_user}"
DB_PASSWORD="${DATABASE_PASSWORD:-rabby_password}"

echo -e "${YELLOW}Database Configuration:${NC}"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Step 1: Check if PostgreSQL is running
echo "📡 Step 1: Checking PostgreSQL connection..."
if command -v docker &> /dev/null && docker ps | grep -q rabby_postgres; then
    echo -e "${GREEN}✓ PostgreSQL is running (Docker)${NC}"
elif command -v psql &> /dev/null && psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "SELECT 1" &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is running (Local)${NC}"
else
    echo -e "${RED}✗ PostgreSQL is not running${NC}"
    echo ""
    echo "Please start PostgreSQL:"
    echo "  - Docker: cd apps/api && docker-compose up -d"
    echo "  - Homebrew: brew services start postgresql"
    exit 1
fi

# Step 2: Initialize database schema
echo ""
echo "📊 Step 2: Initializing database schema..."

if [ -f "db/schema.sql" ]; then
    if command -v docker &> /dev/null && docker ps | grep -q rabby_postgres; then
        # Use Docker exec
        docker exec -i rabby_postgres psql -U "$DB_USER" -d "$DB_NAME" < db/schema.sql
    else
        # Use local psql
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" < db/schema.sql
    fi

    echo -e "${GREEN}✓ Database schema initialized${NC}"
else
    echo -e "${RED}✗ schema.sql not found${NC}"
    echo "Please run this script from apps/api directory"
    exit 1
fi

# Step 3: Verify data
echo ""
echo "🔍 Step 3: Verifying seed data..."

if command -v docker &> /dev/null && docker ps | grep -q rabby_postgres; then
    DAPP_COUNT=$(docker exec rabby_postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM dapp_entries;")
    RULE_COUNT=$(docker exec rabby_postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM security_rules;")
else
    DAPP_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM dapp_entries;")
    RULE_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM security_rules;")
fi

DAPP_COUNT=$(echo $DAPP_COUNT | xargs)
RULE_COUNT=$(echo $RULE_COUNT | xargs)

echo "  DApp Entries: $DAPP_COUNT"
echo "  Security Rules: $RULE_COUNT"

if [ "$DAPP_COUNT" -gt 0 ] && [ "$RULE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Seed data verified${NC}"
else
    echo -e "${YELLOW}⚠ Seed data may be missing${NC}"
fi

# Step 4: Test connection
echo ""
echo "🔗 Step 4: Testing API server connection..."

if [ -f ".env" ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
else
    echo -e "${YELLOW}⚠ .env file not found, copying from .env.example${NC}"
    cp .env.example .env
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Database setup completed successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Install dependencies: yarn install"
echo "  2. Start the server: yarn dev"
echo "  3. Check health: curl http://localhost:3001/health"
echo ""
echo "Useful commands:"
echo "  - Connect to DB: docker exec -it rabby_postgres psql -U $DB_USER -d $DB_NAME"
echo "  - View tables: \\dt"
echo "  - View DApps: SELECT name, category FROM dapp_entries;"
echo ""
