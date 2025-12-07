#!/bin/bash
################################################################################
# Emergency Response System - Admin User Setup Script
# Creates or updates admin user for dashboard access
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "======================================================"
echo "  Emergency Response System - Admin Setup"
echo "======================================================"
echo ""

# Check if backend container is running
if ! docker ps | grep -q "emergency_backend"; then
    log_error "Backend container is not running"
    log_info "Please start the backend first using deploy-git.sh or deploy-curl.sh"
    exit 1
fi

# Get admin details
log_info "Enter admin user details:"
echo ""

read -p "Phone number (WhatsApp): " PHONE
read -p "Full name: " NAME

# Validate input
if [ -z "$PHONE" ] || [ -z "$NAME" ]; then
    log_error "Phone number and name are required"
    exit 1
fi

# Create or update admin user
log_info "Creating/updating admin user..."

docker exec emergency_backend node -e "
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    // Check if user exists
    const existing = await prisma.user.findUnique({
      where: { phoneNumber: '$PHONE' },
    });

    let user;
    if (existing) {
      // Update existing user to admin
      user = await prisma.user.update({
        where: { phoneNumber: '$PHONE' },
        data: {
          name: '$NAME',
          role: 'ADMIN',
          trustLevel: 5,
          isActive: true,
        },
      });
      console.log('✅ Admin user updated successfully');
    } else {
      // Create new admin user
      user = await prisma.user.create({
        data: {
          phoneNumber: '$PHONE',
          name: '$NAME',
          role: 'ADMIN',
          trustLevel: 5,
          isActive: true,
        },
      });
      console.log('✅ Admin user created successfully');
    }

    console.log('');
    console.log('User Details:');
    console.log('  Phone Number:', user.phoneNumber);
    console.log('  Name:', user.name);
    console.log('  Role:', user.role);
    console.log('  Trust Level:', user.trustLevel);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.\$disconnect());
" && CREATION_SUCCESS=true || CREATION_SUCCESS=false

if [ "$CREATION_SUCCESS" = true ]; then
    echo ""
    log_success "Admin user setup completed!"
    echo ""
    echo "======================================================"
    echo "  Login Credentials"
    echo "======================================================"
    echo "  Username: $PHONE"
    echo "  Password: Set in .env as ADMIN_PASSWORD"
    echo "======================================================"
    echo ""

    # Check if ADMIN_PASSWORD is set in .env
    if [ -f "$HOME/chatbot-disaster-response/.env" ]; then
        if grep -q "^ADMIN_PASSWORD=" "$HOME/chatbot-disaster-response/.env"; then
            log_success "ADMIN_PASSWORD is already set in .env"
        else
            log_warning "ADMIN_PASSWORD not found in .env"
            echo ""
            read -p "Set admin password now? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                read -s -p "Enter admin password: " PASSWORD
                echo ""
                read -s -p "Confirm password: " PASSWORD2
                echo ""

                if [ "$PASSWORD" = "$PASSWORD2" ]; then
                    echo "ADMIN_PASSWORD=$PASSWORD" >> "$HOME/chatbot-disaster-response/.env"
                    log_success "Password added to .env"
                    log_info "Restarting backend to apply changes..."

                    cd "$HOME/chatbot-disaster-response"
                    if command -v docker compose &> /dev/null && docker compose version &> /dev/null; then
                        docker compose restart backend
                    else
                        docker-compose restart backend
                    fi
                else
                    log_error "Passwords do not match"
                    log_warning "Please manually add ADMIN_PASSWORD to .env"
                fi
            fi
        fi
    fi

    echo ""
    log_info "You can now login to the dashboard at:"
    log_info "  http://your-domain/dashboard"
else
    log_error "Failed to create admin user"
    exit 1
fi
