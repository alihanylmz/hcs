-- ============================================
-- TEAM KANBAN + YORUMLAR + BİLDİRİMLER
-- FİNAL VERSİYON - TEMİZ KURULUM
-- ============================================
-- Bu dosyayı Supabase SQL Editor'de çalıştırın
-- ============================================

-- STEP 1: ENUMLARı OLUŞTUR
-- ============================================

DROP TYPE IF EXISTS team_role CASCADE;
CREATE TYPE team_role AS ENUM ('owner', 'admin', 'member');

DROP TYPE IF EXISTS card_status CASCADE;
CREATE TYPE card_status AS ENUM ('TODO', 'DOING', 'DONE', 'SENT');

DROP TYPE IF EXISTS card_event_type CASCADE;
CREATE TYPE card_event_type AS ENUM (
    'CARD_CREATED',
    'STATUS_CHANGED',
    'ASSIGNEE_CHANGED',
    'UPDATED'
);

DROP TYPE IF EXISTS notification_type CASCADE;
CREATE TYPE notification_type AS ENUM (
    'CARD_ASSIGNED',
    'CARD_COMMENT',
    'CARD_STATUS_CHANGED',
    'CARD_OVERDUE',
    'DAILY_SUMMARY'
);

-- STEP 2: TABLOLARI OLUŞTUR
-- ============================================

-- TEAMS
DROP TABLE IF EXISTS teams CASCADE;
CREATE TABLE teams (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    emoji text NOT NULL DEFAULT '🚀',
    accent_color text NOT NULL DEFAULT '#2563EB',
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- TEAM_MEMBERS
DROP TABLE IF EXISTS team_members CASCADE;
CREATE TABLE team_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role team_role NOT NULL DEFAULT 'member',
    invited_by uuid REFERENCES auth.users(id),
    joined_at timestamptz DEFAULT now(),
    UNIQUE(team_id, user_id)
);

