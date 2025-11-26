#!/bin/bash

# Initialize database with Prisma migrations

set -e

echo "🗄️  Initializing database..."

# Wait for database to be ready
echo "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
  if docker exec emergency_db pg_isready -U postgres > /dev/null 2>&1; then
    echo "✅ PostgreSQL is ready!"
    break
  fi
  attempt=$((attempt + 1))
  echo "Attempt $attempt/$max_attempts..."
  sleep 2
done

if [ $attempt -eq $max_attempts ]; then
  echo "❌ PostgreSQL failed to start. Please check logs:"
  echo "   docker logs emergency_db"
  exit 1
fi

# Run Prisma migrations
echo "📦 Running database migrations..."

docker exec emergency_backend sh -c "cd /app && npx prisma migrate deploy"

if [ $? -eq 0 ]; then
  echo "✅ Database migrations completed!"
else
  echo "❌ Migration failed. Trying to create migration..."
  docker exec emergency_backend sh -c "cd /app && npx prisma migrate dev --name init"
fi

echo ""
echo "🎉 Database setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Create admin user by accessing:"
echo "      POST http://localhost:3000/auth/setup-admin"
echo "      Body: { \"phoneNumber\": \"+6281234567890\", \"name\": \"Admin\", \"password\": \"your-password\" }"
echo ""
echo "   2. Save the admin password in .env:"
echo "      ADMIN_PASSWORD=your-password"
