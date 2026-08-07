import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing Supabase service configuration.");
    }

    const { usdTry, eurTry } = await fetchTcmbRates().catch(
      fetchExchangeRateFallback,
    );

    const now = new Date().toISOString();

    const rows = [
      {
        code: "USDTRY",
        label: "Dolar",
        unit_label: "1 USD",
        value: usdTry,
        is_fallback: false,
        sort_order: 10,
        updated_at: now,
      },
      {
        code: "EURTRY",
        label: "Euro",
        unit_label: "1 EUR",
        value: eurTry,
        is_fallback: false,
        sort_order: 20,
        updated_at: now,
      },
    ];

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const { error } = await supabase.from("market_rates").upsert(rows);

    if (error) {
      throw error;
    }

    return json({ ok: true, updated_at: now, rates: rows });
  } catch (error) {
    return json(
      {
        ok: false,
        error: error instanceof Error ? error.message : String(error),
      },
      500,
    );
  }
});

async function fetchTcmbRates(): Promise<{ usdTry: number; eurTry: number }> {
  const response = await fetch("https://www.tcmb.gov.tr/kurlar/today.xml");
  if (!response.ok) {
    throw new Error("TCMB rates could not be fetched.");
  }

  const xml = await response.text();
  return {
    usdTry: readTcmbForexSelling(xml, "USD"),
    eurTry: readTcmbForexSelling(xml, "EUR"),
  };
}

function readTcmbForexSelling(xml: string, code: "USD" | "EUR"): number {
  const pattern = new RegExp(
    `<Currency[^>]+(?:Kod|CurrencyCode)="${code}"[\\s\\S]*?<ForexSelling>([^<]+)</ForexSelling>`,
  );
  const match = xml.match(pattern);
  const value = Number(match?.[1]);

  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${code}/TRY TCMB selling rate is missing.`);
  }

  return value;
}

async function fetchExchangeRateFallback(): Promise<{
  usdTry: number;
  eurTry: number;
}> {
  const [usdTry, eurTry] = await Promise.all([
    fetchExchangeRate("USD"),
    fetchExchangeRate("EUR"),
  ]);

  return { usdTry, eurTry };
}

async function fetchExchangeRate(base: "USD" | "EUR"): Promise<number> {
  const response = await fetch(`https://open.er-api.com/v6/latest/${base}`);
  if (!response.ok) {
    throw new Error(`${base}/TRY rate could not be fetched.`);
  }

  const body = (await response.json()) as { rates?: Record<string, number> };
  const tryValue = body.rates?.TRY;
  if (typeof tryValue !== "number") {
    throw new Error(`${base}/TRY rate is missing.`);
  }

  return tryValue;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
