-- ============================================
-- TÜM SORUNLARI DÜZELT - KAPSAMLI FİX
-- ============================================
-- Bu script tüm migration sorunlarını düzeltir
-- ============================================

-- 1) ENUM TİPLERİNİ DÜZELT/GÜNCELLENMİŞ
-- ============================================

-- Eski enum'u sil ve yeniden oluştur (eğer COMMENTED yoksa)
DO $$ 
BEGIN
    -- card_event_type enum'unu kontrol et ve COMMENTED ekle
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'card_event_type' AND e.enumlabel = 'COMMENTED'
    ) THEN
        ALTER TYPE card_event_type ADD VALUE 'COMMENTED';
    END IF;
EXCEPTION
    WHEN others THEN
        -- Eğer enum yoksa, oluştur
        CREATE TYPE card_event_type AS ENUM (
            'CARD_CREATED',
            'STATUS_CHANGED',
            'ASSIGNEE_CHANGED',
            'UPDATED',
            'COMMENTED'
        );
END $$;

-- 2) EKSIK TABLOLARI OLUŞTUR (IF NOT EXISTS)
-- ============================================

-- Teams
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

-- Team Members
CREATE TABLE IF NOT EXISTS team_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role team_role NOT NULL DEFAULT 'member',
    invited_by uuid REFERENCES auth.users(id),
    joined_at timestamptz DEFAULT now(),
    UNIQUE(team_id, user_id)
);

-- Boards
CREATE TABLE IF NOT EXISTS boards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Cards
CREATE TABLE IF NOT EXISTS cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    board_id uuid REFERENCES boards(id) ON DELETE CASCADE NOT NULL,
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
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

-- Card Events
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

-- Card Comments
CREATE TABLE IF NOT EXISTS card_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE NOT NULL,
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    comment text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Notifications
CREATE TABLE IF NOT EXISTS notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE,
    "type" notification_type NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- 3) TÜM İNDEXLERİ OLUŞTUR
-- ============================================

CREATE INDEX IF NOT EXISTS idx_team_members_team_user ON team_members(team_id, user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_boards_team ON boards(team_id);
CREATE INDEX IF NOT EXISTS idx_cards_team_status ON cards(team_id, status);
CREATE INDEX IF NOT EXISTS idx_cards_board_status ON cards(board_id, status);
CREATE INDEX IF NOT EXISTS idx_cards_assignee ON cards(assignee_id);
CREATE INDEX IF NOT EXISTS idx_card_events_team_created ON card_events(team_id, created_at);
CREATE INDEX IF NOT EXISTS idx_card_events_card_created ON card_events(card_id, created_at);
CREATE INDEX IF NOT EXISTS idx_card_comments_card ON card_comments(card_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_card_comments_team ON card_comments(team_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_team ON notifications(team_id, created_at DESC);

-- 4) RLS AKTİFLEŞTİR
-- ============================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 5) TÜM POLİTİKALARI YENİDEN OLUŞTUR
-- ============================================

-- TEAMS Politikaları
DROP POLICY IF EXISTS teams_select_policy ON teams;
CREATE POLICY teams_select_policy ON teams
    FOR SELECT
    USING (
        created_by = auth.uid() 
        OR is_team_member(id, auth.uid())
    );

DROP POLICY IF EXISTS teams_insert_policy ON teams;
CREATE POLICY teams_insert_policy ON teams
    FOR INSERT
    WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS teams_update_policy ON teams;
CREATE POLICY teams_update_policy ON teams
    FOR UPDATE
    USING (get_team_role(id, auth.uid()) = 'owner');

DROP POLICY IF EXISTS teams_delete_policy ON teams;
CREATE POLICY teams_delete_policy ON teams
    FOR DELETE
    USING (get_team_role(id, auth.uid()) = 'owner');

-- TEAM_MEMBERS Politikaları
DROP POLICY IF EXISTS team_members_select_policy ON team_members;
CREATE POLICY team_members_select_policy ON team_members
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS team_members_insert_policy ON team_members;
CREATE POLICY team_members_insert_policy ON team_members
    FOR INSERT
    WITH CHECK (
        (user_id = auth.uid() AND role = 'owner' AND invited_by = auth.uid())
        OR
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

DROP POLICY IF EXISTS team_members_update_policy ON team_members;
CREATE POLICY team_members_update_policy ON team_members
    FOR UPDATE
    USING (get_team_role(team_id, auth.uid()) = 'owner');

DROP POLICY IF EXISTS team_members_delete_policy ON team_members;
CREATE POLICY team_members_delete_policy ON team_members
    FOR DELETE
    USING (
        get_team_role(team_id, auth.uid()) IN ('owner', 'admin')
        AND role != 'owner'
    );

-- BOARDS Politikaları
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

-- CARDS Politikaları
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

-- CARD_EVENTS Politikaları
DROP POLICY IF EXISTS card_events_select_policy ON card_events;
CREATE POLICY card_events_select_policy ON card_events
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS card_events_insert_policy ON card_events;
CREATE POLICY card_events_insert_policy ON card_events
    FOR INSERT
    WITH CHECK (
        is_team_member(team_id, auth.uid())
        AND user_id = auth.uid()
    );

-- CARD_COMMENTS Politikaları
DROP POLICY IF EXISTS card_comments_select_policy ON card_comments;
CREATE POLICY card_comments_select_policy ON card_comments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM team_members
            WHERE team_id = card_comments.team_id
            AND user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS card_comments_insert_policy ON card_comments;
CREATE POLICY card_comments_insert_policy ON card_comments
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM team_members
            WHERE team_id = card_comments.team_id
            AND user_id = auth.uid()
        )
        AND user_id = auth.uid()
    );

