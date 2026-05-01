const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function toInventoryItem(row) {
  return {
    id: row.barcode,
    inventory_item_id: row.inventory_item_id,
    barcode: row.barcode,
    name: row.item_name,
    item_name: row.item_name,
    image_url: row.image_url,
    price: Number(row.price),
    unit: row.unit || 'sp',
    stockQuantity: row.stock,
    stock: row.stock,
    status: row.status,
  };
}

router.get('/items', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT *
       FROM inventory_items
       WHERE status <> 'deleted'
       ORDER BY inventory_item_id DESC`
    );
    res.json({ success: true, data: rows.map(toInventoryItem) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy hàng trong kho', error: error.message });
  }
});

router.post('/items', async (req, res) => {
  try {
    const { barcode, item_name, name, image_url, price, unit, stock, stockQuantity } = req.body;
    const itemName = item_name || name;
    if (!barcode || !itemName || price == null) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập barcode, item_name, price' });
    }

    const [result] = await pool.execute(
      `INSERT INTO inventory_items (barcode, item_name, image_url, price, unit, stock, status)
       VALUES (?, ?, ?, ?, ?, ?, 'active')`,
      [
        barcode,
        itemName,
        image_url || null,
        Number(price),
        unit || 'sp',
        Number(stock ?? stockQuantity ?? 0),
      ]
    );
    const [rows] = await pool.execute('SELECT * FROM inventory_items WHERE inventory_item_id = ?', [result.insertId]);
    res.status(201).json({ success: true, message: 'Đã thêm hàng vào kho', data: toInventoryItem(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi thêm hàng vào kho', error: error.message });
  }
});

router.put('/items/:id', async (req, res) => {
  try {
    const { barcode, item_name, name, image_url, price, unit, stock, stockQuantity, status } = req.body;
    await pool.execute(
      `UPDATE inventory_items
       SET barcode = COALESCE(?, barcode),
           item_name = COALESCE(?, item_name),
           image_url = ?,
           price = COALESCE(?, price),
           unit = COALESCE(?, unit),
           stock = COALESCE(?, stock),
           status = COALESCE(?, status)
       WHERE inventory_item_id = ?`,
      [
        barcode || null,
        item_name || name || null,
        image_url ?? null,
        price == null ? null : Number(price),
        unit || null,
        stock == null && stockQuantity == null ? null : Number(stock ?? stockQuantity),
        status || null,
        req.params.id,
      ]
    );
    const [rows] = await pool.execute('SELECT * FROM inventory_items WHERE inventory_item_id = ?', [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy hàng trong kho' });
    }
    res.json({ success: true, message: 'Đã cập nhật hàng trong kho', data: toInventoryItem(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi cập nhật hàng trong kho', error: error.message });
  }
});

router.get('/logs', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT il.*, ii.item_name, ii.barcode, ii.unit, p.product_name, u.full_name AS employee_name
       FROM inventory_logs il
       JOIN inventory_items ii ON ii.inventory_item_id = il.inventory_item_id
       LEFT JOIN products p ON p.product_id = il.product_id
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
    const { inventory_item_id, employee_id, quantity, note } = req.body;
    if (!inventory_item_id || !employee_id || Number(quantity) <= 0) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập inventory_item_id, employee_id, quantity' });
    }

    await connection.beginTransaction();
    const [items] = await connection.execute(
      'SELECT inventory_item_id FROM inventory_items WHERE inventory_item_id = ? OR barcode = ? FOR UPDATE',
      [inventory_item_id, inventory_item_id]
    );
    if (items.length === 0) throw new Error('Không tìm thấy hàng trong kho');
    const itemId = Number(items[0].inventory_item_id);
    await connection.execute('UPDATE inventory_items SET stock = stock + ? WHERE inventory_item_id = ?', [
      Number(quantity),
      itemId,
    ]);
    await connection.execute(
      `INSERT INTO inventory_logs (inventory_item_id, product_id, employee_id, action, quantity, note)
       VALUES (?, NULL, ?, 'import', ?, ?)`,
      [itemId, Number(employee_id), Number(quantity), note || null]
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

router.post('/adjust', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { inventory_item_id, employee_id, actual_quantity, note } = req.body;
    if (!inventory_item_id || !employee_id || Number(actual_quantity) < 0) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập inventory_item_id, employee_id, actual_quantity',
      });
    }

    await connection.beginTransaction();
    const [items] = await connection.execute(
      'SELECT inventory_item_id, stock FROM inventory_items WHERE inventory_item_id = ? OR barcode = ? FOR UPDATE',
      [inventory_item_id, inventory_item_id]
    );
    if (items.length === 0) {
      throw new Error('Không tìm thấy hàng trong kho');
    }

    const beforeStock = Number(items[0].stock);
    const actualQuantity = Number(actual_quantity);
    const difference = actualQuantity - beforeStock;

    await connection.execute('UPDATE inventory_items SET stock = ? WHERE inventory_item_id = ?', [
      actualQuantity,
      Number(items[0].inventory_item_id),
    ]);
    await connection.execute(
      `INSERT INTO inventory_logs (inventory_item_id, product_id, employee_id, action, quantity, note)
       VALUES (?, NULL, ?, 'adjust', ?, ?)`,
      [
        Number(items[0].inventory_item_id),
        Number(employee_id),
        difference,
        note || `Kiểm kê: ${beforeStock} -> ${actualQuantity}`,
      ]
    );
    await connection.commit();
    res.json({
      success: true,
      message: 'Đã điều chỉnh tồn kho',
      data: { beforeStock, actualQuantity, difference },
    });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi kiểm kê kho', error: error.message });
  } finally {
    connection.release();
  }
});

router.post('/export', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    const { inventory_item_id, product_id, employee_id, quantity, note } = req.body;
    if (!inventory_item_id || !employee_id || Number(quantity) <= 0) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập inventory_item_id, employee_id, quantity' });
    }

    await connection.beginTransaction();
    const [items] = await connection.execute(
      'SELECT inventory_item_id, stock FROM inventory_items WHERE inventory_item_id = ? OR barcode = ? FOR UPDATE',
      [inventory_item_id, inventory_item_id]
    );
    if (items.length === 0) throw new Error('Không tìm thấy hàng trong kho');
    if (Number(items[0].stock) < Number(quantity)) throw new Error('Không đủ tồn kho');

    await connection.execute('UPDATE inventory_items SET stock = stock - ? WHERE inventory_item_id = ?', [
      Number(quantity),
      Number(items[0].inventory_item_id),
    ]);
    await connection.execute(
      `INSERT INTO inventory_logs (inventory_item_id, product_id, employee_id, action, quantity, note)
       VALUES (?, ?, ?, 'export', ?, ?)`,
      [
        Number(items[0].inventory_item_id),
        product_id ? Number(product_id) : null,
        Number(employee_id),
        -Number(quantity),
        note || 'Đưa hàng lên kệ',
      ]
    );
    await connection.commit();
    res.json({ success: true, message: 'Đã xuất hàng khỏi kho' });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, message: 'Lỗi xuất kho', error: error.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
