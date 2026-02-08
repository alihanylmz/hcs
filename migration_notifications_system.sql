-- ============================================
-- BİLDİRİM SİSTEMİ - TAM KURULUM
-- ============================================

-- 1) BİLDİRİM ENUM
-- ============================================

DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        'CARD_ASSIGNED',      -- Kart size atandı
        'CARD_COMMENT',       -- Kartınıza yorum yapıldı
        'CARD_STATUS_CHANGED',-- Kartınızın durumu değişti
        'CARD_OVERDUE',       -- Açık iş uzun süredir bekliyor
        'DAILY_SUMMARY'       -- Günlük özet
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2) BİLDİRİMLER TABLOSU
-- ============================================

CREATE TABLE IF NOT EXISTS notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_team ON notifications(team_id, created_at DESC);

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- SELECT: Kullanıcı kendi bildirimlerini görebilir
DROP POLICY IF EXISTS notifications_select_policy ON notifications;
CREATE POLICY notifications_select_policy ON notifications
    FOR SELECT
    USING (user_id = auth.uid());

-- UPDATE: Kullanıcı kendi bildirimlerini güncelleyebilir (read durumu)
DROP POLICY IF EXISTS notifications_update_policy ON notifications;
CREATE POLICY notifications_update_policy ON notifications
    FOR UPDATE
    USING (user_id = auth.uid());

-- INSERT: Sistem tarafından eklenecek (SECURITY DEFINER fonksiyonlar)
DROP POLICY IF EXISTS notifications_insert_policy ON notifications;
CREATE POLICY notifications_insert_policy ON notifications
    FOR INSERT
    WITH CHECK (true); -- Fonksiyonlar SECURITY DEFINER olduğu için güvenli

-- DELETE: Kullanıcı kendi bildirimlerini silebilir
DROP POLICY IF EXISTS notifications_delete_policy ON notifications;
CREATE POLICY notifications_delete_policy ON notifications
    FOR DELETE
    USING (user_id = auth.uid());

-- 3) ONESIGNAL PLAYER ID TABLOSU
-- ============================================

CREATE TABLE IF NOT EXISTS user_push_tokens (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    onesignal_player_id text,
    device_type text, -- 'ios', 'android', 'web'
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE user_push_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_push_tokens_policy ON user_push_tokens;
CREATE POLICY user_push_tokens_policy ON user_push_tokens
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 4) BİLDİRİM GÖNDERME FONKSİYONLARI
-- ============================================

-- Helper: Kullanıcıya bildirim ekle
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

-- 5) OTOMATIK BİLDİRİM TETİKLEYİCİLERİ
-- ============================================

-- Kart atandığında bildirim gönder
CREATE OR REPLACE FUNCTION notify_card_assigned()
RETURNS TRIGGER AS $$
DECLARE
    v_card_title text;
    v_assigner_name text;
