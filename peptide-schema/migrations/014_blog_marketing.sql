-- Blog & Marketing Schema Migration
-- Blog posts CMS and marketing campaign tracking

-- ============================================================
-- BLOG POSTS
-- ============================================================

CREATE TABLE blog_posts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title             TEXT NOT NULL,
  slug              TEXT NOT NULL UNIQUE,
  content           TEXT NOT NULL DEFAULT '',       -- markdown content
  excerpt           TEXT,
  author_id         UUID REFERENCES profiles(id) ON DELETE SET NULL,
  featured_image_url TEXT,
  tags              TEXT[] DEFAULT '{}',
  is_published      BOOLEAN DEFAULT false,
  published_at      TIMESTAMPTZ,
  seo_title         TEXT,                           -- optional override for <title>
  seo_description   TEXT,
  seo_keywords      TEXT[] DEFAULT '{}',
  view_count        INTEGER DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_blog_posts_slug        ON blog_posts(slug);
CREATE INDEX idx_blog_posts_published   ON blog_posts(is_published, published_at DESC);
CREATE INDEX idx_blog_posts_author      ON blog_posts(author_id);
CREATE INDEX idx_blog_posts_tags        ON blog_posts USING GIN(tags);

-- ============================================================
-- MARKETING CAMPAIGNS
-- ============================================================

CREATE TABLE marketing_campaigns (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL,
  channel           TEXT NOT NULL,                  -- 'email' | 'sms'
  status            TEXT DEFAULT 'draft',           -- 'draft' | 'scheduled' | 'sent' | 'cancelled'
  subject           TEXT,                           -- email subject / sms preview
  content           TEXT,                           -- campaign content (html/text)
  audience_filter   JSONB DEFAULT '{}',             -- filter criteria for targeting
  scheduled_at      TIMESTAMPTZ,
  sent_at           TIMESTAMPTZ,
  total_recipients  INTEGER DEFAULT 0,
  total_delivered   INTEGER DEFAULT 0,
  total_opened      INTEGER DEFAULT 0,
  total_clicked     INTEGER DEFAULT 0,
  created_by        UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_campaigns_status   ON marketing_campaigns(status);
CREATE INDEX idx_campaigns_channel  ON marketing_campaigns(channel);

-- ============================================================
-- EMAIL SUBSCRIBERS (for blog newsletter opt-in)
-- ============================================================

CREATE TABLE email_subscribers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT NOT NULL UNIQUE,
  first_name      TEXT,
  source          TEXT DEFAULT 'blog',              -- 'blog' | 'intake' | 'checkout' | 'manual'
  is_subscribed   BOOLEAN DEFAULT true,
  subscribed_at   TIMESTAMPTZ DEFAULT now(),
  unsubscribed_at TIMESTAMPTZ,
  user_id         UUID REFERENCES profiles(id) ON DELETE SET NULL,
  tags            TEXT[] DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_subscribers_email      ON email_subscribers(email);
CREATE INDEX idx_subscribers_active     ON email_subscribers(is_subscribed);

-- ============================================================
-- AUTO-UPDATE updated_at TRIGGERS
-- ============================================================

CREATE TRIGGER blog_posts_updated_at
  BEFORE UPDATE ON blog_posts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER campaigns_updated_at
  BEFORE UPDATE ON marketing_campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketing_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_subscribers ENABLE ROW LEVEL SECURITY;

-- Blog posts: anyone can read published posts
CREATE POLICY blog_posts_select_published ON blog_posts
  FOR SELECT USING (is_published = true);

-- Blog posts: service role (admin) can manage all posts
-- (admin operations use createServiceClient which bypasses RLS)

-- Marketing campaigns: service role only (admin operations)
-- No public access needed

-- Email subscribers: users can see their own subscription
CREATE POLICY subscribers_select_own ON email_subscribers
  FOR SELECT USING ((select auth.uid()) = user_id);

CREATE POLICY subscribers_insert ON email_subscribers
  FOR INSERT WITH CHECK (true);

CREATE POLICY subscribers_update_own ON email_subscribers
  FOR UPDATE USING ((select auth.uid()) = user_id);
