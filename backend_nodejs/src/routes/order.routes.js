const express = require('express');
const pool = require('../config/db');

const router = express.Router();

const paymentJoinSql = `
  LEFT JOIN (
    SELECT p1.order_id, p1.method, p1.status
    FROM payments p1
    JOIN (
      SELECT order_id, MAX(payment_id) AS payment_id
      FROM payments
      GROUP BY order_id
    ) latest ON latest.payment_id = p1.payment_id
  ) pay ON pay.order_id = o.order_id
`;

async function getActiveShiftId(connection, employeeId) {
  if (!employeeId) return null;
  const [statusColumns] = await connection.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'work_shifts'
       AND COLUMN_NAME = 'status'`
  );
  const hasShiftStatus = Number(statusColumns[0]?.count || 0) > 0;
  const activeWhere = hasShiftStatus
    ? "end_time IS NULL AND status IN ('active', 'working')"
    : 'end_time IS NULL';
  const [rows] = await connection.execute(
    `SELECT shift_id
     FROM work_shifts
     WHERE employee_id = ?
       AND ${activeWhere}
     ORDER BY shift_date DESC, start_time DESC, shift_id DESC
     LIMIT 1`,
    [employeeId]
  );
  return rows[0]?.shift_id || null;
}

async function ordersHasShiftId(connection) {
  const [rows] = await connection.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'orders'
       AND COLUMN_NAME = 'shift_id'`
  );
  return Number(rows[0]?.count || 0) > 0;
}

function normalizeOrder(row) {
  return {
    ...row,
    id: String(row.order_id),
    orderDate: row.created_at,
    totalAmount: Number(row.final_amount),
    customerName: row.customer_name || 'Khách lẻ',
    paymentStatus: row.payment_status || row.latest_payment_status,
    paymentMethod: row.payment_method || 'cash',
    shippingAddress: row.shipping_address,
  };
}

async function fetchOrder(orderId) {
  const [orders] = await pool.execute(
    `SELECT o.*, cu.full_name AS customer_name, eu.full_name AS employee_name,
            pay.method AS payment_method, pay.status AS latest_payment_status
     FROM orders o
     LEFT JOIN users cu ON cu.user_id = o.customer_id
     LEFT JOIN users eu ON eu.user_id = o.employee_id
     ${paymentJoinSql}
     WHERE o.order_id = ?`,
    [orderId]
  );
  if (orders.length === 0) return null;

  const [items] = await pool.execute(
    `SELECT oi.*, p.product_name, p.image_url
     FROM order_items oi
     JOIN products p ON p.product_id = oi.product_id
     WHERE oi.order_id = ?
     ORDER BY oi.order_item_id`,
    [orderId]
  );

  return {
    ...normalizeOrder(orders[0]),
    status: orders[0].status,
    items: items.map((item) => ({
      ...item,
      productId: String(item.product_id),
      productName: item.product_name,
      unitPrice: Number(item.price),
      subtotal: Number(item.subtotal),
    })),
  };
}

router.get('/', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT o.*, cu.full_name AS customer_name, eu.full_name AS employee_name,
              pay.method AS payment_method, pay.status AS latest_payment_status
       FROM orders o
       LEFT JOIN users cu ON cu.user_id = o.customer_id
       LEFT JOIN users eu ON eu.user_id = o.employee_id
       ${paymentJoinSql}
       ORDER BY o.created_at DESC`
    );
    res.json({ success: true, data: rows.map(normalizeOrder) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy đơn hàng', error: error.message });
  }
});

router.get('/online', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT o.*, cu.full_name AS customer_name, eu.full_name AS employee_name,
              pay.method AS payment_method, pay.status AS latest_payment_status
       FROM orders o
       LEFT JOIN users cu ON cu.user_id = o.customer_id
       LEFT JOIN users eu ON eu.user_id = o.employee_id
       ${paymentJoinSql}
       WHERE o.order_type = 'online'
         AND o.status IN ('pending', 'confirmed', 'preparing')
       ORDER BY o.created_at ASC`
    );
    res.json({ success: true, data: rows.map(normalizeOrder) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy đơn online', error: error.message });
  }
});

async function fetchHistory(req, res) {
  try {
    const customerId = Number(req.params.customerId || req.get('x-user-id'));
    const params = [];
    let customerWhere = '';
    if (customerId) {
      customerWhere = 'AND o.customer_id = ?';
      params.push(customerId);
    }

    const [rows] = await pool.execute(
      `SELECT o.order_id
       FROM orders o
       WHERE o.status IN ('completed', 'Hoàn thành', 'hoàn thành')
         ${customerWhere}
       ORDER BY o.created_at DESC`,
      params
    );
    const orders = [];
    for (const row of rows) {
      const order = await fetchOrder(row.order_id);
      if (order) orders.push(order);
    }
    res.json({ success: true, data: orders });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy lịch sử mua hàng', error: error.message });
  }
}

