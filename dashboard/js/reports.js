// Reports Page Logic
let currentPage = 1;
let currentFilters = {
  status: '',
  type: '',
  urgency: '',
  search: '',
};

// Load reports with filters
async function loadReports(page = 1) {
  try {
    currentPage = page;

    // Build query string
    const params = new URLSearchParams({
      page: currentPage,
      limit: 10,
      sort: 'createdAt:desc',
    });

    if (currentFilters.status) params.append('status', currentFilters.status);
    if (currentFilters.type) params.append('type', currentFilters.type);
    if (currentFilters.urgency) params.append('urgency', currentFilters.urgency);
    if (currentFilters.search) params.append('search', currentFilters.search);

    const data = await authFetch(`/api/reports?${params.toString()}`);

    if (data.success) {
      displayReports(data.reports);
      displayPagination(data.pagination);
    }
  } catch (error) {
    console.error('Failed to load reports:', error);
    document.getElementById('reportsList').innerHTML = `
      <div class="bg-red-50 border border-red-200 text-red-700 px-6 py-4 rounded-lg">
        <i class="fas fa-exclamation-triangle mr-2"></i>
        Gagal memuat laporan. Silakan coba lagi.
      </div>
    `;
  }
}

// Display reports
function displayReports(reports) {
  const container = document.getElementById('reportsList');

  if (!reports || reports.length === 0) {
    container.innerHTML = `
      <div class="bg-white rounded-xl shadow-sm p-12 text-center">
        <i class="fas fa-inbox text-6xl text-gray-300 mb-4"></i>
        <p class="text-gray-500 text-lg">Tidak ada laporan yang ditemukan</p>
      </div>
    `;
    return;
  }

  container.innerHTML = reports.map(report => `
    <div class="bg-white rounded-xl shadow-sm p-6 hover:shadow-md transition cursor-pointer" onclick="viewReport('${report.id}')">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <div class="flex items-center space-x-3 mb-2">
            <span class="font-bold text-lg text-gray-800">#${report.reportNumber}</span>
            ${getTypeBadge(report.type)}
            ${getUrgencyBadge(report.urgency)}
            ${getStatusBadge(report.status)}
          </div>
          <h3 class="text-gray-800 font-semibold mb-2">${report.summary}</h3>
          <div class="flex items-center space-x-4 text-sm text-gray-600">
            <span><i class="fas fa-map-marker-alt mr-1"></i>${report.location}</span>
            <span><i class="fas fa-phone mr-1"></i>${report.phoneNumber}</span>
            <span><i class="fas fa-clock mr-1"></i>${formatRelativeTime(report.createdAt)}</span>
          </div>
        </div>
        <div class="text-right">
          <button onclick="event.stopPropagation(); viewReport('${report.id}')" class="text-blue-600 hover:text-blue-700">
            <i class="fas fa-eye text-xl"></i>
          </button>
        </div>
      </div>

      ${report.description ? `
        <div class="mt-3 pt-3 border-t border-gray-100">
          <p class="text-sm text-gray-600 line-clamp-2">${report.description}</p>
        </div>
      ` : ''}

      ${report.assignedTo ? `
        <div class="mt-3 pt-3 border-t border-gray-100 flex items-center space-x-2 text-sm text-gray-600">
          <i class="fas fa-user-check"></i>
          <span>Ditangani oleh: <strong>${report.assignedTo.name}</strong></span>
        </div>
      ` : ''}
    </div>
  `).join('');
}