BEGIN
    -- Sadece yeni atama varsa
    IF NEW.assignee_id IS NOT NULL AND (OLD.assignee_id IS NULL OR OLD.assignee_id != NEW.assignee_id) THEN
        -- Kart başlığını al
        SELECT title INTO v_card_title FROM cards WHERE id = NEW.id;
        
        -- Atayan kişinin adını al
        SELECT full_name INTO v_assigner_name FROM profiles WHERE id = auth.uid();
        
        -- Bildirim ekle
        PERFORM add_notification(
            NEW.team_id,
            NEW.assignee_id,
            NEW.id,
            'CARD_ASSIGNED',
            'Size yeni bir kart atandı',
            (v_assigner_name || ' size "' || v_card_title || '" kartını atadı')
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

-- Yorum yapıldığında bildirim gönder
CREATE OR REPLACE FUNCTION notify_card_comment()
RETURNS TRIGGER AS $$
DECLARE
    v_card record;
    v_commenter_name text;
    v_assignee_id uuid;
    v_creator_id uuid;
BEGIN
    -- Kart bilgilerini al
    SELECT * INTO v_card FROM cards WHERE id = NEW.card_id;
    
    -- Yorum yapan kişinin adını al
    SELECT full_name INTO v_commenter_name FROM profiles WHERE id = NEW.user_id;
    
    -- Kart sahibine bildirim (kendi yorumu değilse)
    IF v_card.created_by != NEW.user_id THEN
        PERFORM add_notification(
            NEW.team_id,
            v_card.created_by,
            NEW.card_id,
            'CARD_COMMENT',
            'Kartınıza yorum yapıldı',
            (v_commenter_name || ' "' || v_card.title || '" kartına yorum yaptı')
        );
    END IF;
    
    -- Atanan kişiye bildirim (kendisi değilse ve kart sahibi değilse)
    IF v_card.assignee_id IS NOT NULL 
       AND v_card.assignee_id != NEW.user_id 
       AND v_card.assignee_id != v_card.created_by THEN
        PERFORM add_notification(
            NEW.team_id,
            v_card.assignee_id,
            NEW.card_id,
            'CARD_COMMENT',
            'Kartınıza yorum yapıldı',
            (v_commenter_name || ' "' || v_card.title || '" kartına yorum yaptı')
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

-- Durum değiştiğinde bildirim gönder
CREATE OR REPLACE FUNCTION notify_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_changer_name text;
BEGIN
    -- Sadece durum değişirse
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.assignee_id IS NOT NULL THEN
        -- Değiştiren kişinin adını al
        SELECT full_name INTO v_changer_name FROM profiles WHERE id = auth.uid();
        
        -- Atanan kişiye bildirim (kendisi değiştirmediyse)
        IF NEW.assignee_id != auth.uid() THEN
            PERFORM add_notification(
                NEW.team_id,
                NEW.assignee_id,
                NEW.id,
                'CARD_STATUS_CHANGED',
                'Kartınızın durumu değişti',
                (v_changer_name || ' "' || NEW.title || '" kartını ' || NEW.status || ' yaptı')
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS card_status_change_notification ON cards;
CREATE TRIGGER card_status_change_notification
    AFTER UPDATE OF status ON cards
    FOR EACH ROW
    EXECUTE FUNCTION notify_status_change();

-- 6) AÇIK İŞ UYARISI FONKSİYONU (Manuel çağrılacak veya cron ile)
-- ============================================

CREATE OR REPLACE FUNCTION send_overdue_notifications()
RETURNS void AS $$
DECLARE
    v_card record;
    v_hours_in_doing integer;
BEGIN
    -- 24 saatten fazla DOING'de bekleyen kartlar
    FOR v_card IN 
        SELECT c.*, p.full_name as assignee_name
        FROM cards c
        LEFT JOIN profiles p ON p.id = c.assignee_id
        WHERE c.status = 'DOING'
        AND c.first_doing_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (now() - c.first_doing_at)) / 3600.0 > 24
        AND c.assignee_id IS NOT NULL
    LOOP
        v_hours_in_doing := FLOOR(EXTRACT(EPOCH FROM (now() - v_card.first_doing_at)) / 3600.0);
        
        -- Bildirim ekle
        PERFORM add_notification(
            v_card.team_id,
            v_card.assignee_id,
            v_card.id,
            'CARD_OVERDUE',
            'Açık iş bekliyor',
            ('"' || v_card.title || '" kartı ' || v_hours_in_doing || ' saattir devam ediyor')
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7) GÜNLÜK ÖZET FONKSİYONU
-- ============================================

CREATE OR REPLACE FUNCTION send_daily_summary()
RETURNS void AS $$
DECLARE
    v_team record;
    v_member record;
    v_todo_count integer;
    v_doing_count integer;
    v_message text;
BEGIN
    -- Her takım için
    FOR v_team IN SELECT * FROM teams LOOP
        -- Takımdaki her üye için
        FOR v_member IN 
            SELECT DISTINCT user_id 
            FROM team_members 
            WHERE team_id = v_team.id 
        LOOP
            -- Kartları say
            SELECT COUNT(*) INTO v_todo_count
            FROM cards
            WHERE team_id = v_team.id
            AND status = 'TODO'
            AND (assignee_id = v_member.user_id OR assignee_id IS NULL);
            
            SELECT COUNT(*) INTO v_doing_count
            FROM cards
            WHERE team_id = v_team.id
            AND status = 'DOING'
            AND assignee_id = v_member.user_id;
            
            -- Bildirim mesajı oluştur
            v_message := v_team.name || ' takımı: ' || 
                        v_todo_count || ' yapılacak, ' || 
                        v_doing_count || ' devam eden iş';
            
            -- Bildirim ekle
            PERFORM add_notification(
                v_team.id,
                v_member.user_id,
                null,
                'DAILY_SUMMARY',
                'Günlük Özet',
                v_message
            );
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- BİLDİRİM SİSTEMİ HAZIR ✅
-- ============================================

-- KULLANIM:
-- 1. Otomatik bildirimler: Trigger'lar otomatik çalışır
-- 2. Açık iş uyarısı: SELECT send_overdue_notifications(); (manuel veya cron)
-- 3. Günlük özet: SELECT send_daily_summary(); (manuel veya cron)

-- CRON KURULUMU (opsiyonel):
-- Supabase Dashboard → Database → Extensions → pg_cron enable
-- Sonra:
-- SELECT cron.schedule('overdue-check', '0 */6 * * *', 'SELECT send_overdue_notifications()');
-- SELECT cron.schedule('daily-summary', '0 9 * * *', 'SELECT send_daily_summary()');
