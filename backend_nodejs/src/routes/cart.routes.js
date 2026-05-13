const express = require('express');
const pool = require('../config/db');

const router = express.Router();

async function getOrCreateCart(connection, userId) {
  console.log('🔍 Kiểm tra cart của user:', userId);

  const [existing] = await connection.execute(
    'SELECT cart_id FROM carts WHERE user_id = ? LIMIT 1',
    [userId]
  );

  if (existing.length > 0) {
    console.log('✅ Đã có cart:', existing[0].cart_id);
    return existing[0].cart_id;
  }

  console.log('🆕 Tạo cart mới cho user:', userId);

  const [created] = await connection.execute(
    'INSERT INTO carts (user_id) VALUES (?)',
    [userId]
  );

  console.log('✅ Cart mới ID:', created.insertId);

  return created.insertId;
}

// ======================
// GET CART
// ======================
router.get('/:userId', async (req, res) => {
  try {
    console.log('📥 GET CART USER:', req.params.userId);

    const [carts] = await pool.execute(
      'SELECT cart_id FROM carts WHERE user_id = ? LIMIT 1',
      [req.params.userId]
    );

    if (carts.length === 0) {
      console.log('⚠️ User chưa có cart');

      return res.json({
        success: true,
        data: {
          user_id: Number(req.params.userId),
          items: [],
        },
      });
    }

    const cartId = carts[0].cart_id;

    console.log('🛒 Cart ID:', cartId);

    const [items] = await pool.execute(
      `
      SELECT
        ci.cart_item_id,
        ci.product_id,
        ci.quantity,
        p.product_name,
        p.price,
        p.image_url,
        p.stock
      FROM cart_items ci
      JOIN products p ON p.product_id = ci.product_id
      WHERE ci.cart_id = ?
      ORDER BY ci.cart_item_id
      `,
      [cartId]
    );

    console.log('📦 CART ITEMS:', items);

    res.json({
      success: true,
      data: {
        user_id: Number(req.params.userId),
        cart_id: cartId,
        items,
      },
    });
  } catch (error) {
    console.error('❌ Lỗi GET CART:', error);

    res.status(500).json({
      success: false,
      message: 'Lỗi lấy giỏ hàng',
      error: error.message,
    });
  }
});

// ======================
// SAVE CART
// ======================
router.put('/:userId', async (req, res) => {
  console.log('\n========================');
  console.log('🛒 SAVE CART API CALLED');
  console.log('👤 USER:', req.params.userId);
  console.log('📦 BODY:', req.body);
  console.log('========================\n');

  const connection = await pool.getConnection();

  try {
    const { items } = req.body;

    if (!Array.isArray(items)) {
      return res.status(400).json({
        success: false,
        message: 'items phải là array',
      });
    }

    await connection.beginTransaction();

    const cartId = await getOrCreateCart(
      connection,
      req.params.userId
    );

    console.log('🗑️ Xóa cart cũ:', cartId);

    await connection.execute(
      'DELETE FROM cart_items WHERE cart_id = ?',
      [cartId]
    );

    for (const item of items) {
      console.log('➕ INSERT ITEM:', item);

      if (Number(item.quantity) > 0) {
      console.log("INSERT ITEM RUNNING");
      console.log(item);
        await connection.execute(
          `

          INSERT INTO cart_items
          (cart_id, product_id, quantity)
          VALUES (?, ?, ?)
          `,
          [
            cartId,
            Number(item.product_id),
            Number(item.quantity),
          ]
        );
      }
    }

    await connection.commit();

    console.log('✅ SAVE CART SUCCESS');

    res.json({
      success: true,
      message: 'Đã lưu giỏ hàng',
      data: {
        cart_id: cartId,
      },
    });
  } catch (error) {
    console.error('❌ SAVE CART ERROR:', error);

    await connection.rollback();

    res.status(500).json({
      success: false,
      message: 'Lỗi lưu giỏ hàng',
      error: error.message,
    });
  } finally {
    connection.release();
  }
});

module.exports = router;