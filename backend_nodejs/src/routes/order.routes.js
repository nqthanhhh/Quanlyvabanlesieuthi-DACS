const express = require('express');
const pool = require('../config/db');

const router = express.Router();

async function fetchOrder(orderId) {
  const [orders] = await pool.execute(
    `SELECT o.*, cu.full_name AS customer_name, eu.full_name AS employee_name
     FROM orders o
     LEFT JOIN users cu ON cu.user_id = o.customer_id
     LEFT JOIN users eu ON eu.user_id = o.employee_id
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
    ...orders[0],
    id: String(orders[0].order_id),
    orderDate: orders[0].created_at,
    totalAmount: Number(orders[0].final_amount),
    customerName: orders[0].customer_name || 'Khách lẻ',
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
      `SELECT o.*, cu.full_name AS customer_name, eu.full_name AS employee_name
       FROM orders o
       LEFT JOIN users cu ON cu.user_id = o.customer_id
       LEFT JOIN users eu ON eu.user_id = o.employee_id
       ORDER BY o.created_at DESC`
    );
    res.json({
      success: true,
      data: rows.map((row) => ({
        ...row,
        id: String(row.order_id),
        orderDate: row.created_at,
        totalAmount: Number(row.final_amount),
        customerName: row.customer_name || 'Khách lẻ',
      })),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy đơn hàng', error: error.message });
  }
});

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
      payment_method = 'cash',
      items,
    } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Đơn hàng cần có items' });
    }

    await connection.beginTransaction();

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

    const [orderResult] = await connection.execute(
      `INSERT INTO orders
       (customer_id, employee_id, order_type, total_amount, discount_amount, final_amount, status, payment_status, shipping_address)
       VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?)`,
      [
        customer_id || null,
        employee_id || null,
        order_type,
        total,
        total,
        status,
        payment_status,
        shipping_address || null,
      ]
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
