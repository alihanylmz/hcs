-- ============================================
-- TEAM KNOWLEDGE CENTER MIGRATION
-- Run this after migration_team_kanban.sql
-- ============================================

CREATE TABLE IF NOT EXISTS team_pages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id uuid REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    summary text DEFAULT '' NOT NULL,
    icon text DEFAULT 'DOC' NOT NULL,
    created_by uuid REFERENCES auth.users(id) NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS team_page_blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id uuid REFERENCES team_pages(id) ON DELETE CASCADE NOT NULL,
    block_type text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    content jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_team_pages_team_updated
    ON team_pages(team_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_team_page_blocks_page_order
    ON team_page_blocks(page_id, sort_order);

ALTER TABLE team_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_page_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS team_pages_select_policy ON team_pages;
CREATE POLICY team_pages_select_policy ON team_pages
    FOR SELECT
    USING (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS team_pages_insert_policy ON team_pages;
CREATE POLICY team_pages_insert_policy ON team_pages
    FOR INSERT
    WITH CHECK (
        is_team_member(team_id, auth.uid())
        AND created_by = auth.uid()
    );

DROP POLICY IF EXISTS team_pages_update_policy ON team_pages;
CREATE POLICY team_pages_update_policy ON team_pages
    FOR UPDATE
    USING (is_team_member(team_id, auth.uid()))
    WITH CHECK (is_team_member(team_id, auth.uid()));

DROP POLICY IF EXISTS team_pages_delete_policy ON team_pages;
CREATE POLICY team_pages_delete_policy ON team_pages
    FOR DELETE
    USING (
        created_by = auth.uid()
        OR get_team_role(team_id, auth.uid()) IN ('owner', 'admin')
    );

DROP POLICY IF EXISTS team_page_blocks_select_policy ON team_page_blocks;
CREATE POLICY team_page_blocks_select_policy ON team_page_blocks
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1
            FROM team_pages
            WHERE team_pages.id = team_page_blocks.page_id
              AND is_team_member(team_pages.team_id, auth.uid())
        )
    );

DROP POLICY IF EXISTS team_page_blocks_insert_policy ON team_page_blocks;
CREATE POLICY team_page_blocks_insert_policy ON team_page_blocks
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM team_pages
            WHERE team_pages.id = team_page_blocks.page_id
              AND is_team_member(team_pages.team_id, auth.uid())
        )
    );

DROP POLICY IF EXISTS team_page_blocks_update_policy ON team_page_blocks;
CREATE POLICY team_page_blocks_update_policy ON team_page_blocks
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1
            FROM team_pages
            WHERE team_pages.id = team_page_blocks.page_id
              AND is_team_member(team_pages.team_id, auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM team_pages
            WHERE team_pages.id = team_page_blocks.page_id
              AND is_team_member(team_pages.team_id, auth.uid())
        )
    );

DROP POLICY IF EXISTS team_page_blocks_delete_policy ON team_page_blocks;
CREATE POLICY team_page_blocks_delete_policy ON team_page_blocks
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1
            FROM team_pages
            WHERE team_pages.id = team_page_blocks.page_id
              AND is_team_member(team_pages.team_id, auth.uid())
        )
    );

CREATE OR REPLACE FUNCTION update_team_pages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS team_pages_updated_at_trigger ON team_pages;
CREATE TRIGGER team_pages_updated_at_trigger
    BEFORE UPDATE ON team_pages
    FOR EACH ROW
    EXECUTE FUNCTION update_team_pages_updated_at();
