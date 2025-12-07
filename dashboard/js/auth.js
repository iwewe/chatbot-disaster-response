// API Configuration
const API_BASE = window.location.hostname === 'localhost'
  ? 'http://localhost:3000'
  : window.location.origin;

// Check authentication
function checkAuth() {
  const token = localStorage.getItem('auth_token');
  const user = localStorage.getItem('user');

  if (!token || !user) {
    window.location.href = './index.html';
    return null;
  }

  try {
    const userData = JSON.parse(user);
    // Update user info in sidebar
    const userNameEl = document.getElementById('userName');
    const userRoleEl = document.getElementById('userRole');
    if (userNameEl) userNameEl.textContent = userData.name || userData.username;
    if (userRoleEl) userRoleEl.textContent = userData.role || 'User';
    return userData;
  } catch {
    logout();
    return null;
  }
}

// Logout function
function logout() {
  localStorage.removeItem('auth_token');
  localStorage.removeItem('user');
  window.location.href = './index.html';
}

// API fetch with auth
async function authFetch(url, options = {}) {
  const token = localStorage.getItem('auth_token');

  const defaultOptions = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
  };

  const mergedOptions = {
    ...defaultOptions,
    ...options,
    headers: {
      ...defaultOptions.headers,
      ...options.headers,
    },
  };

  try {
    const response = await fetch(`${API_BASE}${url}`, mergedOptions);

    // Handle unauthorized
    if (response.status === 401) {
      logout();
      throw new Error('Unauthorized');
    }

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Request failed');
    }

    return data;
  } catch (error) {
    console.error('API Error:', error);
    throw error;
  }
}

// Format date
function formatDate(dateString) {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
}

// Format relative time
function formatRelativeTime(dateString) {
  const date = new Date(dateString);
  const now = new Date();
  const diff = now - date;
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (seconds < 60) return 'Baru saja';
  if (minutes < 60) return `${minutes} menit yang lalu`;
  if (hours < 24) return `${hours} jam yang lalu`;
  if (days < 7) return `${days} hari yang lalu`;
  return formatDate(dateString);
}

// Get urgency badge HTML
function getUrgencyBadge(urgency) {
  const badges = {
    CRITICAL: '<span class="px-2 py-1 bg-red-100 text-red-700 rounded-full text-xs font-semibold"><i class="fas fa-exclamation-circle mr-1"></i>KRITIS</span>',
    HIGH: '<span class="px-2 py-1 bg-orange-100 text-orange-700 rounded-full text-xs font-semibold"><i class="fas fa-exclamation-triangle mr-1"></i>TINGGI</span>',
    MEDIUM: '<span class="px-2 py-1 bg-yellow-100 text-yellow-700 rounded-full text-xs font-semibold">SEDANG</span>',
    LOW: '<span class="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold">RENDAH</span>',
  };
  return badges[urgency] || urgency;
}

// Get status badge HTML
function getStatusBadge(status) {
  const badges = {
    PENDING_VERIFICATION: '<span class="px-2 py-1 bg-yellow-100 text-yellow-700 rounded-full text-xs font-semibold"><i class="fas fa-clock mr-1"></i>Menunggu Verifikasi</span>',
    VERIFIED: '<span class="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold"><i class="fas fa-check-circle mr-1"></i>Terverifikasi</span>',
    IN_PROGRESS: '<span class="px-2 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-semibold"><i class="fas fa-spinner mr-1"></i>Dalam Proses</span>',
    RESOLVED: '<span class="px-2 py-1 bg-gray-100 text-gray-700 rounded-full text-xs font-semibold"><i class="fas fa-check-double mr-1"></i>Selesai</span>',
    REJECTED: '<span class="px-2 py-1 bg-red-100 text-red-700 rounded-full text-xs font-semibold"><i class="fas fa-times-circle mr-1"></i>Ditolak</span>',
  };
  return badges[status] || status;
}

// Get type badge HTML
function getTypeBadge(type) {
  const badges = {
    KORBAN: '<span class="px-2 py-1 bg-red-50 text-red-700 rounded text-xs font-semibold"><i class="fas fa-ambulance mr-1"></i>Korban</span>',
    KEBUTUHAN: '<span class="px-2 py-1 bg-blue-50 text-blue-700 rounded text-xs font-semibold"><i class="fas fa-box mr-1"></i>Kebutuhan</span>',
  };
  return badges[type] || type;
}

// Check auth on page load
if (window.location.pathname.includes('dashboard.html') ||
    window.location.pathname.includes('reports.html') ||
    window.location.pathname.includes('users.html') ||
    window.location.pathname.includes('map.html')) {
  checkAuth();
}
