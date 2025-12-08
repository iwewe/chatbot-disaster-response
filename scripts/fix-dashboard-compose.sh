#!/bin/bash
################################################################################
# Fix docker-compose.yml indentation issue for dashboard service
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "Fixing docker-compose.yml dashboard service indentation..."
echo ""

# Backup original
cp docker-compose.yml docker-compose.yml.broken
log_info "Backed up broken file to docker-compose.yml.broken"

# Remove incorrectly added dashboard service
# We'll look for the dashboard service and remove it from wherever it is
log_info "Removing incorrectly placed dashboard service..."

# Create a clean version by removing dashboard service lines
grep -v "dashboard:" docker-compose.yml | \
grep -v "image: nginx:alpine" | \
grep -v "container_name: emergency_dashboard" | \
grep -v "./dashboard:/usr/share/nginx/html:ro" | \
grep -v "./nginx-dashboard.conf:/etc/nginx/conf.d/default.conf:ro" | \
grep -v "8080:80" > docker-compose.yml.tmp

# Find where services section ends (before networks or volumes)
# We'll add dashboard service right before the last closing of services section

# Find the line number where we should insert dashboard
# Look for the line with 'networks:' or 'volumes:' at root level (no indentation)
INSERT_LINE=$(grep -n "^networks:" docker-compose.yml.tmp | head -1 | cut -d: -f1)

if [ -z "$INSERT_LINE" ]; then
    INSERT_LINE=$(grep -n "^volumes:" docker-compose.yml.tmp | head -1 | cut -d: -f1)
fi

if [ -z "$INSERT_LINE" ]; then
    log_error "Could not find insertion point in docker-compose.yml"
    exit 1
fi

# Insert dashboard service before networks/volumes section
log_info "Adding dashboard service at correct position..."

# Split file
head -n $((INSERT_LINE - 1)) docker-compose.yml.tmp > docker-compose.yml.new
cat >> docker-compose.yml.new <<'EOF'

  dashboard:
    image: nginx:alpine
    container_name: emergency_dashboard
    volumes:
      - ./dashboard:/usr/share/nginx/html:ro
      - ./nginx-dashboard.conf:/etc/nginx/conf.d/default.conf:ro
    ports:
      - "8080:80"
    networks:
      - emergency_net
    depends_on:
      - backend
    restart: unless-stopped

EOF

# Append rest of file
tail -n +$INSERT_LINE docker-compose.yml.tmp >> docker-compose.yml.new

# Replace original
mv docker-compose.yml.new docker-compose.yml
rm docker-compose.yml.tmp

log_success "docker-compose.yml fixed!"
echo ""

# Validate
log_info "Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    log_success "✓ docker-compose.yml is valid!"
else
    log_error "✗ docker-compose.yml validation failed"
    echo ""
    echo "Showing validation output:"
    docker compose config
    echo ""
    log_info "Restoring backup..."
    mv docker-compose.yml.broken docker-compose.yml
    exit 1
fi

echo ""
log_info "You can now run: docker compose up -d dashboard"