-- BOARDS
DROP TABLE IF EXISTS boards CASCADE;
CREATE TABLE boards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- CARDS
DROP TABLE IF EXISTS cards CASCADE;
CREATE TABLE cards (
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

-- CARD_EVENTS
DROP TABLE IF EXISTS card_events CASCADE;
CREATE TABLE card_events (
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

-- CARD_COMMENTS
DROP TABLE IF EXISTS card_comments CASCADE;
CREATE TABLE card_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE NOT NULL,
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    comment text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- NOTIFICATIONS
DROP TABLE IF EXISTS notifications CASCADE;
CREATE TABLE notifications (
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

-- STEP 3: İNDEXLER
-- ============================================

CREATE INDEX idx_team_members_team_user ON team_members(team_id, user_id);
CREATE INDEX idx_cards_team_status ON cards(team_id, status);
CREATE INDEX idx_cards_board_status ON cards(board_id, status);
CREATE INDEX idx_card_events_card ON card_events(card_id, created_at);
CREATE INDEX idx_card_comments_card ON card_comments(card_id, created_at DESC);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

-- STEP 4: RLS AKTİF
-- ============================================

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- STEP 5: HELPER FONKSİYONLAR
-- ============================================

CREATE OR REPLACE FUNCTION is_team_member(p_team_id uuid, p_user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM team_members
        WHERE team_id = p_team_id AND user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

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

-- STEP 6: RLS POLİCİES
-- ============================================

-- TEAMS
CREATE POLICY teams_select ON teams FOR SELECT USING (
    created_by = auth.uid() OR is_team_member(id, auth.uid())
);
CREATE POLICY teams_insert ON teams FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY teams_update ON teams FOR UPDATE USING (get_team_role(id, auth.uid()) = 'owner');
CREATE POLICY teams_delete ON teams FOR DELETE USING (get_team_role(id, auth.uid()) = 'owner');

-- TEAM_MEMBERS
CREATE POLICY team_members_select ON team_members FOR SELECT USING (is_team_member(team_id, auth.uid()));
CREATE POLICY team_members_insert ON team_members FOR INSERT WITH CHECK (
    (user_id = auth.uid() AND role = 'owner' AND invited_by = auth.uid())
    OR (
        EXISTS (
            SELECT 1 FROM team_members tm
            WHERE tm.team_id = team_members.team_id
            AND tm.user_id = auth.uid()
            AND tm.role IN ('owner', 'admin')
        )
        AND invited_by = auth.uid()
    )
);
CREATE POLICY team_members_update ON team_members FOR UPDATE USING (get_team_role(team_id, auth.uid()) = 'owner');
CREATE POLICY team_members_delete ON team_members FOR DELETE USING (
    get_team_role(team_id, auth.uid()) IN ('owner', 'admin') AND role != 'owner'
);

-- BOARDS
CREATE POLICY boards_all ON boards FOR ALL USING (is_team_member(team_id, auth.uid()));

-- CARDS
CREATE POLICY cards_select ON cards FOR SELECT USING (is_team_member(team_id, auth.uid()));
CREATE POLICY cards_insert ON cards FOR INSERT WITH CHECK (is_team_member(team_id, auth.uid()) AND created_by = auth.uid());
CREATE POLICY cards_update ON cards FOR UPDATE USING (is_team_member(team_id, auth.uid()));
CREATE POLICY cards_delete ON cards FOR DELETE USING (is_team_member(team_id, auth.uid()));

-- CARD_EVENTS
CREATE POLICY card_events_select ON card_events FOR SELECT USING (is_team_member(team_id, auth.uid()));
CREATE POLICY card_events_insert ON card_events FOR INSERT WITH CHECK (is_team_member(team_id, auth.uid()) AND user_id = auth.uid());

-- CARD_COMMENTS
CREATE POLICY card_comments_select ON card_comments FOR SELECT USING (is_team_member(team_id, auth.uid()));
CREATE POLICY card_comments_insert ON card_comments FOR INSERT WITH CHECK (is_team_member(team_id, auth.uid()) AND user_id = auth.uid());
CREATE POLICY card_comments_update ON card_comments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY card_comments_delete ON card_comments FOR DELETE USING (user_id = auth.uid());

-- NOTIFICATIONS
CREATE POLICY notifications_select ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY notifications_update ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY notifications_insert ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY notifications_delete ON notifications FOR DELETE USING (user_id = auth.uid());

-- PROFILES (eğer yoksa)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles FOR SELECT USING (true);

-- STEP 7: TRIGGER FONKSİYONLAR
-- ============================================

-- cards.updated_at trigger
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

-- Bildirim helper
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
EXCEPTION WHEN OTHERS THEN
    -- Hata olursa sessizce geç (bildirim sistemi ana işi bozmasın)
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Kart atama bildirimi
CREATE OR REPLACE FUNCTION notify_card_assigned()
RETURNS TRIGGER AS $$
DECLARE
    v_assigner_name text;
BEGIN
    IF NEW.assignee_id IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.assignee_id IS DISTINCT FROM NEW.assignee_id) THEN
        SELECT full_name INTO v_assigner_name FROM profiles WHERE id = NEW.created_by;
        
        PERFORM add_notification(
            NEW.team_id,
            NEW.assignee_id,
            NEW.id,
            'CARD_ASSIGNED',
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

-- Yorum bildirimi
CREATE OR REPLACE FUNCTION notify_card_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_card record;
    v_commenter_name text;
BEGIN
    SELECT * INTO v_card FROM cards WHERE id = NEW.card_id;
    SELECT full_name INTO v_commenter_name FROM profiles WHERE id = NEW.user_id;
    
    -- Kart sahibine
    IF v_card.created_by != NEW.user_id THEN
        PERFORM add_notification(
            v_card.team_id,
            v_card.created_by,
            NEW.card_id,
            'CARD_COMMENT',
            'Kartınıza yorum yapıldı',
            (COALESCE(v_commenter_name, 'Birisi') || ' "' || v_card.title || '" kartına yorum yaptı')
        );
    END IF;
    
    -- Atanan kişiye
    IF v_card.assignee_id IS NOT NULL 
       AND v_card.assignee_id != NEW.user_id 
       AND v_card.assignee_id != v_card.created_by THEN
        PERFORM add_notification(
            v_card.team_id,
            v_card.assignee_id,
            NEW.card_id,
            'CARD_COMMENT',
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

-- STEP 8: ANALİTİK FONKSİYONLAR
-- ============================================

CREATE OR REPLACE FUNCTION calculate_avg_lead_time(
    p_team_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS double precision AS $$
DECLARE
    v_avg_hours double precision;
BEGIN
    SELECT AVG(EXTRACT(EPOCH FROM (done_at - created_at)) / 3600.0)
    INTO v_avg_hours
    FROM cards
    WHERE team_id = p_team_id
      AND done_at IS NOT NULL
      AND done_at >= p_start_date
      AND done_at <= p_end_date;
    RETURN v_avg_hours;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION calculate_avg_cycle_time(
    p_team_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS double precision AS $$
DECLARE
    v_avg_hours double precision;
BEGIN
    SELECT AVG(EXTRACT(EPOCH FROM (done_at - first_doing_at)) / 3600.0)
    INTO v_avg_hours
    FROM cards
    WHERE team_id = p_team_id
      AND done_at IS NOT NULL
      AND first_doing_at IS NOT NULL
      AND done_at >= p_start_date
      AND done_at <= p_end_date;
    RETURN v_avg_hours;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION calculate_todo_dwell(
    p_team_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS double precision AS $$
DECLARE
    v_avg_hours double precision;
BEGIN
    SELECT AVG(EXTRACT(EPOCH FROM (first_doing_at - created_at)) / 3600.0)
    INTO v_avg_hours
    FROM cards
    WHERE team_id = p_team_id
      AND first_doing_at IS NOT NULL
      AND first_doing_at >= p_start_date
      AND first_doing_at <= p_end_date;
    RETURN v_avg_hours;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION calculate_doing_dwell(
    p_team_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS double precision AS $$
DECLARE
    v_avg_hours double precision;
BEGIN
    SELECT AVG(EXTRACT(EPOCH FROM (done_at - first_doing_at)) / 3600.0)
    INTO v_avg_hours
    FROM cards
    WHERE team_id = p_team_id
      AND done_at IS NOT NULL
      AND first_doing_at IS NOT NULL
      AND done_at >= p_start_date
      AND done_at <= p_end_date;
    RETURN v_avg_hours;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION get_user_completions(
    p_team_id uuid,
    p_start_date timestamptz,
    p_end_date timestamptz
)
RETURNS TABLE (
    user_id uuid,
    user_name text,
    completed_count bigint,
    avg_lead_time double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.assignee_id as user_id,
        p.full_name as user_name,
        COUNT(c.id) as completed_count,
        AVG(EXTRACT(EPOCH FROM (c.done_at - c.created_at)) / 3600.0) as avg_lead_time
    FROM cards c
    INNER JOIN profiles p ON p.id = c.assignee_id
    WHERE c.team_id = p_team_id
      AND c.done_at IS NOT NULL
      AND c.done_at >= p_start_date
      AND c.done_at <= p_end_date
      AND c.assignee_id IS NOT NULL
    GROUP BY c.assignee_id, p.full_name
    ORDER BY completed_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================
-- MİGRASYON TAMAMLANDI ✅
-- ============================================
-- Artık flutter clean && flutter pub get && flutter run yapabilirsiniz!
