import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { pingDb } from './db.js';
import { productsRouter } from './routes/products.js';
import { ordersRouter } from './routes/orders.js';

const app = express();

app.use(
  cors({
    origin: process.env.CORS_ORIGIN || '*',
  })
);
app.use(express.json({ limit: '1mb' }));

app.get('/health', async (_req, res) => {
  try {
    await pingDb();
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ ok: false, message: String(e) });
  }
});

app.use('/products', productsRouter);
app.use('/orders', ordersRouter);

const port = Number(process.env.PORT || 8080);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`[server] listening on http://localhost:${port}`);
});
