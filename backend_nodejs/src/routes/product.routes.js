const express = require('express');
const pool = require('../config/db');

const router = express.Router();

function toProduct(row) {
  return {
    id: String(row.product_id),
    product_id: row.product_id,
    name: row.product_name,
    product_name: row.product_name,
    barcode: row.barcode,
    description: row.description,
    image_url: row.image_url,
    price: Number(row.price),
    unit: row.unit || 'sp',
    stockQuantity: row.stock,
    stock: row.stock,
    min_stock: row.min_stock,
    category_id: row.category_id,
    category_name: row.category_name,
    status: row.status,
  };
}

router.get('/', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT p.*, c.category_name
       FROM products p
       JOIN categories c ON c.category_id = p.category_id
       WHERE p.status <> 'deleted'
       ORDER BY p.product_id DESC`
    );
    res.json({ success: true, data: rows.map(toProduct) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy sản phẩm', error: error.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT p.*, c.category_name
       FROM products p
       JOIN categories c ON c.category_id = p.category_id
       WHERE p.product_id = ? AND p.status <> 'deleted'`,
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy sản phẩm' });
    }
    res.json({ success: true, data: toProduct(rows[0]) });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi lấy sản phẩm', error: error.message });
  }
});

router.post('/', async (req, res) => {
  try {
    const {
      product_name,
      name,
      barcode,
      description,
      image_url,
      price,
      unit,
      stock,
      stockQuantity,
      min_stock,
      category_id,
    } = req.body;

    const productName = product_name || name;
    const productBarcode = barcode || `P${Date.now()}`;
    const productStock = Number(stock ?? stockQuantity ?? 0);

    if (!productName || price == null || !category_id) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập product_name, price, category_id',
      });
    }

    const [result] = await pool.execute(
      `INSERT INTO products
       (product_name, barcode, description, image_url, price, unit, stock, min_stock, category_id, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')`,
      [
        productName,
        productBarcode,
        description || null,
        image_url || null,
        Number(price),
        unit || 'sp',
        productStock,
        Number(min_stock ?? 10),
        Number(category_id),
      ]
    );

    const [rows] = await pool.execute(
      `SELECT p.*, c.category_name
       FROM products p
       JOIN categories c ON c.category_id = p.category_id
       WHERE p.product_id = ?`,
      [result.insertId]
    );
    res.status(201).json({ success: true, message: 'Đã thêm sản phẩm', data: toProduct(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi thêm sản phẩm', error: error.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const {
      product_name,
      name,
      barcode,
      description,
      image_url,
      price,
      unit,
      stock,
      stockQuantity,
      min_stock,
      category_id,
      status,
    } = req.body;

    await pool.execute(
      `UPDATE products
       SET product_name = COALESCE(?, product_name),
           barcode = COALESCE(?, barcode),
           description = ?,
           image_url = ?,
           price = COALESCE(?, price),
           unit = COALESCE(?, unit),
           stock = COALESCE(?, stock),
           min_stock = COALESCE(?, min_stock),
           category_id = COALESCE(?, category_id),
           status = COALESCE(?, status)
       WHERE product_id = ?`,
      [
        product_name || name || null,
        barcode || null,
        description ?? null,
        image_url ?? null,
        price == null ? null : Number(price),
        unit || null,
        stock == null && stockQuantity == null ? null : Number(stock ?? stockQuantity),
        min_stock == null ? null : Number(min_stock),
        category_id == null ? null : Number(category_id),
        status || null,
        req.params.id,
      ]
    );

    const [rows] = await pool.execute(
      `SELECT p.*, c.category_name
       FROM products p
       JOIN categories c ON c.category_id = p.category_id
       WHERE p.product_id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy sản phẩm' });
    }
    res.json({ success: true, message: 'Đã cập nhật sản phẩm', data: toProduct(rows[0]) });
  } catch (error) {
    const status = error.code === 'ER_DUP_ENTRY' ? 409 : 500;
    res.status(status).json({ success: false, message: 'Lỗi cập nhật sản phẩm', error: error.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await pool.execute("UPDATE products SET status = 'deleted' WHERE product_id = ?", [req.params.id]);
    res.json({ success: true, message: 'Đã xóa sản phẩm' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi xóa sản phẩm', error: error.message });
  }
});

module.exports = router;
