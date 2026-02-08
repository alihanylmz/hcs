# 🔔 BİLDİRİM SİSTEMİ - ADIM ADIM KURULUM

Migration'ı **tek seferde değil**, **adım adım** çalıştırın:

---

## ADIM 1: ENUM Oluştur

```sql
DO $$ BEGIN
    CREATE TYPE notification_type AS ENUM (
        'CARD_ASSIGNED',
        'CARD_COMMENT',
        'CARD_STATUS_CHANGED',
        'CARD_OVERDUE',
        'DAILY_SUMMARY'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
```

**RUN** → Başarılı olmalı ✅

---

## ADIM 2: Notifications Tablosu

```sql
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

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_team ON notifications(team_id, created_at DESC);
```

**RUN** → Başarılı olmalı ✅

---

## ADIM 3: RLS Policies

```sql
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

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
```

**RUN** → Başarılı olmalı ✅

---

## ADIM 4: Helper Function

```sql
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
```

**RUN** → Başarılı olmalı ✅

---

## ADIM 5: Kart Atama Trigger

```sql
CREATE OR REPLACE FUNCTION notify_card_assigned()
RETURNS TRIGGER AS $$
DECLARE
    v_card_title text;
    v_assigner_name text;
BEGIN
    IF NEW.assignee_id IS NOT NULL AND (OLD.assignee_id IS NULL OR OLD.assignee_id != NEW.assignee_id) THEN
        v_card_title := NEW.title;
        
        SELECT full_name INTO v_assigner_name FROM profiles WHERE id = auth.uid();
        
        PERFORM add_notification(
            NEW.team_id,
            NEW.assignee_id,
            NEW.id,
            'CARD_ASSIGNED'::notification_type,
            'Size yeni bir kart atandı',
            (COALESCE(v_assigner_name, 'Birisi') || ' size "' || v_card_title || '" kartını atadı')
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
```

**RUN** → Başarılı olmalı ✅

---

## ADIM 6: Yorum Trigger

```sql
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
            NEW.team_id,
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
            NEW.team_id,
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
```

**RUN** → Başarılı olmalı ✅

---

## ✅ TAMAMLANDI

Artık:
1. ✅ Kart atandığında → Bildirim
2. ✅ Yorum yapıldığında → Bildirim
3. ✅ Flutter'da **R** yapın
4. ✅ Drawer → **Bildirimler** sayfası

Test edin! 🚀