// Display pagination
function displayPagination(pagination) {
  if (!pagination) return;

  const container = document.getElementById('pagination');
  const { currentPage, totalPages, total } = pagination;

  if (totalPages <= 1) {
    container.innerHTML = '';
    return;
  }

  let pages = [];

  // Previous button
  if (currentPage > 1) {
    pages.push(`<button onclick="loadReports(${currentPage - 1})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"><i class="fas fa-chevron-left"></i></button>`);
  }

  // Page numbers
  for (let i = 1; i <= totalPages; i++) {
    if (i === currentPage) {
      pages.push(`<button class="px-4 py-2 bg-blue-600 text-white rounded-lg">${i}</button>`);
    } else if (i === 1 || i === totalPages || (i >= currentPage - 2 && i <= currentPage + 2)) {
      pages.push(`<button onclick="loadReports(${i})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">${i}</button>`);
    } else if (i === currentPage - 3 || i === currentPage + 3) {
      pages.push(`<span class="px-2">...</span>`);
    }
  }

  // Next button
  if (currentPage < totalPages) {
    pages.push(`<button onclick="loadReports(${currentPage + 1})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"><i class="fas fa-chevron-right"></i></button>`);
  }

  container.innerHTML = `
    <div class="flex items-center space-x-2">
      ${pages.join('')}
    </div>
    <p class="text-sm text-gray-600 mt-4 text-center">Total: ${total} laporan</p>
  `;
}

// Apply filters
function applyFilters() {
  currentFilters = {
    status: document.getElementById('filterStatus').value,
    type: document.getElementById('filterType').value,
    urgency: document.getElementById('filterUrgency').value,
    search: document.getElementById('searchQuery').value,
  };
  loadReports(1);
}

// Refresh reports
async function refreshReports() {
  const btn = document.querySelector('button[onclick="refreshReports()"]');
  const icon = btn.querySelector('i');

  icon.classList.add('fa-spin');
  btn.disabled = true;

  await loadReports(currentPage);

  icon.classList.remove('fa-spin');
  btn.disabled = false;
}

// View report detail
async function viewReport(reportId) {
  try {
    const data = await authFetch(`/api/reports/${reportId}`);

    if (data.success) {
      displayReportModal(data.report);
    }
  } catch (error) {
    console.error('Failed to load report detail:', error);
    alert('Gagal memuat detail laporan');
  }
}

