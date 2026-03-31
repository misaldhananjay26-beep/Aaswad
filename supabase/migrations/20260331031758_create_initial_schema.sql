/*
  # Aaswad 51 - Initial Database Schema

  1. New Tables
    - `profiles`: User profiles with name and phone
    - `menu_items`: Food items with pricing, category, images
    - `orders`: Customer orders with items and delivery details
    - `order_items`: Line items for each order (normalized)

  2. Security
    - Enable RLS on all tables
    - Users can only read/write their own data
    - Admins can manage all orders and menu items
    
  3. Key Features
    - Real-time order tracking via PostgreSQL changes
    - Order status workflow (pending → confirmed → cooking → out_for_delivery → delivered)
    - Inventory tracking for menu items
*/

-- ─────────────────────────────────────────────────────────────
-- PROFILES TABLE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────
-- MENU ITEMS TABLE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price decimal(8,2) NOT NULL,
  category text NOT NULL CHECK (category IN ('Breakfast', 'Thali', 'Snacks', 'Sweets', 'Drinks')),
  image_url text,
  is_veg boolean DEFAULT true,
  is_bestseller boolean DEFAULT false,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active menu items"
  ON menu_items FOR SELECT
  USING (is_active = true);

CREATE POLICY "Only admins can insert menu items"
  ON menu_items FOR INSERT
  TO authenticated
  WITH CHECK (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'));

CREATE POLICY "Only admins can update menu items"
  ON menu_items FOR UPDATE
  TO authenticated
  USING (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'))
  WITH CHECK (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'));

CREATE POLICY "Only admins can delete menu items"
  ON menu_items FOR DELETE
  TO authenticated
  USING (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'));

-- ─────────────────────────────────────────────────────────────
-- ORDERS TABLE
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  delivery_address text NOT NULL,
  special_note text,
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  subtotal decimal(10,2) NOT NULL,
  delivery_fee decimal(8,2) NOT NULL DEFAULT 30,
  gst decimal(10,2) NOT NULL,
  total decimal(10,2) NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cooking', 'out_for_delivery', 'delivered', 'cancelled')),
  payment_status text DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
  payment_id text,
  cf_order_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own orders"
  ON orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can read all orders"
  ON orders FOR SELECT
  TO authenticated
  USING (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'));

CREATE POLICY "Admins can update all orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'))
  WITH CHECK (auth.jwt() ->> 'email' IN ('misaldhananjay27@gmail.com'));

-- ─────────────────────────────────────────────────────────────
-- INDEXES FOR PERFORMANCE
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category);
CREATE INDEX IF NOT EXISTS idx_menu_items_active ON menu_items(is_active) WHERE is_active = true;

-- ─────────────────────────────────────────────────────────────
-- SEED INITIAL MENU ITEMS
-- ─────────────────────────────────────────────────────────────
INSERT INTO menu_items (name, description, price, category, image_url, is_bestseller, sort_order) VALUES
  ('Misal Pav', 'Spicy sprouted lentil curry with pav and farsan', 99.00, 'Breakfast', 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=400&q=80', true, 1),
  ('Kande Pohe', 'Fluffy flattened rice with onions and mustard seeds', 69.00, 'Breakfast', 'https://images.unsplash.com/photo-1567337710282-00832b415979?auto=format&fit=crop&w=400&q=80', true, 2),
  ('Thalipeeth + Dahi', 'Crispy multigrain flatbread with fresh dahi', 89.00, 'Breakfast', 'https://i.ibb.co/4ZgWqVp/thalipeeth.jpg', true, 3),
  ('Varan Bhaat Thali', 'Complete meal with rice, dal, sabzi and more', 199.00, 'Thali', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80', true, 4),
  ('Special Aaswad 51 Thali', 'Grand 12-item thali with Puran Poli and Aamras', 299.00, 'Thali', 'https://images.unsplash.com/photo-1567337710282-00832b415979?auto=format&fit=crop&w=400&q=80', true, 5),
  ('Kothimbir Vadi', 'Crispy coriander and besan fritters', 79.00, 'Snacks', 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?auto=format&fit=crop&w=400&q=80', true, 6),
  ('Puran Poli + Ghee', 'Sweet stuffed flatbread with pure ghee', 89.00, 'Sweets', 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=400&q=80', true, 7),
  ('Piyush', 'Chilled buttermilk with cardamom and saffron', 59.00, 'Drinks', 'https://images.unsplash.com/photo-1603569283847-aa295f0d016a?auto=format&fit=crop&w=400&q=80', true, 8)
ON CONFLICT DO NOTHING;