// Users Page Logic
let currentPage = 1;
let currentFilters = {
  role: '',
  active: '',
  search: '',
};

// Load users with filters
async function loadUsers(page = 1) {
  try {
    currentPage = page;

    // Build query string
    const params = new URLSearchParams({
      page: currentPage,
      limit: 20,
    });

    if (currentFilters.role) params.append('role', currentFilters.role);
    if (currentFilters.active !== '') params.append('isActive', currentFilters.active);
    if (currentFilters.search) params.append('search', currentFilters.search);

    const data = await authFetch(`/api/users?${params.toString()}`);

    if (data.success) {
      displayUsers(data.users);
      if (data.pagination) {
        displayPagination(data.pagination);
      }
    }
  } catch (error) {
    console.error('Failed to load users:', error);
    document.getElementById('usersTableBody').innerHTML = `
      <tr>
        <td colspan="6" class="px-6 py-8 text-center text-red-600">
          <i class="fas fa-exclamation-triangle mr-2"></i>
          Gagal memuat data pengguna
        </td>
      </tr>
    `;
  }
}

// Display users
function displayUsers(users) {
  const tbody = document.getElementById('usersTableBody');

  if (!users || users.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="6" class="px-6 py-8 text-center text-gray-500">
          <i class="fas fa-users text-4xl mb-2"></i>
          <p>Tidak ada pengguna yang ditemukan</p>
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = users.map(user => `
    <tr class="hover:bg-gray-50">
      <td class="px-6 py-4">
        <div class="flex items-center">
          <div class="bg-gray-200 w-10 h-10 rounded-full flex items-center justify-center mr-3">
            <i class="fas fa-user text-gray-600"></i>
          </div>
          <div>
            <p class="font-semibold text-gray-800">${user.name}</p>
            <p class="text-sm text-gray-500">@${user.username}</p>
          </div>
        </div>
      </td>
      <td class="px-6 py-4">
        ${getRoleBadge(user.role)}
      </td>
      <td class="px-6 py-4 text-sm text-gray-600">
        ${user.email ? `<p><i class="fas fa-envelope mr-1"></i>${user.email}</p>` : ''}
        ${user.phone ? `<p><i class="fas fa-phone mr-1"></i>${user.phone}</p>` : ''}
      </td>
      <td class="px-6 py-4">
        ${user.isActive
          ? '<span class="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold">Aktif</span>'
          : '<span class="px-2 py-1 bg-red-100 text-red-700 rounded-full text-xs font-semibold">Nonaktif</span>'
        }
      </td>
      <td class="px-6 py-4 text-sm text-gray-600">
        ${formatDate(user.createdAt)}
      </td>
      <td class="px-6 py-4 text-right">
        <button onclick="editUser('${user.id}')" class="text-blue-600 hover:text-blue-800 mr-3" title="Edit">
          <i class="fas fa-edit"></i>
        </button>
        <button onclick="toggleUserStatus('${user.id}', ${!user.isActive})" class="text-${user.isActive ? 'red' : 'green'}-600 hover:text-${user.isActive ? 'red' : 'green'}-800 mr-3" title="${user.isActive ? 'Nonaktifkan' : 'Aktifkan'}">
          <i class="fas fa-${user.isActive ? 'ban' : 'check-circle'}"></i>
        </button>
        <button onclick="deleteUser('${user.id}')" class="text-red-600 hover:text-red-800" title="Hapus">
          <i class="fas fa-trash"></i>
        </button>
      </td>
    </tr>
  `).join('');
}

// Get role badge
function getRoleBadge(role) {
  const badges = {
    ADMIN: '<span class="px-2 py-1 bg-purple-100 text-purple-700 rounded-full text-xs font-semibold"><i class="fas fa-crown mr-1"></i>Admin</span>',
    OPERATOR: '<span class="px-2 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-semibold"><i class="fas fa-headset mr-1"></i>Operator</span>',
    VOLUNTEER: '<span class="px-2 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold"><i class="fas fa-hands-helping mr-1"></i>Relawan</span>',
  };
  return badges[role] || role;
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
    pages.push(`<button onclick="loadUsers(${currentPage - 1})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"><i class="fas fa-chevron-left"></i></button>`);
  }

  // Page numbers
  for (let i = 1; i <= totalPages; i++) {
    if (i === currentPage) {
      pages.push(`<button class="px-4 py-2 bg-blue-600 text-white rounded-lg">${i}</button>`);
    } else if (i === 1 || i === totalPages || (i >= currentPage - 2 && i <= currentPage + 2)) {
      pages.push(`<button onclick="loadUsers(${i})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">${i}</button>`);
    } else if (i === currentPage - 3 || i === currentPage + 3) {
      pages.push(`<span class="px-2">...</span>`);
    }
  }

  // Next button
  if (currentPage < totalPages) {
    pages.push(`<button onclick="loadUsers(${currentPage + 1})" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"><i class="fas fa-chevron-right"></i></button>`);
  }

  container.innerHTML = `
    <div class="flex items-center space-x-2">
      ${pages.join('')}
    </div>
    <p class="text-sm text-gray-600 mt-4 text-center">Total: ${total} pengguna</p>
  `;
}

