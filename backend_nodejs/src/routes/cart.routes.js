const express = require('express');
const pool = require('../config/db');

const router = express.Router();

async function getOrCreateCart(connection, userId) {
  const [existing] = await connection.execute('SELECT cart_id FROM carts WHERE user_id = ? LIMIT 1', [userId]);
  if (existing.length > 0) return existing[0].cart_id;
  const [created] = await connection.execute('INSERT INTO carts (user_id) VALUES (?)', [userId]);
  return created.insertId;
}

router.get('/:userId', async (req, res) => {
  try {
    const [carts] = await pool.execute('SELECT cart_id FROM carts WHERE user_id = ? LIMIT 1', [req.params.userId]);
    if (carts.length === 0) {
      return res.json({ success: true, data: { user_id: Number(req.params.userId), items: [] } });
    }
    const [items] = await pool.execute(
      `SELECT ci.cart_item_id, ci.product_id, ci.quantity, p.product_name, p.price, p.image_url, p.stock
       FROM cart_items ci
       JOIN products p ON p.product_id = ci.product_id
       WHERE ci.cart_id = ?
       ORDER BY ci.cart_item_id`,
      [carts[0].cart_id]
    );
    res.json({ success: true, data: { user_id: Number(req.params.userId), cart_id: carts[0].cart_id, items } });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy giỏ hàng', error: error.message });
  }
});

router.put('/:userId', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ success: false, message: 'items phải là array' });
    }

    await connection.beginTransaction();
    const cartId = await getOrCreateCart(connection, req.params.userId);
    await connection.execute('DELETE FROM cart_items WHERE cart_id = ?', [cartId]);
    for (const item of items) {
      if (Number(item.quantity) > 0) {
        await connection.execute(
          'INSERT INTO cart_items (cart_id, product_id, quantity) VALUES (?, ?, ?)',
          [cartId, Number(item.product_id), Number(item.quantity)]
        );
      }
    }
    await connection.commit();
    res.json({ success: true, message: 'Đã lưu giỏ hàng', data: { cart_id: cartId } });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi lưu giỏ hàng', error: error.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
