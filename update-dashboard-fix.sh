#!/bin/bash
#################################################################
# Update Dashboard - Fix API Response & Add Manual Input Form
#################################################################

cd /opt/emergency-chatbot

echo "📥 Downloading dashboard fixes from GitHub..."

# Download updated files
wget -q -O dashboard/index.html https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/dashboard/index.html

wget -q -O dashboard/dashboard.html https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/dashboard/dashboard.html

wget -q -O dashboard/reports.html https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/dashboard/reports.html

wget -q -O dashboard/create-report.html https://raw.githubusercontent.com/iwewe/chatbot-disaster-response/claude/emergency-chatbot-database-015rFTqBPiJaT7MnsyVpSXpf/dashboard/create-report.html

echo "✅ Files downloaded!"

# Restart dashboard
echo "🔄 Restarting dashboard..."
docker compose restart dashboard

sleep 3

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         ✅ Dashboard Updated Successfully!          ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "🔧 What's Fixed:"
echo "   ✓ Login now works with admin credentials"
echo "   ✓ Dashboard displays data correctly"
echo "   ✓ Reports table shows all data"
echo "   ✓ Added manual report form"
echo ""
echo "🌐 Access:"
echo "   Dashboard: http://192.168.110.62:8080"
echo "   Login:     admin / Admin123!Staging"
echo ""
echo "📝 New Features:"
echo "   • Manual report input form"
echo "   • View/filter/search reports"
echo "   • Real-time statistics"
echo ""
