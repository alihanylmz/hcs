-- ============================================
-- TEAM-BASED KANBAN SYSTEM MIGRATION
-- HCS İş Takip - Takım Planlama Sistemi
-- ============================================
-- Bu migration günlük plan sistemini kaldırıp
-- yerine takım tabanlı Kanban sistemi kurar.
-- ============================================

-- 1) ENUM TİPLERİ
-- ============================================

DO $$ BEGIN
    CREATE TYPE team_role AS ENUM ('owner', 'admin', 'member');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE card_status AS ENUM ('TODO', 'DOING', 'DONE', 'SENT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE card_event_type AS ENUM (
        'CARD_CREATED',
        'STATUS_CHANGED',
        'ASSIGNEE_CHANGED',
        'UPDATED',
        'COMMENTED'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2) TABLOLAR
-- ============================================

-- TEAMS (Takımlar)
CREATE TABLE IF NOT EXISTS teams (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    emoji text NOT NULL DEFAULT '🚀',
    accent_color text NOT NULL DEFAULT '#2563EB',
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE teams
ADD COLUMN IF NOT EXISTS emoji text NOT NULL DEFAULT '🚀';

ALTER TABLE teams
ADD COLUMN IF NOT EXISTS accent_color text NOT NULL DEFAULT '#2563EB';

-- TEAM_MEMBERS (Takım Üyeleri)
CREATE TABLE IF NOT EXISTS team_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role team_role NOT NULL DEFAULT 'member',
    invited_by uuid REFERENCES auth.users(id),
    joined_at timestamptz DEFAULT now(),
    UNIQUE(team_id, user_id)
);

-- BOARDS (Panolar - her takımın birden fazla panosu olabilir)
CREATE TABLE IF NOT EXISTS boards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- CARDS (Kartlar - iş öğeleri)
CREATE TABLE IF NOT EXISTS cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id uuid REFERENCES boards(id) ON DELETE CASCADE NOT NULL,
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL, -- RLS için denormalize
    title text NOT NULL,
    description text,
    status card_status NOT NULL DEFAULT 'TODO',
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    assignee_id uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    first_doing_at timestamptz,
    done_at timestamptz,
    sent_at timestamptz
);

-- CARD_EVENTS (Kart geçmişi)
CREATE TABLE IF NOT EXISTS card_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    event_type card_event_type NOT NULL,
    from_status card_status,
    to_status card_status,
    from_assignee uuid REFERENCES auth.users(id),
    to_assignee uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now()
);

-- 3) İNDEXLER (Performans)
-- ============================================

CREATE INDEX IF NOT EXISTS idx_team_members_team_user ON team_members(team_id, user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_boards_team ON boards(team_id);
CREATE INDEX IF NOT EXISTS idx_cards_team_status ON cards(team_id, status);
CREATE INDEX IF NOT EXISTS idx_cards_board_status ON cards(board_id, status);
CREATE INDEX IF NOT EXISTS idx_cards_assignee ON cards(assignee_id);
CREATE INDEX IF NOT EXISTS idx_card_events_team_created ON card_events(team_id, created_at);
CREATE INDEX IF NOT EXISTS idx_card_events_card_created ON card_events(card_id, created_at);

-- 4) RLS AKTIFLEŞTIRME
-- ============================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;

-- 5) RLS POLİTİKALARI
-- ============================================