router.get('/history', fetchHistory);
router.get('/history/:customerId', fetchHistory);

router.get('/:id', async (req, res) => {
  try {
    const order = await fetchOrder(req.params.id);
    if (!order) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' });
    }
    res.json({ success: true, data: order });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy đơn hàng', error: error.message });
  }
});

router.patch('/:id/status', async (req, res) => {
  try {
    const status = String(req.body.status || '').trim();
    const allowed = ['pending', 'confirmed', 'preparing', 'completed', 'cancelled'];
    if (!allowed.includes(status)) {
      return res.status(400).json({ success: false, message: 'Trạng thái đơn hàng không hợp lệ' });
    }

    const [result] = await pool.execute(
      'UPDATE orders SET status = ? WHERE order_id = ?',
      [status, req.params.id]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy đơn hàng' });
    }

    const order = await fetchOrder(req.params.id);
    res.json({ success: true, message: 'Đã cập nhật trạng thái đơn hàng', data: order });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi cập nhật trạng thái đơn hàng', error: error.message });
  }
});

router.post('/', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const {
      customer_id,
      employee_id,
      order_type = 'offline',
      status = 'completed',
      payment_status = 'paid',
      shipping_address,
      note,
      payment_method = 'cash',
      items,
    } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Đơn hàng cần có items' });
    }

    await connection.beginTransaction();
    const employeeId = employee_id ? Number(employee_id) : null;
    const hasOrdersShiftId = await ordersHasShiftId(connection);
    const activeShiftId = hasOrdersShiftId
      ? await getActiveShiftId(connection, employeeId)
      : null;

    let total = 0;
    const normalizedItems = [];
    for (const item of items) {
      const productId = Number(item.product_id || item.productId);
      const quantity = Number(item.quantity);
      if (!productId || quantity <= 0) {
        throw new Error('Item không hợp lệ');
      }

      const [products] = await connection.execute(
        'SELECT product_id, product_name, price, stock FROM products WHERE product_id = ? FOR UPDATE',
        [productId]
      );
      if (products.length === 0) {
        throw new Error(`Không tìm thấy sản phẩm ${productId}`);
      }
      if (products[0].stock < quantity) {
        throw new Error(`Không đủ tồn kho cho ${products[0].product_name}`);
      }

      const price = Number(item.price ?? products[0].price);
      const subtotal = price * quantity;
      total += subtotal;
      normalizedItems.push({ productId, quantity, price, subtotal });
    }

    const insertColumns = hasOrdersShiftId
      ? 'customer_id, employee_id, shift_id, order_type, total_amount, discount_amount, final_amount, status, payment_status, shipping_address, note'
      : 'customer_id, employee_id, order_type, total_amount, discount_amount, final_amount, status, payment_status, shipping_address, note';
    const insertValues = hasOrdersShiftId
      ? '?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?'
      : '?, ?, ?, ?, 0, ?, ?, ?, ?, ?';
    const insertParams = hasOrdersShiftId
      ? [
          customer_id || null,
          employeeId,
          activeShiftId,
          order_type,
          total,
          total,
          status,
          payment_status,
          shipping_address || null,
          note || null,
        ]
      : [
          customer_id || null,
          employeeId,
          order_type,
          total,
          total,
          status,
          payment_status,
          shipping_address || null,
          note || null,
        ];

    const [orderResult] = await connection.execute(
      `INSERT INTO orders (${insertColumns}) VALUES (${insertValues})`,
      insertParams
    );

    for (const item of normalizedItems) {
      await connection.execute(
        `INSERT INTO order_items (order_id, product_id, quantity, price, subtotal)
         VALUES (?, ?, ?, ?, ?)`,
        [orderResult.insertId, item.productId, item.quantity, item.price, item.subtotal]
      );
      await connection.execute('UPDATE products SET stock = stock - ? WHERE product_id = ?', [
        item.quantity,
        item.productId,
      ]);
    }

    await connection.execute(
      'INSERT INTO payments (order_id, method, amount, status, paid_at) VALUES (?, ?, ?, ?, NOW())',
      [orderResult.insertId, payment_method, total, payment_status]
    );

    await connection.commit();
    const order = await fetchOrder(orderResult.insertId);
    res.status(201).json({ success: true, message: 'Đã tạo đơn hàng', data: order });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi tạo đơn hàng', error: error.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
