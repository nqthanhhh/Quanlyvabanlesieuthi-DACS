# MySQL Backend (MVP)

This folder contains a minimal Node.js + Express backend that uses MySQL for storage.

## 1) Install MySQL (Windows)
- Install **MySQL Community Server 8.x** (and optionally **MySQL Workbench**).
- Ensure the MySQL service is running on port **3306**.

## 2) Create DB schema
Open MySQL Workbench (or any SQL client) and run:
- `schema.sql`

It will create database `sieuthimini` and tables: `products`, `orders`, `order_lines`.

## 3) Configure env
Copy `.env.example` to `.env` and edit values:

PowerShell:
- `Copy-Item .env.example .env`

## 4) Install & run
- `npm install`
- `npm run dev`

## 5) Endpoints
- `GET /health`
- `GET /products`
- `PUT /products/:id` (upsert)
- `DELETE /products/:id`
- `GET /orders?status=...`
- `POST /orders` (places order + decrements stock in a transaction)
- `PATCH /orders/:id/status`

## Notes
- Flutter should call this API (do **not** connect Flutter directly to MySQL).
- Android emulator accesses host machine via `http://10.0.2.2:<PORT>`.
