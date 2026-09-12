// Teklif e-postasini teklif@uzalteknik.com adresinden gercekten gonderir.
// Su ana kadar uygulama sadece Windows'ta yerel Outlook'u aciyordu
// (bkz. lib/services/outlook_attachment_email_service.dart); bu fonksiyon
// onun yerine gecebilecek, sunucu tarafli gercek SMTP gonderimidir.
//
// Cagiran taraf giris yapmis olmali (Authorization: Bearer <user jwt>).
// Istek govdesi:
// {
//   "quoteId": "...",           // sadece log/hata mesaji icin, zorunlu degil
//   "to": "musteri@firma.com",
//   "cc": "teklif@uzalteknik.com,personel@uzalteknik.com", // opsiyonel, virgulle ayrik
//   "subject": "...",
//   "body": "...",              // duz metin
//   "attachmentBase64": "...",  // opsiyonel, PDF icerigi
//   "attachmentFilename": "UZ-....pdf"
// }
import { createClient } from "npm:@supabase/supabase-js@2";
import { SmtpClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64ToUint8Array(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error("Missing Supabase service configuration.");
    }
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header." }, 401);
    }

    // Cagiranin gercekten oturum acmis bir kullanici oldugunu dogrula.
    // Bu fonksiyon herkese acik hale gelirse spam relay riski olur.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Invalid session." }, 401);
    }

    const payload = await req.json();
    const to = (payload.to as string | undefined)?.trim();
    const ccRaw = (payload.cc as string | undefined)?.trim();
    // Birden fazla adres virgulle ayrilmis tek string olarak gelebilir
    // (ornek: kurumsal kutu + gonderen personel).
    const cc = ccRaw
      ? ccRaw
          .split(",")
          .map((addr) => addr.trim())
          .filter((addr) => addr.length > 0)
      : undefined;
    const subject = (payload.subject as string | undefined)?.trim() ?? "";
    const body = (payload.body as string | undefined) ?? "";
    const attachmentBase64 = payload.attachmentBase64 as string | undefined;
    const attachmentFilename =
      (payload.attachmentFilename as string | undefined) ?? "teklif.pdf";

    if (!to) {
      return jsonResponse({ error: "'to' alani zorunlu." }, 400);
    }

    const mailHost = Deno.env.get("QUOTE_MAIL_HOST");
    const mailPort = Number(Deno.env.get("QUOTE_MAIL_SMTP_PORT") ?? "465");
    const mailUser = Deno.env.get("QUOTE_MAIL_USER");
    const mailPassword = Deno.env.get("QUOTE_MAIL_PASSWORD");

    if (!mailHost || !mailUser || !mailPassword) {
      throw new Error(
        "QUOTE_MAIL_HOST / QUOTE_MAIL_USER / QUOTE_MAIL_PASSWORD ayarlanmamis.",
      );
    }

    const client = new SmtpClient();
    await client.connect({
      hostname: mailHost,
      port: mailPort,
      auth: { username: mailUser, password: mailPassword },
      tls: true,
    });

    try {
      await client.send({
        from: mailUser,
        to,
        cc,
        subject,
        content: body,
        attachments: attachmentBase64
          ? [
              {
                filename: attachmentFilename,
                content: base64ToUint8Array(attachmentBase64),
                encoding: "binary",
              },
            ]
          : undefined,
      });
    } finally {
      await client.close();
    }

    return jsonResponse({
      sent: true,
      to,
      sentBy: userData.user.id,
      sentAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error("send-quote-email failed", error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});
