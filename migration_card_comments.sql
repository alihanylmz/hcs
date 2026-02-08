-- ============================================
-- KART YORUM SİSTEMİ
-- ============================================

-- Tablo oluştur
CREATE TABLE IF NOT EXISTS card_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id uuid REFERENCES cards(id) ON DELETE CASCADE NOT NULL,
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    comment text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_card_comments_card ON card_comments(card_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_card_comments_team ON card_comments(team_id);

-- RLS Aktif
ALTER TABLE card_comments ENABLE ROW LEVEL SECURITY;

-- SELECT: Takım üyeleri görebilir
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

-- INSERT: Takım üyeleri yorum ekleyebilir
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

-- UPDATE: Sadece kendi yorumunu güncelleyebilir
DROP POLICY IF EXISTS card_comments_update_policy ON card_comments;
CREATE POLICY card_comments_update_policy ON card_comments
    FOR UPDATE
    USING (user_id = auth.uid());

-- DELETE: Sadece kendi yorumunu silebilir VEYA takım owner/admin silebilir
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

-- ============================================
-- YORUM SİSTEMİ HAZIR ✅
-- ============================================