// Display report modal
function displayReportModal(report) {
  const modal = document.getElementById('reportModal');
  const content = document.getElementById('reportModalContent');

  content.innerHTML = `
    <div class="space-y-6">
      <!-- Header Info -->
      <div class="flex items-start justify-between">
        <div>
          <h3 class="text-xl font-bold text-gray-800 mb-2">#${report.reportNumber}</h3>
          <div class="flex items-center space-x-2">
            ${getTypeBadge(report.type)}
            ${getUrgencyBadge(report.urgency)}
            ${getStatusBadge(report.status)}
          </div>
        </div>
        <div class="text-right text-sm text-gray-600">
          <p><i class="fas fa-clock mr-1"></i>${formatDate(report.createdAt)}</p>
          ${report.updatedAt && report.updatedAt !== report.createdAt ? `
            <p class="text-xs mt-1">Update: ${formatRelativeTime(report.updatedAt)}</p>
          ` : ''}
        </div>
      </div>

      <!-- Summary -->
      <div>
        <h4 class="font-semibold text-gray-800 mb-2">Ringkasan</h4>
        <p class="text-gray-700">${report.summary}</p>
      </div>

      <!-- Description -->
      ${report.description ? `
        <div>
          <h4 class="font-semibold text-gray-800 mb-2">Detail</h4>
          <p class="text-gray-700 whitespace-pre-wrap">${report.description}</p>
        </div>
      ` : ''}

      <!-- Contact & Location -->
      <div class="grid grid-cols-2 gap-4">
        <div>
          <h4 class="font-semibold text-gray-800 mb-2">Kontak</h4>
          <p class="text-gray-700"><i class="fas fa-phone mr-2"></i>${report.phoneNumber}</p>
          ${report.reporterName ? `<p class="text-gray-700"><i class="fas fa-user mr-2"></i>${report.reporterName}</p>` : ''}
        </div>
        <div>
          <h4 class="font-semibold text-gray-800 mb-2">Lokasi</h4>
          <p class="text-gray-700"><i class="fas fa-map-marker-alt mr-2"></i>${report.location}</p>
          ${report.coordinates ? `
            <a href="https://www.google.com/maps?q=${report.coordinates.lat},${report.coordinates.lng}" target="_blank" class="text-blue-600 hover:underline text-sm">
              <i class="fas fa-external-link-alt mr-1"></i>Lihat di peta
            </a>
          ` : ''}
        </div>
      </div>

      <!-- Extracted Data -->
      ${report.extractedData && Object.keys(report.extractedData).length > 0 ? `
        <div>
          <h4 class="font-semibold text-gray-800 mb-2">Data Terstruktur</h4>
          <div class="bg-gray-50 rounded-lg p-4">
            <pre class="text-sm text-gray-700 whitespace-pre-wrap">${JSON.stringify(report.extractedData, null, 2)}</pre>
          </div>
        </div>
      ` : ''}

      <!-- Media -->
      ${report.media && report.media.length > 0 ? `
        <div>
          <h4 class="font-semibold text-gray-800 mb-2">Media (${report.media.length})</h4>
          <div class="grid grid-cols-3 gap-4">
            ${report.media.map(m => `
              <div class="relative">
                ${m.type === 'IMAGE' ? `
                  <img src="${m.url}" class="w-full h-32 object-cover rounded-lg" alt="Media">
                ` : `
                  <div class="w-full h-32 bg-gray-200 rounded-lg flex items-center justify-center">
                    <i class="fas fa-${m.type === 'VIDEO' ? 'video' : 'file'} text-3xl text-gray-400"></i>
                  </div>
                `}
                <a href="${m.url}" target="_blank" class="absolute bottom-2 right-2 bg-white px-2 py-1 rounded text-xs">
                  <i class="fas fa-external-link-alt"></i>
                </a>
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}

      <!-- Actions -->
      <div class="pt-4 border-t border-gray-200">
        <h4 class="font-semibold text-gray-800 mb-3">Aksi</h4>
        <div class="flex items-center space-x-3">
          ${report.status === 'PENDING_VERIFICATION' ? `
            <button onclick="updateReportStatus('${report.id}', 'VERIFIED')" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
              <i class="fas fa-check mr-2"></i>Verifikasi
            </button>
            <button onclick="updateReportStatus('${report.id}', 'REJECTED')" class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg">
              <i class="fas fa-times mr-2"></i>Tolak
            </button>
          ` : ''}
          ${report.status === 'VERIFIED' ? `
            <button onclick="updateReportStatus('${report.id}', 'IN_PROGRESS')" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg">
              <i class="fas fa-play mr-2"></i>Mulai Proses
            </button>
          ` : ''}
          ${report.status === 'IN_PROGRESS' ? `
            <button onclick="updateReportStatus('${report.id}', 'RESOLVED')" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg">
              <i class="fas fa-check-double mr-2"></i>Selesaikan
            </button>
          ` : ''}
          <button onclick="closeReportModal()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded-lg">
            Tutup
          </button>
        </div>
      </div>
    </div>
  `;

  modal.classList.remove('hidden');
}

// Close report modal
function closeReportModal() {
  document.getElementById('reportModal').classList.add('hidden');
}

// Update report status
async function updateReportStatus(reportId, newStatus) {
  if (!confirm(`Ubah status laporan menjadi ${newStatus}?`)) return;

  try {
    const data = await authFetch(`/api/reports/${reportId}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status: newStatus }),
    });

    if (data.success) {
      closeReportModal();
      await loadReports(currentPage);
      alert('Status laporan berhasil diubah');
    } else {
      alert('Gagal mengubah status: ' + (data.message || 'Unknown error'));
    }
  } catch (error) {
    console.error('Failed to update report status:', error);
    alert('Gagal mengubah status laporan');
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  loadReports(1);
});
