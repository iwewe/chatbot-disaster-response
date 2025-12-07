// Dashboard Main Logic
let reportTypesChart = null;
let urgencyChart = null;

// Load dashboard data
async function loadDashboard() {
  try {
    await Promise.all([
      loadStats(),
      loadCharts(),
      loadRecentReports(),
    ]);
  } catch (error) {
    console.error('Failed to load dashboard:', error);
    showError('Gagal memuat data dashboard');
  }
}

// Load statistics
async function loadStats() {
  try {
    const data = await authFetch('/api/dashboard/stats');

    if (data.success) {
      const stats = data.data || data;
      const summary = stats.summary || stats;

      document.getElementById('totalReports').textContent = summary.totalReports || 0;
      document.getElementById('pendingReports').textContent = summary.pendingVerification || 0;
      document.getElementById('verifiedReports').textContent = (summary.totalReports - summary.pendingVerification) || 0;
      document.getElementById('criticalReports').textContent = summary.criticalReports || 0;
    }
  } catch (error) {
    console.error('Failed to load stats:', error);
  }
}

// Load charts
async function loadCharts() {
  try {
    const data = await authFetch('/api/dashboard/stats');

    if (data.success) {
      const stats = data.data || data;
      const reportsByType = stats.reportsByType || {};
      const reportsByUrgency = stats.reportsByUrgency || {};

      // Report Types Chart
      if (reportTypesChart) reportTypesChart.destroy();
      const reportTypesCtx = document.getElementById('reportTypesChart').getContext('2d');
      reportTypesChart = new Chart(reportTypesCtx, {
        type: 'doughnut',
        data: {
          labels: ['Korban', 'Kebutuhan'],
          datasets: [{
            data: [
              reportsByType.KORBAN || 0,
              reportsByType.KEBUTUHAN || 0,
            ],
            backgroundColor: [
              'rgba(239, 68, 68, 0.8)',
              'rgba(59, 130, 246, 0.8)',
            ],
            borderColor: [
              'rgba(239, 68, 68, 1)',
              'rgba(59, 130, 246, 1)',
            ],
            borderWidth: 2,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: true,
          plugins: {
            legend: {
              position: 'bottom',
            },
          },
        },
      });

      // Urgency Levels Chart
      if (urgencyChart) urgencyChart.destroy();
      const urgencyCtx = document.getElementById('urgencyChart').getContext('2d');
      urgencyChart = new Chart(urgencyCtx, {
        type: 'bar',
        data: {
          labels: ['Kritis', 'Tinggi', 'Sedang', 'Rendah'],
          datasets: [{
            label: 'Jumlah Laporan',
            data: [
              reportsByUrgency.CRITICAL || 0,
              reportsByUrgency.HIGH || 0,
              reportsByUrgency.MEDIUM || 0,
              reportsByUrgency.LOW || 0,
            ],
            backgroundColor: [
              'rgba(239, 68, 68, 0.8)',
              'rgba(249, 115, 22, 0.8)',
              'rgba(234, 179, 8, 0.8)',
              'rgba(34, 197, 94, 0.8)',
            ],
            borderColor: [
              'rgba(239, 68, 68, 1)',
              'rgba(249, 115, 22, 1)',
              'rgba(234, 179, 8, 1)',
              'rgba(34, 197, 94, 1)',
            ],
            borderWidth: 2,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: true,
          scales: {
            y: {
              beginAtZero: true,
              ticks: {
                stepSize: 1,
              },
            },
          },
          plugins: {
            legend: {
              display: false,
            },
          },
        },
      });
    }
  } catch (error) {
    console.error('Failed to load charts:', error);
  }
}

// Load recent reports
async function loadRecentReports() {
  try {
    const data = await authFetch('/api/reports?limit=5&sortBy=createdAt&sortOrder=desc');

    const container = document.getElementById('recentReports');
    const reports = data.data || data.reports || [];

    if (data.success && reports && reports.length > 0) {
      container.innerHTML = reports.map(report => `
        <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition">
          <div class="flex items-start justify-between mb-2">
            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-1">
                <span class="font-semibold text-gray-800">#${report.reportNumber}</span>
                ${getTypeBadge(report.type)}
              </div>
              <p class="text-sm text-gray-600 line-clamp-2">${report.summary}</p>
            </div>
          </div>
          <div class="flex items-center justify-between mt-3 pt-3 border-t border-gray-100">
            <div class="flex items-center space-x-4 text-xs text-gray-500">
              <span><i class="fas fa-map-marker-alt mr-1"></i>${report.location}</span>
              <span><i class="fas fa-clock mr-1"></i>${formatRelativeTime(report.createdAt)}</span>
            </div>
            <div class="flex items-center space-x-2">
              ${getUrgencyBadge(report.urgency)}
              ${getStatusBadge(report.status)}
            </div>
          </div>
        </div>
      `).join('');
    } else {
      container.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <i class="fas fa-inbox text-4xl mb-2"></i>
          <p>Belum ada laporan</p>
        </div>
      `;
    }
  } catch (error) {
    console.error('Failed to load recent reports:', error);
    document.getElementById('recentReports').innerHTML = `
      <div class="text-center py-8 text-red-500">
        <i class="fas fa-exclamation-triangle text-4xl mb-2"></i>
        <p>Gagal memuat laporan terbaru</p>
      </div>
    `;
  }
}

// Refresh data
async function refreshData() {
  const btn = document.querySelector('button[onclick="refreshData()"]');
  const icon = btn.querySelector('i');

  icon.classList.add('fa-spin');
  btn.disabled = true;

  await loadDashboard();

  icon.classList.remove('fa-spin');
  btn.disabled = false;
}

// Show error message
function showError(message) {
  // You can implement a toast notification here
  console.error(message);
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
  loadDashboard();

  // Auto-refresh every 30 seconds
  setInterval(loadDashboard, 30000);
});
