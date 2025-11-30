#!/bin/bash

echo "🔍 Testing Network dari dalam Container..."
echo ""

echo "1️⃣ Testing DNS Resolution..."
docker exec emergency_backend nslookup web.whatsapp.com || echo "❌ nslookup gagal"
echo ""

echo "2️⃣ Testing dengan getent hosts..."
docker exec emergency_backend getent hosts web.whatsapp.com || echo "❌ getent gagal"
echo ""

echo "3️⃣ Testing ping ke web.whatsapp.com..."
docker exec emergency_backend ping -c 3 web.whatsapp.com || echo "❌ ping gagal"
echo ""

echo "4️⃣ Testing curl ke WhatsApp Web..."
docker exec emergency_backend curl -v -m 10 https://web.whatsapp.com 2>&1 | head -20
echo ""

echo "5️⃣ Checking /etc/resolv.conf di container..."
docker exec emergency_backend cat /etc/resolv.conf
echo ""

echo "6️⃣ Testing DNS ke 8.8.8.8..."
docker exec emergency_backend ping -c 3 8.8.8.8 || echo "❌ ping 8.8.8.8 gagal"
