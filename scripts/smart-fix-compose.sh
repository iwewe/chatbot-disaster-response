#!/bin/bash
################################################################################
# Smart Fix for docker-compose.yml - Handle duplicate volumes and misplaced services
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo "Smart Fix for docker-compose.yml"
echo "================================="
echo ""

# Check if file exists
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found in current directory"
    exit 1
fi

# Backup
BACKUP="docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)"
cp docker-compose.yml "$BACKUP"
log_success "Backed up to: $BACKUP"

# Read the entire file and fix it properly
log_info "Analyzing docker-compose.yml structure..."

# Extract only the clean services section (everything before first 'networks:' or 'volumes:')
# Then rebuild the file properly

python3 - <<'PYTHON_SCRIPT'
import yaml
import sys

try:
    # Read the broken file
    with open('docker-compose.yml', 'r') as f:
        content = f.read()

    # Try to load as much as possible
    # Remove dashboard service if it exists in wrong place
    lines = content.split('\n')

    # Find sections
    in_services = False
    in_networks = False
    in_volumes = False

    clean_lines = []
    skip_dashboard = False
    indent_level = 0

    for i, line in enumerate(lines):
        stripped = line.lstrip()

        # Detect sections
        if line.startswith('services:'):
            in_services = True
            in_networks = False
            in_volumes = False
            clean_lines.append(line)
            continue

        if line.startswith('networks:'):
            in_services = False
            in_networks = True
            in_volumes = False
            # Skip if this is a duplicate
            if 'networks:' in '\n'.join(clean_lines):
                continue
            clean_lines.append(line)
            continue

        if line.startswith('volumes:'):
            in_services = False
            in_networks = False
            in_volumes = True
            # Skip if this is a duplicate
            if 'volumes:' in '\n'.join(clean_lines):
                continue
            clean_lines.append(line)
            continue

        # Skip dashboard service in wrong section
        if 'dashboard:' in line and (in_networks or in_volumes):
            skip_dashboard = True
            indent_level = len(line) - len(line.lstrip())
            continue

        if skip_dashboard:
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= indent_level and stripped and not stripped.startswith('-'):
                skip_dashboard = False
            else:
                continue

        clean_lines.append(line)

    # Write cleaned content
    with open('docker-compose.yml.cleaned', 'w') as f:
        f.write('\n'.join(clean_lines))

    print("CLEANED")

except Exception as e:
    print(f"ERROR:{e}")
    sys.exit(1)

PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    log_success "File cleaned successfully"
    mv docker-compose.yml.cleaned docker-compose.yml
else
    log_error "Python cleaning failed, using manual method..."

    # Fallback: Manual cleaning
    cp "$BACKUP" docker-compose.yml

    # Remove all dashboard-related lines
    sed -i '/^  dashboard:/d' docker-compose.yml
    sed -i '/image: nginx:alpine/d' docker-compose.yml
    sed -i '/container_name: emergency_dashboard/d' docker-compose.yml
    sed -i '/.*dashboard.*usr.*share.*nginx.*/d' docker-compose.yml
    sed -i '/.*nginx-dashboard.conf.*/d' docker-compose.yml
    sed -i '/8080:80/d' docker-compose.yml

    # Remove duplicate volumes: sections (keep only first one)
    awk '/^volumes:/{if(++count>1)next}1' docker-compose.yml > docker-compose.yml.tmp
    mv docker-compose.yml.tmp docker-compose.yml

    # Remove duplicate networks: sections
    awk '/^networks:/{if(++count>1)next}1' docker-compose.yml > docker-compose.yml.tmp
    mv docker-compose.yml.tmp docker-compose.yml
fi

# Now add dashboard service in the correct place
log_info "Adding dashboard service in correct position..."

# Find line number of first 'networks:' or 'volumes:' at root level
NETWORKS_LINE=$(grep -n "^networks:" docker-compose.yml | head -1 | cut -d: -f1)
VOLUMES_LINE=$(grep -n "^volumes:" docker-compose.yml | head -1 | cut -d: -f1)

# Use whichever comes first
if [ -n "$NETWORKS_LINE" ] && [ -n "$VOLUMES_LINE" ]; then
    if [ $NETWORKS_LINE -lt $VOLUMES_LINE ]; then
        INSERT_LINE=$NETWORKS_LINE
    else
        INSERT_LINE=$VOLUMES_LINE
    fi
elif [ -n "$NETWORKS_LINE" ]; then
    INSERT_LINE=$NETWORKS_LINE
elif [ -n "$VOLUMES_LINE" ]; then
    INSERT_LINE=$VOLUMES_LINE
else
    log_error "Could not find networks: or volumes: section"
    exit 1
fi

log_info "Inserting dashboard service before line $INSERT_LINE"

# Split file and insert dashboard
head -n $((INSERT_LINE - 1)) docker-compose.yml > docker-compose.yml.new

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

tail -n +$INSERT_LINE docker-compose.yml >> docker-compose.yml.new

mv docker-compose.yml.new docker-compose.yml

# Validate
log_info "Validating docker-compose.yml..."
if docker compose config > /dev/null 2>&1; then
    log_success "✓ docker-compose.yml is valid!"
    log_info ""
    log_info "Fixed docker-compose.yml successfully!"
    log_info "You can now run: docker compose up -d dashboard"
    echo ""
else
    log_error "✗ Validation failed"
    echo ""
    docker compose config 2>&1 | head -20
    echo ""
    log_warning "Restoring from backup: $BACKUP"
    cp "$BACKUP" docker-compose.yml
    echo ""
    log_error "Manual fix required. Please share docker-compose.yml content."
    exit 1
fi