// Apply filters
function applyFilters() {
  currentFilters = {
    role: document.getElementById('filterRole').value,
    active: document.getElementById('filterActive').value,
    search: document.getElementById('searchQuery').value,
  };
  loadUsers(1);
}

// Refresh users
async function refreshUsers() {
  const btn = document.querySelector('button[onclick="refreshUsers()"]');
  const icon = btn.querySelector('i');

  icon.classList.add('fa-spin');
  btn.disabled = true;

  await loadUsers(currentPage);

  icon.classList.remove('fa-spin');
  btn.disabled = false;
}

// Show add user modal
function showAddUserModal() {
  document.getElementById('userModalTitle').textContent = 'Tambah Pengguna';
  document.getElementById('userForm').reset();
  document.getElementById('userId').value = '';
  document.getElementById('userModal').classList.remove('hidden');
}

// Edit user
async function editUser(userId) {
  try {
    const data = await authFetch(`/api/users/${userId}`);

    if (data.success) {
      const user = data.data || data.user;

      document.getElementById('userModalTitle').textContent = 'Edit Pengguna';
      document.getElementById('userId').value = user.id;
      document.getElementById('phoneNumber').value = user.phoneNumber;
      document.getElementById('name').value = user.name;
      document.getElementById('organization').value = user.organization || '';
      document.getElementById('role').value = user.role;
      document.getElementById('isActive').checked = user.isActive;

      document.getElementById('userModal').classList.remove('hidden');
    }
  } catch (error) {
    console.error('Failed to load user:', error);
    alert('Gagal memuat data pengguna');
  }
}

// Close user modal
function closeUserModal() {
  document.getElementById('userModal').classList.add('hidden');
}

// Handle user form submit
document.getElementById('userForm').addEventListener('submit', async (e) => {
  e.preventDefault();

  const userId = document.getElementById('userId').value;
  const formData = {
    phoneNumber: document.getElementById('phoneNumber').value,
    name: document.getElementById('name').value,
    organization: document.getElementById('organization').value || null,
    role: document.getElementById('role').value,
    isActive: document.getElementById('isActive').checked,
  };

  try {
    let data;

    if (userId) {
      // Update existing user
      data = await authFetch(`/api/users/${userId}`, {
        method: 'PATCH',
        body: JSON.stringify(formData),
      });
    } else {
      // Create new user
      data = await authFetch('/api/users', {
        method: 'POST',
        body: JSON.stringify(formData),
      });
    }

    if (data.success) {
      closeUserModal();
      await loadUsers(currentPage);
      alert(userId ? 'Pengguna berhasil diupdate' : 'Pengguna berhasil ditambahkan');
    } else {
      alert('Gagal menyimpan pengguna: ' + (data.message || 'Unknown error'));
    }
  } catch (error) {
    console.error('Failed to save user:', error);
    alert('Gagal menyimpan pengguna');
  }
});

// Toggle user status
async function toggleUserStatus(userId, newStatus) {
  if (!confirm(`${newStatus ? 'Aktifkan' : 'Nonaktifkan'} pengguna ini?`)) return;

  try {
    const data = await authFetch(`/api/users/${userId}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive: newStatus }),
    });

    if (data.success) {
      await loadUsers(currentPage);
      alert('Status pengguna berhasil diubah');
    } else {
      alert('Gagal mengubah status: ' + (data.message || 'Unknown error'));
    }
  } catch (error) {
    console.error('Failed to toggle user status:', error);
    alert('Gagal mengubah status pengguna');
  }
}

// Delete user
async function deleteUser(userId) {
  if (!confirm('Hapus pengguna ini? Tindakan ini tidak dapat dibatalkan.')) return;

  try {
    const data = await authFetch(`/api/users/${userId}`, {
      method: 'DELETE',
    });

    if (data.success) {
      await loadUsers(currentPage);
      alert('Pengguna berhasil dihapus');
    } else {
      alert('Gagal menghapus pengguna: ' + (data.message || 'Unknown error'));
    }
  } catch (error) {
    console.error('Failed to delete user:', error);
    alert('Gagal menghapus pengguna');
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  loadUsers(1);
});
