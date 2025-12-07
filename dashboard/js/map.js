// Map Page Logic
let map = null;
let markers = [];
let allReports = [];

// Initialize map
function initMap() {
  // Default center: Indonesia (adjust based on your deployment area)
  const defaultCenter = [-6.2088, 106.8456]; // Jakarta
  const defaultZoom = 5;

  map = L.map('map').setView(defaultCenter, defaultZoom);

  // Add OpenStreetMap tiles
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19,
  }).addTo(map);

  // Load reports
  loadMapReports();
}

// Load reports with coordinates
async function loadMapReports() {
  try {
    const data = await authFetch('/api/reports?hasCoordinates=true&limit=1000');

    if (data.success) {
      allReports = data.reports || [];
      updateMapMarkers();
    }
  } catch (error) {
    console.error('Failed to load map reports:', error);
    alert('Gagal memuat data peta');
  }
}

// Update map markers based on filters
function updateMapMarkers() {
  // Clear existing markers
  markers.forEach(marker => map.removeLayer(marker));
  markers = [];

  // Get filter states
  const filters = {
    types: {
      KORBAN: document.getElementById('filterKorban').checked,
      KEBUTUHAN: document.getElementById('filterKebutuhan').checked,
    },
    urgency: {
      CRITICAL: document.getElementById('filterCritical').checked,
      HIGH: document.getElementById('filterHigh').checked,
      MEDIUM: document.getElementById('filterMedium').checked,
      LOW: document.getElementById('filterLow').checked,
    },
  };

  // Filter reports
  const filteredReports = allReports.filter(report => {
    if (!report.coordinates) return false;
    if (!filters.types[report.type]) return false;
    if (!filters.urgency[report.urgency]) return false;
    return true;
  });

  // Add markers for filtered reports
  filteredReports.forEach(report => {
    const marker = createMarker(report);
    if (marker) {
      markers.push(marker);
      marker.addTo(map);
    }
  });

  // Update stats
  document.getElementById('visibleMarkers').textContent = markers.length;

  // Fit map to markers if any exist
  if (markers.length > 0) {
    const group = new L.featureGroup(markers);
    map.fitBounds(group.getBounds().pad(0.1));
  }
}

// Create marker for report
function createMarker(report) {
  if (!report.coordinates || !report.coordinates.lat || !report.coordinates.lng) {
    return null;
  }

  const { lat, lng } = report.coordinates;

  // Marker icon based on urgency and type
  const iconColor = getMarkerColor(report.urgency);
  const iconSymbol = report.type === 'KORBAN' ? 'ambulance' : 'box';

  const customIcon = L.divIcon({
    className: 'custom-marker',
    html: `<div style="
      background-color: ${iconColor};
      width: 32px;
      height: 32px;
      border-radius: 50%;
      border: 3px solid white;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      font-size: 14px;
    "><i class="fas fa-${iconSymbol}"></i></div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
    popupAnchor: [0, -16],
  });

  const marker = L.marker([lat, lng], { icon: customIcon });

  // Popup content
  const popupContent = `
    <div style="min-width: 250px;">
      <div style="font-weight: bold; font-size: 16px; margin-bottom: 8px;">
        #${report.reportNumber}
      </div>
      <div style="margin-bottom: 8px;">
        ${getTypeBadge(report.type)}
        ${getUrgencyBadge(report.urgency)}
      </div>
      <div style="margin-bottom: 8px;">
        <strong>Lokasi:</strong><br>
        ${report.location}
      </div>
      <div style="margin-bottom: 8px;">
        <strong>Ringkasan:</strong><br>
        ${report.summary}
      </div>
      ${report.description ? `
        <div style="margin-bottom: 8px;">
          <strong>Detail:</strong><br>
          <div style="max-height: 100px; overflow-y: auto; font-size: 12px; color: #666;">
            ${report.description.substring(0, 200)}${report.description.length > 200 ? '...' : ''}
          </div>
        </div>
      ` : ''}
      <div style="margin-bottom: 8px;">
        ${getStatusBadge(report.status)}
      </div>
      <div style="font-size: 12px; color: #666; margin-bottom: 8px;">
        <i class="fas fa-clock"></i> ${formatRelativeTime(report.createdAt)}
      </div>
      <a href="./reports.html?id=${report.id}" target="_blank" style="
        display: inline-block;
        background-color: #2563eb;
        color: white;
        padding: 6px 12px;
        border-radius: 6px;
        text-decoration: none;
        font-size: 14px;
        margin-top: 8px;
      ">
        <i class="fas fa-eye"></i> Lihat Detail
      </a>
    </div>
  `;

  marker.bindPopup(popupContent);

  return marker;
}

// Get marker color based on urgency
function getMarkerColor(urgency) {
  const colors = {
    CRITICAL: '#dc2626', // red-600
    HIGH: '#ea580c',    // orange-600
    MEDIUM: '#eab308',  // yellow-500
    LOW: '#16a34a',     // green-600
  };
  return colors[urgency] || '#6b7280'; // gray-500 default
}

// Update map filters
function updateMapFilters() {
  updateMapMarkers();
}

// Refresh map
async function refreshMap() {
  const btn = document.querySelector('button[onclick="refreshMap()"]');
  const icon = btn.querySelector('i');

  icon.classList.add('fa-spin');
  btn.disabled = true;

  await loadMapReports();

  icon.classList.remove('fa-spin');
  btn.disabled = false;
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  initMap();

  // Auto-refresh every 60 seconds
  setInterval(loadMapReports, 60000);
});