-- HELPER FUNCTION: Kullanıcı takım üyesi mi?
CREATE OR REPLACE FUNCTION is_team_member(p_team_id uuid, p_user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM team_members
        WHERE team_id = p_team_id AND user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- HELPER FUNCTION: Kullanıcının takımdaki rolü
CREATE OR REPLACE FUNCTION get_team_role(p_team_id uuid, p_user_id uuid)
RETURNS team_role AS $$
DECLARE
    v_role team_role;
BEGIN
    SELECT role INTO v_role
    FROM team_members
    WHERE team_id = p_team_id AND user_id = p_user_id;
    RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================
-- TEAMS POLİTİKALARI
-- ============================================

-- SELECT: Üye olduğu takımları veya kendi oluşturduğu takımları görebilir
DROP POLICY IF EXISTS teams_select_policy ON teams;
CREATE POLICY teams_select_policy ON teams
    FOR SELECT
    USING (
        created_by = auth.uid() 
        OR is_team_member(id, auth.uid())
    );

-- INSERT: Herkes takım oluşturabilir (created_by = auth.uid() kontrolü app'te)
DROP POLICY IF EXISTS teams_insert_policy ON teams;
CREATE POLICY teams_insert_policy ON teams
    FOR INSERT
    WITH CHECK (created_by = auth.uid());

-- UPDATE: Sadece takım sahibi (owner rolü) güncelleyebilir
DROP POLICY IF EXISTS teams_update_policy ON teams;
CREATE POLICY teams_update_policy ON teams
    FOR UPDATE
    USING (
        get_team_role(id, auth.uid()) = 'owner'
    );

-- DELETE: Sadece takım sahibi (owner rolü) silebilir
DROP POLICY IF EXISTS teams_delete_policy ON teams;
CREATE POLICY teams_delete_policy ON teams
    FOR DELETE
    USING (
        get_team_role(id, auth.uid()) = 'owner'
    );

-- ============================================
-- TEAM_MEMBERS POLİTİKALARI
-- ============================================

-- SELECT: Aynı takımın üyeleri birbirini görebilir
DROP POLICY IF EXISTS team_members_select_policy ON team_members;
CREATE POLICY team_members_select_policy ON team_members
    FOR SELECT
    USING (
        is_team_member(team_id, auth.uid())
    );

-- INSERT: İlk owner kendini ekleyebilir VEYA owner/admin davet edebilir
-- Bu policy takım oluşturma sırasında owner'ın kendini eklemesine izin verir
DROP POLICY IF EXISTS team_members_insert_policy ON team_members;
CREATE POLICY team_members_insert_policy ON team_members
    FOR INSERT
    WITH CHECK (
        -- Senaryo 1: Takımı oluşturan kişi kendini owner olarak ekliyor
        (user_id = auth.uid() AND role = 'owner' AND invited_by = auth.uid())
        OR
        -- Senaryo 2: Mevcut owner/admin başkasını davet ediyor
        (
            EXISTS (
                SELECT 1 FROM team_members tm
                WHERE tm.team_id = team_members.team_id
                AND tm.user_id = auth.uid()
                AND tm.role IN ('owner', 'admin')
            )
            AND invited_by = auth.uid()
        )
    );

-- UPDATE: Sadece owner rol değiştirebilir
DROP POLICY IF EXISTS team_members_update_policy ON team_members;
CREATE POLICY team_members_update_policy ON team_members
    FOR UPDATE
    USING (
        get_team_role(team_id, auth.uid()) = 'owner'
    );

-- DELETE: Owner veya admin silebilir, ancak owner'ı silemez
DROP POLICY IF EXISTS team_members_delete_policy ON team_members;
CREATE POLICY team_members_delete_policy ON team_members
    FOR DELETE
    USING (
        get_team_role(team_id, auth.uid()) IN ('owner', 'admin')
        AND role != 'owner'  -- Owner'ı asla silemez
    );

-- ============================================
-- BOARDS POLİTİKALARI
-- ============================================

-- SELECT/INSERT/UPDATE/DELETE: Takım üyeleri tüm işlemleri yapabilir
DROP POLICY IF EXISTS boards_select_policy ON boards;
CREATE POLICY boards_select_policy ON boards
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS boards_insert_policy ON boards;
CREATE POLICY boards_insert_policy ON boards
    FOR INSERT
    WITH CHECK (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS boards_update_policy ON boards;
CREATE POLICY boards_update_policy ON boards
    FOR UPDATE
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS boards_delete_policy ON boards;
CREATE POLICY boards_delete_policy ON boards
    FOR DELETE
    USING (is_team_member(team_id, auth.uid()));

-- ============================================
-- CARDS POLİTİKALARI
-- ============================================

-- SELECT/INSERT/UPDATE: Takım üyeleri tüm işlemleri yapabilir
DROP POLICY IF EXISTS cards_select_policy ON cards;
CREATE POLICY cards_select_policy ON cards
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS cards_insert_policy ON cards;
CREATE POLICY cards_insert_policy ON cards
    FOR INSERT
    WITH CHECK (
        is_team_member(team_id, auth.uid())
        AND created_by = auth.uid()
    );

DROP POLICY IF EXISTS cards_update_policy ON cards;
CREATE POLICY cards_update_policy ON cards
    FOR UPDATE
    USING (is_team_member(team_id, auth.uid()));

-- DELETE: Kart oluşturan veya owner/admin silebilir
DROP POLICY IF EXISTS cards_delete_policy ON cards;
CREATE POLICY cards_delete_policy ON cards
    FOR DELETE
    USING (
        is_team_member(team_id, auth.uid())
        AND (
            created_by = auth.uid()
            OR get_team_role(team_id, auth.uid()) IN ('owner', 'admin')
        )
    );

-- ============================================
-- CARD_EVENTS POLİTİKALARI
-- ============================================

-- SELECT: Takım üyeleri görebilir
DROP POLICY IF EXISTS card_events_select_policy ON card_events;
CREATE POLICY card_events_select_policy ON card_events
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

-- INSERT: Takım üyeleri ekleyebilir
DROP POLICY IF EXISTS card_events_insert_policy ON card_events;
CREATE POLICY card_events_insert_policy ON card_events
    FOR INSERT
    WITH CHECK (
        is_team_member(team_id, auth.uid())
        AND user_id = auth.uid()
    );

-- UPDATE/DELETE: İzin yok (event log değiştirilemez)
-- Politika tanımlamazsak default DENY olur

-- ============================================
-- TRIGGER: cards.updated_at otomatik güncelleme
-- ============================================

CREATE OR REPLACE FUNCTION update_cards_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cards_updated_at_trigger ON cards;
CREATE TRIGGER cards_updated_at_trigger
    BEFORE UPDATE ON cards
    FOR EACH ROW
    EXECUTE FUNCTION update_cards_updated_at();

-- ============================================
-- MİGRASYON TAMAMLANDI ✅
-- ============================================
-- NOT: Bu migration'ı Supabase SQL Editor'de çalıştırın!
-- Tablolar oluşturulduktan sonra Flutter uygulaması çalışacaktır.
