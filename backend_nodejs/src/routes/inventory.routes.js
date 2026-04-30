const express = require('express');
const pool = require('../config/db');

const router = express.Router();

router.get('/logs', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT il.*, p.product_name, u.full_name AS employee_name
       FROM inventory_logs il
       JOIN products p ON p.product_id = il.product_id
       JOIN users u ON u.user_id = il.employee_id
       ORDER BY il.created_at DESC`
    );
    res.json({ success: true, data: rows });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy lịch sử kho', error: error.message });
  }
});

router.post('/import', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { product_id, employee_id, quantity, note } = req.body;
    if (!product_id || !employee_id || Number(quantity) <= 0) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập product_id, employee_id, quantity' });
    }

    await connection.beginTransaction();
    await connection.execute('UPDATE products SET stock = stock + ? WHERE product_id = ?', [
      Number(quantity),
      Number(product_id),
    ]);
    await connection.execute(
      `INSERT INTO inventory_logs (product_id, employee_id, action, quantity, note)
       VALUES (?, ?, 'import', ?, ?)`,
      [Number(product_id), Number(employee_id), Number(quantity), note || null]
    );
    await connection.commit();
    res.json({ success: true, message: 'Đã nhập kho' });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi nhập kho', error: error.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
