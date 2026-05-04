import { Router } from 'express';
import { pool } from '../db.js';

export const productsRouter = Router();

productsRouter.get('/', async (_req, res) => {
  const [rows] = await pool.query(
    'SELECT id, name, price, unit, stock_quantity AS stockQuantity FROM products ORDER BY name ASC'
  );
  res.json(rows);
});

// Upsert product
productsRouter.put('/:id', async (req, res) => {
  const id = String(req.params.id || '').trim();
  const { name, price, unit, stockQuantity } = req.body || {};

  if (!id) return res.status(400).json({ message: 'Missing product id' });
  if (!name || !unit) {
    return res.status(400).json({ message: 'Missing name/unit' });
  }

  const priceNum = Number(price);
  const stockNum = Number(stockQuantity ?? 0);
  if (Number.isNaN(priceNum) || priceNum < 0) {
    return res.status(400).json({ message: 'Invalid price' });
  }
  if (!Number.isInteger(stockNum) || stockNum < 0) {
    return res.status(400).json({ message: 'Invalid stockQuantity' });
  }

  await pool.query(
    `INSERT INTO products (id, name, price, unit, stock_quantity)
     VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE name=VALUES(name), price=VALUES(price), unit=VALUES(unit), stock_quantity=VALUES(stock_quantity)`,
    [id, name, priceNum, unit, stockNum]
  );

  res.json({ id, name, price: priceNum, unit, stockQuantity: stockNum });
});

productsRouter.delete('/:id', async (req, res) => {
  const id = String(req.params.id || '').trim();
  if (!id) return res.status(400).json({ message: 'Missing product id' });

  await pool.query('DELETE FROM products WHERE id = ?', [id]);
  res.status(204).send();
});
