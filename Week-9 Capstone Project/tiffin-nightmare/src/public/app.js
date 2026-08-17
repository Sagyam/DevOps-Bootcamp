/**
 * ==========================================================================
 * TIFFIN BOX — CLIENT APPLICATION LOGIC (CRUD & REAL-TIME ORDERING)
 * ==========================================================================
 */

document.addEventListener('DOMContentLoaded', () => {
  // Application State
  let menuCatalog = [];
  let ordersList = [];
  let selectedDish = null;
  let activeFilter = 'ALL';
  let recentOrders = JSON.parse(localStorage.getItem('tiffin_recent_orders') || '[]');

  // Dish icons mapping
  const dishIcons = {
    'dal bhat': '🍛',
    'momo': '🥟',
    'thukpa': '🍜',
    'sel roti': '🍩',
    'khaja': '🍱',
    'chowmein': '🍝',
    'tea': '☕',
    'default': '🍲'
  };

  function getDishIcon(name = '') {
    const lower = name.toLowerCase();
    for (const [key, icon] of Object.entries(dishIcons)) {
      if (lower.includes(key)) return icon;
    }
    return dishIcons.default;
  }

  // DOM Elements - Navigation
  const navTabs = document.querySelectorAll('.nav-tab');
  const tabContents = document.querySelectorAll('.tab-content');
  const navOrdersCount = document.getElementById('nav-orders-count');
  const kitchenStatusText = document.getElementById('kitchen-status-text');

  // DOM Elements - Menu & Checkout
  const menuGrid = document.getElementById('menu-items-grid');
  const btnReloadMenu = document.getElementById('btn-reload-menu');
  const orderForm = document.getElementById('customer-order-form');
  const checkoutDishName = document.getElementById('checkout-dish-name');
  const checkoutDishPrice = document.getElementById('checkout-dish-price');
  const checkoutItemId = document.getElementById('checkout-item-id');
  const checkoutItemHint = document.getElementById('checkout-item-hint');
  const checkoutQuantity = document.getElementById('checkout-quantity');
  const btnQtyDec = document.getElementById('btn-qty-dec');
  const btnQtyInc = document.getElementById('btn-qty-inc');
  const checkoutPhone = document.getElementById('checkout-phone');
  const checkoutNote = document.getElementById('checkout-note');
  const billSubtotal = document.getElementById('bill-subtotal');
  const billTotal = document.getElementById('bill-total');
  const btnPlaceOrder = document.getElementById('btn-place-order');
  const noteChips = document.querySelectorAll('.chip-btn');

  // Success Confirmation Box
  const orderSuccessCard = document.getElementById('order-success-card');
  const successOrderId = document.getElementById('success-order-id');
  const successItemName = document.getElementById('success-item-name');
  const successQty = document.getElementById('success-qty');
  const successStatus = document.getElementById('success-status');
  const btnTrackNow = document.getElementById('btn-track-now');
  const btnOrderAnother = document.getElementById('btn-order-another');

  // DOM Elements - Orders Dashboard
  const ordersContainer = document.getElementById('orders-container');
  const btnRefreshOrders = document.getElementById('btn-refresh-orders');
  const filterChips = document.querySelectorAll('.filter-chip');
  const countAll = document.getElementById('count-all');
  const countPending = document.getElementById('count-pending');
  const countPreparing = document.getElementById('count-preparing');
  const countDelivered = document.getElementById('count-delivered');
  const countCancelled = document.getElementById('count-cancelled');

  // DOM Elements - Track Order
  const trackSearchForm = document.getElementById('track-search-form');
  const trackSearchInput = document.getElementById('track-search-input');
  const recentChipsContainer = document.getElementById('recent-chips-container');
  const trackResultBox = document.getElementById('track-result-box');
  const trackErrorBox = document.getElementById('track-error-box');
  const trackStep1 = document.getElementById('track-step-1');
  const trackStep2 = document.getElementById('track-step-2');
  const trackStep3 = document.getElementById('track-step-3');
  const trackBar1 = document.getElementById('track-bar-1');
  const trackBar2 = document.getElementById('track-bar-2');
  const trackInfoId = document.getElementById('track-info-id');
  const trackInfoDish = document.getElementById('track-info-dish');
  const trackInfoQty = document.getElementById('track-info-qty');
  const trackInfoStatus = document.getElementById('track-info-status');
  const trackInfoNote = document.getElementById('track-info-note');
  const trackNoteWrapper = document.getElementById('track-note-wrapper');

  // DOM Elements - Menu Manager (Admin CRUD)
  const addMenuForm = document.getElementById('add-menu-form');
  const adminDishName = document.getElementById('admin-dish-name');
  const adminDishPrice = document.getElementById('admin-dish-price');
  const adminDishAvail = document.getElementById('admin-dish-avail');
  const adminMenuList = document.getElementById('admin-menu-list');

  // ----------------------------------------------------
  // Toast Helper
  // ----------------------------------------------------
  function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    const icon = type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️';
    toast.innerHTML = `<span>${icon}</span><span>${message}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(100%)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3500);
  }

  // ----------------------------------------------------
  // Navigation Tabs
  // ----------------------------------------------------
  navTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      navTabs.forEach(t => {
        t.classList.remove('active');
        t.setAttribute('aria-selected', 'false');
      });
      tabContents.forEach(c => c.classList.remove('active'));

      tab.classList.add('active');
      tab.setAttribute('aria-selected', 'true');
      const targetId = tab.getAttribute('data-tab');
      const targetContent = document.getElementById(targetId);
      if (targetContent) targetContent.classList.add('active');

      // Auto-fetch data for tabs
      if (targetId === 'tab-orders') fetchOrders();
      if (targetId === 'tab-admin') renderAdminMenu();
    });
  });

  // ----------------------------------------------------
  // Menu Catalog (Read & Select)
  // ----------------------------------------------------
  async function fetchMenu() {
    menuGrid.innerHTML = `
      <div class="loading-box">
        <div class="spinner"></div>
        <span>Loading today's fresh menu...</span>
      </div>
    `;

    try {
      const res = await fetch('/menu');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      menuCatalog = Array.isArray(data) ? data : (data.items || []);
      renderMenuCards(menuCatalog);
      renderAdminMenu();
      kitchenStatusText.textContent = 'Kitchen Online (Live)';
    } catch (err) {
      menuGrid.innerHTML = `
        <div class="alert-box alert-error">
          <span>Failed to load menu: ${escapeHtml(err.message)}</span>
        </div>
      `;
      kitchenStatusText.textContent = 'Connecting...';
    }
  }

  function renderMenuCards(items) {
    if (!items || items.length === 0) {
      menuGrid.innerHTML = '<div class="text-center py-4 text-muted">No menu items found. Add dishes in Menu Manager!</div>';
      return;
    }

    menuGrid.innerHTML = '';
    items.forEach(item => {
      const isSelected = selectedDish && String(selectedDish.id) === String(item.id);
      const isAvailable = item.available !== false;
      const card = document.createElement('div');
      card.className = `menu-card ${isSelected ? 'selected' : ''}`;

      card.innerHTML = `
        <div class="card-top">
          <div class="dish-icon-wrap">${getDishIcon(item.name)}</div>
          <span class="badge ${isAvailable ? 'badge-success' : 'badge-danger'}">
            ${isAvailable ? 'In Stock' : 'Sold Out'}
          </span>
        </div>
        <div>
          <h4 class="dish-name">${escapeHtml(item.name)}</h4>
          <span class="dish-price">रू ${Number(item.price_npr || 0).toLocaleString()}</span>
        </div>
        <div class="dish-actions">
          <span class="text-muted text-sm">Fresh Lunch Set</span>
          <button class="btn btn-sm btn-primary btn-select-dish" data-id="${item.id}" ${!isAvailable ? 'disabled' : ''}>
            ${isSelected ? '✓ Selected' : 'Select Meal'}
          </button>
        </div>
      `;
      menuGrid.appendChild(card);
    });

    document.querySelectorAll('.btn-select-dish').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const dish = menuCatalog.find(d => String(d.id) === String(id));
        if (dish) selectDish(dish);
      });
    });
  }

  function selectDish(dish) {
    selectedDish = dish;
    checkoutItemId.value = dish.id;
    checkoutDishName.textContent = dish.name;
    checkoutDishPrice.textContent = `रू ${Number(dish.price_npr).toLocaleString()}`;
    checkoutItemHint.textContent = `Dish Code: #${dish.id}`;
    btnPlaceOrder.disabled = false;

    updateBillSummary();
    renderMenuCards(menuCatalog);
    showToast(`Selected ${dish.name}`, 'info');
  }

  function updateBillSummary() {
    if (!selectedDish) {
      billSubtotal.textContent = 'रू 0';
      billTotal.textContent = 'रू 0';
      btnPlaceOrder.textContent = 'Confirm & Place Order';
      return;
    }
    const qty = parseInt(checkoutQuantity.value, 10) || 1;
    const total = (selectedDish.price_npr || 0) * qty;
    billSubtotal.textContent = `रू ${total.toLocaleString()}`;
    billTotal.textContent = `रू ${total.toLocaleString()}`;
    btnPlaceOrder.textContent = `Place Order (रू ${total.toLocaleString()})`;
  }

  // Quantity Stepper Handlers
  btnQtyDec.addEventListener('click', () => {
    let val = parseInt(checkoutQuantity.value, 10) || 1;
    if (val > 1) {
      checkoutQuantity.value = val - 1;
      updateBillSummary();
    }
  });

  btnQtyInc.addEventListener('click', () => {
    let val = parseInt(checkoutQuantity.value, 10) || 1;
    if (val < 20) {
      checkoutQuantity.value = val + 1;
      updateBillSummary();
    }
  });

  checkoutQuantity.addEventListener('input', () => {
    let val = parseInt(checkoutQuantity.value, 10);
    if (isNaN(val) || val < 1) val = 1;
    if (val > 20) val = 20;
    checkoutQuantity.value = val;
    updateBillSummary();
  });

  // Note Chips
  noteChips.forEach(chip => {
    chip.addEventListener('click', () => {
      checkoutNote.value = chip.getAttribute('data-note');
      showToast('Instruction added', 'info');
    });
  });

  btnReloadMenu.addEventListener('click', () => {
    fetchMenu();
    showToast('Menu refreshed', 'info');
  });

  // ----------------------------------------------------
  // Place Customer Order (POST /orders)
  // ----------------------------------------------------
  orderForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!selectedDish) {
      showToast('Please select a dish from the menu', 'error');
      return;
    }

    const qty = parseInt(checkoutQuantity.value, 10);
    const phone = checkoutPhone.value.trim();
    const note = checkoutNote.value.trim();

    btnPlaceOrder.disabled = true;
    btnPlaceOrder.textContent = 'Placing Order...';

    try {
      const payload = {
        item_id: selectedDish.id,
        quantity: qty,
        customer_phone: phone,
        ...(note ? { note } : {})
      };

      const res = await fetch('/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const data = await res.json();

      if (res.ok || res.status === 201) {
        orderForm.classList.add('hidden');
        orderSuccessCard.classList.remove('hidden');

        successOrderId.textContent = data.id;
        successItemName.textContent = selectedDish.name;
        successQty.textContent = `${data.quantity} Portions`;
        successStatus.textContent = data.status || 'PENDING';

        // Save to recent orders
        saveRecentOrder(data.id, selectedDish.name);

        showToast('Order confirmed! Sending to kitchen...', 'success');

        // Refresh orders count
        fetchOrders();

        btnTrackNow.onclick = () => {
          trackSearchInput.value = data.id;
          document.querySelector('[data-tab="tab-track"]').click();
          queryOrder(data.id);
        };
      } else {
        showToast(`Order failed: ${data.details?.customer_phone || data.error || 'Check input'}`, 'error');
      }
    } catch (err) {
      showToast(`Network error: ${err.message}`, 'error');
    } finally {
      btnPlaceOrder.disabled = false;
      updateBillSummary();
    }
  });

  btnOrderAnother.addEventListener('click', () => {
    orderSuccessCard.classList.add('hidden');
    orderForm.classList.remove('hidden');
  });

  function saveRecentOrder(id, name) {
    recentOrders = recentOrders.filter(o => String(o.id) !== String(id));
    recentOrders.unshift({ id, name, time: new Date().toLocaleTimeString() });
    if (recentOrders.length > 5) recentOrders.pop();
    localStorage.setItem('tiffin_recent_orders', JSON.stringify(recentOrders));
    renderRecentChips();
  }

  // ----------------------------------------------------
  // Kitchen Dashboard (Read, Update Status, Delete Orders)
  // ----------------------------------------------------
  async function fetchOrders() {
    try {
      const res = await fetch('/orders');
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      ordersList = Array.isArray(data) ? data : (data.orders || []);
      renderOrdersList();
      updateOrderCounts();
    } catch (err) {
      ordersContainer.innerHTML = `
        <div class="alert-box alert-error">
          <span>Failed to load orders: ${escapeHtml(err.message)}</span>
        </div>
      `;
    }
  }

  function updateOrderCounts() {
    const total = ordersList.length;
    const pending = ordersList.filter(o => o.status === 'PENDING').length;
    const preparing = ordersList.filter(o => o.status === 'PREPARING').length;
    const delivered = ordersList.filter(o => o.status === 'DELIVERED').length;
    const cancelled = ordersList.filter(o => o.status === 'CANCELLED').length;

    countAll.textContent = total;
    countPending.textContent = pending;
    countPreparing.textContent = preparing;
    countDelivered.textContent = delivered;
    countCancelled.textContent = cancelled;
    navOrdersCount.textContent = total;
  }

  function renderOrdersList() {
    let filtered = ordersList;
    if (activeFilter !== 'ALL') {
      filtered = ordersList.filter(o => o.status === activeFilter);
    }

    if (filtered.length === 0) {
      ordersContainer.innerHTML = `
        <div class="text-center py-6 text-muted">
          No orders found under <b>${activeFilter}</b>. Place an order in the Menu tab!
        </div>
      `;
      return;
    }

    ordersContainer.innerHTML = '';
    filtered.forEach(order => {
      const card = document.createElement('div');
      card.className = 'kitchen-order-card';

      const statusBadgeClass = 
        order.status === 'DELIVERED' ? 'badge-success' :
        order.status === 'PREPARING' ? 'badge-info' :
        order.status === 'CANCELLED' ? 'badge-danger' : 'badge-warning';

      card.innerHTML = `
        <div class="order-main-info">
          <div class="order-top-row">
            <span class="order-id-tag">#${escapeHtml(String(order.id).substring(0, 8))}...</span>
            <span class="order-dish-title">${escapeHtml(order.item_name || 'Lunch Meal')}</span>
            <span class="badge ${statusBadgeClass}">${escapeHtml(order.status)}</span>
          </div>
          <div class="order-meta-row">
            <span><b>${order.quantity}</b> portions</span>
            ${order.customer_phone ? `<span>📞 ${escapeHtml(order.customer_phone)}</span>` : ''}
            ${order.created_at ? `<span>🕒 ${new Date(order.created_at).toLocaleTimeString()}</span>` : ''}
            ${order.note ? `<span class="order-note-badge">📝 ${escapeHtml(order.note)}</span>` : ''}
          </div>
        </div>

        <div class="order-action-buttons">
          ${order.status === 'PENDING' ? `
            <button class="btn btn-sm btn-secondary btn-update-status" data-id="${order.id}" data-status="PREPARING">
              🍳 Start Cooking
            </button>
          ` : ''}

          ${order.status === 'PREPARING' ? `
            <button class="btn btn-sm btn-primary btn-update-status" data-id="${order.id}" data-status="DELIVERED">
              🚚 Mark Delivered
            </button>
          ` : ''}

          ${order.status !== 'DELIVERED' && order.status !== 'CANCELLED' ? `
            <button class="btn btn-sm btn-outline btn-update-status" data-id="${order.id}" data-status="CANCELLED" title="Cancel Order">
              ❌
            </button>
          ` : ''}

          <button class="btn btn-sm btn-outline btn-delete-order" data-id="${order.id}" title="Delete Record">
            🗑️
          </button>
        </div>
      `;
      ordersContainer.appendChild(card);
    });

    // Attach Status Update Handlers
    document.querySelectorAll('.btn-update-status').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        const status = btn.getAttribute('data-status');
        await updateOrderStatus(id, status);
      });
    });

    // Attach Delete Handlers
    document.querySelectorAll('.btn-delete-order').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        if (confirm('Delete this order record?')) {
          await deleteOrder(id);
        }
      });
    });
  }

  filterChips.forEach(chip => {
    chip.addEventListener('click', () => {
      filterChips.forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      activeFilter = chip.getAttribute('data-filter');
      renderOrdersList();
    });
  });

  async function updateOrderStatus(id, status) {
    try {
      const res = await fetch(`/orders/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status })
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      showToast(`Order marked as ${status}`, 'success');
      await fetchOrders();
    } catch (err) {
      showToast(`Failed to update status: ${err.message}`, 'error');
    }
  }

  async function deleteOrder(id) {
    try {
      const res = await fetch(`/orders/${encodeURIComponent(id)}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      showToast('Order record deleted', 'info');
      await fetchOrders();
    } catch (err) {
      showToast(`Failed to delete order: ${err.message}`, 'error');
    }
  }

  btnRefreshOrders.addEventListener('click', () => {
    fetchOrders();
    showToast('Orders refreshed', 'info');
  });

  // ----------------------------------------------------
  // Track Order (Read Single Order by ID)
  // ----------------------------------------------------
  trackSearchForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const id = trackSearchInput.value.trim();
    if (id) queryOrder(id);
  });

  async function queryOrder(id) {
    trackErrorBox.classList.add('hidden');
    trackResultBox.classList.add('hidden');

    try {
      const res = await fetch(`/orders/${encodeURIComponent(id)}`);
      const data = await res.json();

      if (res.ok && data) {
        trackResultBox.classList.remove('hidden');
        trackInfoId.textContent = data.id;
        trackInfoDish.textContent = data.item_name || 'Nepali Lunch Set';
        trackInfoQty.textContent = `${data.quantity} Portions`;
        trackInfoStatus.textContent = data.status;

        const badgeClass = 
          data.status === 'DELIVERED' ? 'badge-success' :
          data.status === 'PREPARING' ? 'badge-info' :
          data.status === 'CANCELLED' ? 'badge-danger' : 'badge-warning';
        trackInfoStatus.className = `badge ${badgeClass}`;

        if (data.note) {
          trackNoteWrapper.classList.remove('hidden');
          trackInfoNote.textContent = data.note;
        } else {
          trackNoteWrapper.classList.add('hidden');
        }

        updateTrackTimeline(data.status);
        showToast(`Order status: ${data.status}`, 'info');
      } else {
        trackErrorBox.classList.remove('hidden');
        showToast('Order not found', 'error');
      }
    } catch (err) {
      trackErrorBox.classList.remove('hidden');
      showToast(`Query error: ${err.message}`, 'error');
    }
  }

  function updateTrackTimeline(status) {
    trackStep1.className = 'stepper-step active';
    trackBar1.className = 'stepper-bar';
    trackStep2.className = 'stepper-step';
    trackBar2.className = 'stepper-bar';
    trackStep3.className = 'stepper-step';

    if (status === 'PREPARING') {
      trackBar1.className = 'stepper-bar active';
      trackStep2.className = 'stepper-step active';
    } else if (status === 'DELIVERED') {
      trackBar1.className = 'stepper-bar active';
      trackStep2.className = 'stepper-step active';
      trackBar2.className = 'stepper-bar active';
      trackStep3.className = 'stepper-step active';
    }
  }

  function renderRecentChips() {
    if (!recentOrders.length) {
      recentChipsContainer.innerHTML = '<span class="text-muted text-sm">No recent orders yet</span>';
      return;
    }
    recentChipsContainer.innerHTML = '';
    recentOrders.forEach(ord => {
      const btn = document.createElement('button');
      btn.className = 'recent-chip-btn';
      btn.textContent = `${ord.name} (#${String(ord.id).substring(0, 6)})`;
      btn.onclick = () => {
        trackSearchInput.value = ord.id;
        queryOrder(ord.id);
      };
      recentChipsContainer.appendChild(btn);
    });
  }

  // ----------------------------------------------------
  // Menu Manager (Create, Update, Delete Menu Items)
  // ----------------------------------------------------
  addMenuForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = adminDishName.value.trim();
    const price_npr = parseInt(adminDishPrice.value, 10);
    const available = adminDishAvail.value === 'true';

    try {
      const res = await fetch('/menu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, price_npr, available })
      });

      if (res.ok || res.status === 201) {
        showToast(`Added ${name} to menu!`, 'success');
        adminDishName.value = '';
        fetchMenu();
      } else {
        const err = await res.json();
        showToast(`Failed to add dish: ${JSON.stringify(err)}`, 'error');
      }
    } catch (err) {
      showToast(`Error creating dish: ${err.message}`, 'error');
    }
  });

  function renderAdminMenu() {
    if (!menuCatalog.length) {
      adminMenuList.innerHTML = '<div class="text-muted text-sm py-4">No menu items found.</div>';
      return;
    }

    adminMenuList.innerHTML = '';
    menuCatalog.forEach(item => {
      const row = document.createElement('div');
      row.className = 'admin-item-row';
      const isAvail = item.available !== false;

      row.innerHTML = `
        <div class="admin-item-info">
          <span class="admin-item-name">${getDishIcon(item.name)} ${escapeHtml(item.name)}</span>
          <span class="admin-item-price">रू ${Number(item.price_npr).toLocaleString()}</span>
        </div>

        <div class="admin-item-controls">
          <button class="btn btn-sm ${isAvail ? 'btn-secondary' : 'btn-outline'} btn-toggle-avail" data-id="${item.id}" data-avail="${isAvail}">
            ${isAvail ? '🟢 In Stock' : '🔴 Sold Out'}
          </button>
          <button class="btn btn-sm btn-outline btn-edit-price" data-id="${item.id}" data-price="${item.price_npr}">
            ✏️ Price
          </button>
          <button class="btn btn-sm btn-outline btn-delete-menu" data-id="${item.id}" title="Delete Item">
            🗑️
          </button>
        </div>
      `;
      adminMenuList.appendChild(row);
    });

    // Toggle Avail
    document.querySelectorAll('.btn-toggle-avail').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        const current = btn.getAttribute('data-avail') === 'true';
        await updateMenuItem(id, { available: !current });
      });
    });

    // Edit Price
    document.querySelectorAll('.btn-edit-price').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        const oldPrice = btn.getAttribute('data-price');
        const newPriceStr = prompt('Enter new price in NPR (रू):', oldPrice);
        if (newPriceStr !== null) {
          const newPrice = parseInt(newPriceStr, 10);
          if (!isNaN(newPrice) && newPrice > 0) {
            await updateMenuItem(id, { price_npr: newPrice });
          }
        }
      });
    });

    // Delete Menu Item
    document.querySelectorAll('.btn-delete-menu').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        if (confirm('Delete this dish from the menu?')) {
          await deleteMenuItem(id);
        }
      });
    });
  }

  async function updateMenuItem(id, payload) {
    try {
      const res = await fetch(`/menu/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      showToast('Menu item updated', 'success');
      await fetchMenu();
    } catch (err) {
      showToast(`Update failed: ${err.message}`, 'error');
    }
  }

  async function deleteMenuItem(id) {
    try {
      const res = await fetch(`/menu/${encodeURIComponent(id)}`, { method: 'DELETE' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      showToast('Menu item removed', 'info');
      await fetchMenu();
    } catch (err) {
      showToast(`Delete failed: ${err.message}`, 'error');
    }
  }

  // Helper
  function escapeHtml(str) {
    return String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Initial Load
  fetchMenu();
  fetchOrders();
  renderRecentChips();
  setInterval(fetchOrders, 10000); // 10s kitchen queue polling
});
