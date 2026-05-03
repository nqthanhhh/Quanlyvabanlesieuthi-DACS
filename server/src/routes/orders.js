import { Router } from 'express';
import { pool } from '../db.js';

export const ordersRouter = Router();

ordersRouter.get('/', async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;

  const params = [];
  let sql =
    'SELECT id, order_date AS orderDate, total_amount AS totalAmount, customer_name AS customerName, status FROM orders';
  if (status) {
    sql += ' WHERE status = ?';
    params.push(status);
  }
  sql += ' ORDER BY order_date DESC';

  const [rows] = await pool.query(sql, params);
  res.json(rows);
});

ordersRouter.patch('/:id/status', async (req, res) => {
  const id = String(req.params.id || '').trim();
  const { status } = req.body || {};

  if (!id) return res.status(400).json({ message: 'Missing order id' });
  if (!status) return res.status(400).json({ message: 'Missing status' });

  await pool.query('UPDATE orders SET status = ? WHERE id = ?', [status, id]);
  res.json({ id, status });
});

// Place order with stock decrement (transaction)
ordersRouter.post('/', async (req, res) => {
  const body = req.body || {};
  const orderId = String(body.orderId || '').trim();
  const customerName = String(body.customerName || '').trim() || 'Khách lẻ';
  const totalAmount = Number(body.totalAmount);
  const items = Array.isArray(body.items) ? body.items : [];

  const paymentMethod = body.paymentMethod ? String(body.paymentMethod) : null;
  const fulfillmentMethod = body.fulfillmentMethod
    ? String(body.fulfillmentMethod)
    : null;
  const deliveryAddress = body.deliveryAddress ? String(body.deliveryAddress) : null;

  if (!orderId) return res.status(400).json({ message: 'Missing orderId' });
  if (Number.isNaN(totalAmount) || totalAmount < 0) {
    return res.status(400).json({ message: 'Invalid totalAmount' });
  }
  if (items.length === 0) {
    return res.status(400).json({ message: 'items is required' });
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Check/decrement stock with row locks.
    for (const line of items) {
      const productId = String(line.productId || '').trim();
      const productName = String(line.productName || '').trim();
      const quantity = Number(line.quantity);
      const pricePerUnit = Number(line.pricePerUnit);

      if (!productId || !productName) {
        throw Object.assign(new Error('Invalid order line'), { statusCode: 400 });
      }
      if (!Number.isInteger(quantity) || quantity <= 0) {
        throw Object.assign(new Error('Invalid quantity'), { statusCode: 400 });
      }
      if (Number.isNaN(pricePerUnit) || pricePerUnit < 0) {
        throw Object.assign(new Error('Invalid pricePerUnit'), { statusCode: 400 });
      }

      const [rows] = await conn.query(
        'SELECT stock_quantity FROM products WHERE id = ? FOR UPDATE',
        [productId]
      );
      if (!rows || rows.length === 0) {
        throw Object.assign(new Error(`Product not found: ${productId}`), {
          statusCode: 409,
        });
      }
      const currentStock = Number(rows[0].stock_quantity ?? 0);
      if (currentStock < quantity) {
        throw Object.assign(
          new Error(`Out of stock: ${productName} (còn ${currentStock})`),
          { statusCode: 409 }
        );
      }

      await conn.query(
        'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
        [quantity, productId]
      );
    }

    // Create order header
    await conn.query(
      `INSERT INTO orders (
        id, order_date, total_amount, customer_name, status, source,
        payment_method, fulfillment_method, delivery_address
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        orderId,
        new Date(),
        totalAmount,
        customerName,
        'Chờ xác nhận',
        'app',
        paymentMethod,
        fulfillmentMethod,
        deliveryAddress,
      ]
    );

    // Create order lines
    for (const line of items) {
      await conn.query(
        `INSERT INTO order_lines (
          order_id, product_id, product_name, quantity, price_per_unit
        ) VALUES (?, ?, ?, ?, ?)` ,
        [
          orderId,
          String(line.productId).trim(),
          String(line.productName).trim(),
          Number(line.quantity),
          Number(line.pricePerUnit),
        ]
      );
    }

    await conn.commit();
    res.status(201).json({ id: orderId, status: 'Chờ xác nhận' });
  } catch (e) {
    await conn.rollback();
    const statusCode = e?.statusCode || 500;
    res.status(statusCode).json({ message: e?.message || String(e) });
  } finally {
    conn.release();
  }
});
