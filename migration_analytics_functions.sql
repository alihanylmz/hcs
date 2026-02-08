-- ============================================
-- ANALİTİK RPC FONKSİYONLARI
-- Takım performans metrikleri için
-- ============================================

-- 1) Ortalama Lead Time Hesaplama
-- Lead Time = done_at - created_at (saat cinsinden)
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

-- 2) Ortalama Cycle Time Hesaplama
-- Cycle Time = done_at - first_doing_at (saat cinsinden)
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

-- 3) TODO Dwell Time (Ortalama TODO'da kalma süresi)
-- TODO Dwell = first_doing_at - created_at
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

-- 4) DOING Dwell Time (Ortalama DOING'de kalma süresi)
-- DOING Dwell = done_at - first_doing_at
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

-- 5) Kullanıcı Bazında Tamamlama İstatistikleri
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
-- ANALİTİK FONKSİYONLARI TAMAMLANDI ✅
-- ============================================