DROP POLICY IF EXISTS card_comments_update_policy ON card_comments;
CREATE POLICY card_comments_update_policy ON card_comments
    FOR UPDATE
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS card_comments_delete_policy ON card_comments;
CREATE POLICY card_comments_delete_policy ON card_comments
    FOR DELETE
    USING (
        user_id = auth.uid()
        OR
        EXISTS (
            SELECT 1 FROM team_members
            WHERE team_id = card_comments.team_id
            AND user_id = auth.uid()
            AND role IN ('owner', 'admin')
        )
    );

-- NOTIFICATIONS Politikaları
DROP POLICY IF EXISTS notifications_select_policy ON notifications;
CREATE POLICY notifications_select_policy ON notifications
    FOR SELECT
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_policy ON notifications;
CREATE POLICY notifications_update_policy ON notifications
    FOR UPDATE
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_policy ON notifications;
CREATE POLICY notifications_insert_policy ON notifications
    FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS notifications_delete_policy ON notifications;
CREATE POLICY notifications_delete_policy ON notifications
    FOR DELETE
    USING (user_id = auth.uid());

-- 6) TRIGGER'LARI YENİDEN OLUŞTUR
-- ============================================

-- Cards updated_at trigger
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

-- 7) BİLDİRİM FONKSİYONLARI
-- ============================================

CREATE OR REPLACE FUNCTION add_notification(
    p_team_id uuid,
    p_user_id uuid,
    p_card_id uuid,
    p_type notification_type,
    p_title text,
    p_message text
)
RETURNS void AS $$
BEGIN
    INSERT INTO notifications (team_id, user_id, card_id, "type", title, message)
    VALUES (p_team_id, p_user_id, p_card_id, p_type, p_title, p_message);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Kart Atama Trigger
CREATE OR REPLACE FUNCTION notify_card_assigned()
RETURNS TRIGGER AS $$
DECLARE
    v_assigner_name text;
BEGIN
    IF NEW.assignee_id IS NOT NULL AND (OLD.assignee_id IS NULL OR OLD.assignee_id != NEW.assignee_id) THEN
        SELECT full_name INTO v_assigner_name FROM profiles WHERE id = auth.uid();
        
        PERFORM add_notification(
            NEW.team_id,
            NEW.assignee_id,
            NEW.id,
            'CARD_ASSIGNED'::notification_type,
            'Size yeni bir kart atandı',
            (COALESCE(v_assigner_name, 'Birisi') || ' size "' || NEW.title || '" kartını atadı')
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS card_assigned_notification ON cards;
CREATE TRIGGER card_assigned_notification
    AFTER INSERT OR UPDATE OF assignee_id ON cards
    FOR EACH ROW
    EXECUTE FUNCTION notify_card_assigned();

-- Yorum Trigger
CREATE OR REPLACE FUNCTION notify_card_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_card record;
    v_commenter_name text;
BEGIN
    SELECT * INTO v_card FROM cards WHERE id = NEW.card_id;
    SELECT full_name INTO v_commenter_name FROM profiles WHERE id = NEW.user_id;
    
    IF v_card.created_by != NEW.user_id THEN
        PERFORM add_notification(
            v_card.team_id,
            v_card.created_by,
            NEW.card_id,
            'CARD_COMMENT'::notification_type,
            'Kartınıza yorum yapıldı',
            (COALESCE(v_commenter_name, 'Birisi') || ' "' || v_card.title || '" kartına yorum yaptı')
        );
    END IF;
    
    IF v_card.assignee_id IS NOT NULL 
       AND v_card.assignee_id != NEW.user_id 
       AND v_card.assignee_id != v_card.created_by THEN
        PERFORM add_notification(
            v_card.team_id,
            v_card.assignee_id,
            NEW.card_id,
            'CARD_COMMENT'::notification_type,
            'Kartınıza yorum yapıldı',
            (COALESCE(v_commenter_name, 'Birisi') || ' "' || v_card.title || '" kartına yorum yaptı')
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS card_comment_notification ON card_comments;
CREATE TRIGGER card_comment_notification
    AFTER INSERT ON card_comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_card_comment();

-- ============================================
-- TAMAMLANDI ✅
-- ============================================
-- Bu scripti Supabase SQL Editor'de çalıştırın.
-- Tüm sorunları düzeltecek ve sistemin çalışmasını sağlayacaktır.
