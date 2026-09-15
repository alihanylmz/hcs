// Teklif e-postasini teklif@uzalteknik.com adresinden gercekten gonderir.
// Su ana kadar uygulama sadece Windows'ta yerel Outlook'u aciyordu
// (bkz. lib/services/outlook_attachment_email_service.dart); bu fonksiyon
// onun yerine gecebilecek, sunucu tarafli gercek SMTP gonderimidir.
//
// Tasarim karari: "From" HER ZAMAN sabit kurumsal kutu (teklif@uzalteknik.com)
// - boylece SPF/DKIM/DMARC tek domain uzerinden yonetilir ve musteri hep ayni
// kurumsal adresten mail gelmis gorur. Gonderen personelin kendi adresi
// "Reply-To" olarak eklenir - musteri "Yanitla" dediginde mail dogrudan o
// personele gider, ama gonderen kutu hicbir zaman degismez. Reply-To, HER
// ZAMAN o an giris yapmis kullanicinin kendi hesabidir (sabit bir kisi degil).
//
// Cagiran taraf giris yapmis olmali (Authorization: Bearer <user jwt>).
// Istek govdesi:
// {
//   "quoteId": "...",           // sadece log/hata mesaji icin, zorunlu degil
//   "quoteCode": "UZ-...",
//   "to": "musteri@firma.com",
//   "customerName": "...",      // opsiyonel, selamlamada kullanilir
//   "cc": "personel@uzalteknik.com", // opsiyonel, virgulle ayrik
//   "subject": "...",
//   "body": "...",              // duz metin, e-posta govdesinin giris paragrafi
//   "senderName": "...",        // gonderen personelin adi soyadi (imza + Reply-To)
//   "senderTitle": "...",       // unvan (imza)
//   "senderPhone": "...",       // telefon (imza)
//   "senderEmail": "...",       // kisisel is e-postasi (Reply-To + imza)
//   "attachmentBase64": "...",  // opsiyonel, PDF icerigi
//   "attachmentFilename": "UZ-....pdf"
// }
import { createClient } from "npm:@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

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

// denomailer, "\n" satirlarini oldugu gibi (CR eklemeden) SMTP DATA
// govdesine yaziyor. Cogu mail sunucusu artik "naked LF" (CR'siz LF)
// iceren govdeleri SMTP smuggling savunmasi olarak 501 ile reddediyor
// (bkz. Surgemail "Failure Naked LF"). Gondermeden once tum satir
// sonlarini CRLF'ye ceviriyoruz.
function toCrlf(text: string): string {
  return text.replace(/\r\n/g, "\n").replace(/\n/g, "\r\n");
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function paragraphsHtml(text: string): string {
  return text
    .split(/\n{2,}/)
    .map((block) =>
      `<p style="margin:0 0 14px 0;">${
        escapeHtml(block).replace(/\n/g, "<br>")
      }</p>`
    )
    .join("");
}

/** Premium B2B teklif sunumu gorunumlu HTML e-posta govdesi uretir. */
function buildQuoteEmailHtml(params: {
  quoteCode: string;
  customerName: string;
  introText: string;
  senderName: string;
  senderTitle: string;
  senderEmail: string;
  senderPhone: string;
  hasAttachment: boolean;
}): string {
  const {
    quoteCode,
    customerName,
    introText,
    senderName,
    senderTitle,
    senderEmail,
    senderPhone,
    hasAttachment,
  } = params;

  const greeting = customerName.trim()
    ? `Sayın ${escapeHtml(customerName.trim())},`
    : "Sayın Yetkili,";

  const signatureRows: string[] = [];
  if (senderName) {
    signatureRows.push(
      `<div style="font-size:16px;font-weight:700;color:#111827;">${
        escapeHtml(senderName)
      }</div>`,
    );
  }
  if (senderTitle) {
    signatureRows.push(
      `<div style="font-size:13px;color:#6b7280;margin-top:4px;">${
        escapeHtml(senderTitle)
      }</div>`,
    );
  }
  signatureRows.push(
    `<div style="font-size:13px;color:#6b7280;margin-top:8px;">UZAL TEKNİK</div>`,
  );
  if (senderEmail) {
    signatureRows.push(
      `<div style="font-size:13px;color:#6b7280;margin-top:4px;"><a href="mailto:${
        escapeHtml(senderEmail)
      }" style="color:#1f9d68;text-decoration:none;">${
        escapeHtml(senderEmail)
      }</a></div>`,
    );
  }
  if (senderPhone) {
    signatureRows.push(
      `<div style="font-size:13px;color:#6b7280;margin-top:4px;">${
        escapeHtml(senderPhone)
      }</div>`,
    );
  }
  signatureRows.push(
    `<div style="font-size:13px;margin-top:4px;"><a href="https://uzalteknik.com" style="color:#1f9d68;text-decoration:none;">www.uzalteknik.com</a></div>`,
  );

  return `<!doctype html>
<html lang="tr">
  <body style="margin:0;padding:0;background-color:#f3f4f6;font-family:Segoe UI, Arial, sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f3f4f6;padding:32px 0;">
      <tr>
        <td align="center">
          <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <tr>
              <td style="background-color:#1f2937;padding:28px 32px;">
                <div style="font-size:20px;font-weight:800;letter-spacing:0.5px;color:#ffffff;">UZAL TEKNİK</div>
                <div style="font-size:12px;color:#9ca3af;margin-top:4px;">Otomasyon &amp; Mühendislik Çözümleri</div>
              </td>
            </tr>
            <tr>
              <td style="height:4px;background:linear-gradient(90deg,#1f9d68,#2b82c9);"></td>
            </tr>
            <tr>
              <td style="padding:32px;">
                <div style="display:inline-block;background-color:#e6f2fb;color:#2b82c9;font-size:12px;font-weight:700;padding:6px 12px;border-radius:999px;margin-bottom:16px;">
                  TEKLİF NO: ${escapeHtml(quoteCode)}
                </div>
                <p style="margin:0 0 14px 0;font-size:15px;color:#111827;">${greeting}</p>
                ${
    introText.trim()
      ? paragraphsHtml(introText.trim())
      : `<p style="margin:0 0 14px 0;font-size:15px;color:#111827;">${
        escapeHtml(quoteCode)
      } kodlu teklifimizi ekte bilgilerinize sunuyoruz.</p>`
  }
                ${
    hasAttachment
      ? `<table role="presentation" cellpadding="0" cellspacing="0" style="margin-top:8px;background-color:#f6f8fa;border:1px solid #d7dee6;border-radius:10px;">
                  <tr>
                    <td style="padding:12px 16px;font-size:13px;color:#17304c;font-weight:700;">
                      📎 Teklif dosyası PDF olarak bu e-postaya eklenmiştir.
                    </td>
                  </tr>
                </table>`
      : ""
  }
                <p style="margin:24px 0 0 0;font-size:14px;color:#111827;">Bilgilerinize saygılarımızla,</p>
                <div style="margin-top:20px;border-top:1px solid #e5e7eb;padding-top:20px;">
                  ${signatureRows.join("\n                  ")}
                </div>
              </td>
            </tr>
            <tr>
              <td style="background-color:#f9fafb;padding:16px 32px;border-top:1px solid #e5e7eb;">
                <div style="font-size:11px;color:#9ca3af;">Bu e-posta UZAL TEKNİK teklif sistemi tarafından gönderilmiştir.</div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
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
    // Birden fazla adres virgulle ayrilmis tek string olarak gelebilir.
    const cc = ccRaw
      ? ccRaw
          .split(",")
          .map((addr) => addr.trim())
          .filter((addr) => addr.length > 0)
      : undefined;
    const quoteCode = (payload.quoteCode as string | undefined)?.trim() ?? "";
    const customerName =
      (payload.customerName as string | undefined)?.trim() ?? "";
    const subject = (payload.subject as string | undefined)?.trim() ??
      (quoteCode ? `UZAL TEKNİK | ${quoteCode} Nolu Teklifiniz` : "Teklif");
    const introText = (payload.body as string | undefined) ?? "";
    const senderName = (payload.senderName as string | undefined)?.trim() ??
      "";
    const senderTitle = (payload.senderTitle as string | undefined)?.trim() ??
      "";
    const senderPhone = (payload.senderPhone as string | undefined)?.trim() ??
      "";
    const senderEmail = (payload.senderEmail as string | undefined)?.trim() ??
      "";
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

    const html = buildQuoteEmailHtml({
      quoteCode,
      customerName,
      introText,
      senderName,
      senderTitle,
      senderEmail,
      senderPhone,
      hasAttachment: Boolean(attachmentBase64),
    });
    const plainTextFallback = toCrlf(
      `${customerName ? `Sayın ${customerName},` : "Sayın Yetkili,"}\n\n${
        introText.trim() || `${quoteCode} kodlu teklifimizi ekte bilgilerinize sunuyoruz.`
      }\n\nBilgilerinize saygılarımızla,\n${
        [senderName, senderTitle, "UZAL TEKNİK", senderEmail, senderPhone]
          .filter((v) => v)
          .join("\n")
      }`,
    );

    // denomailer 1.6 API: baglanti bilgisi constructor'a verilir, `.send()`
    // ilk cagrida kendisi baglanir - eski surumdeki `.connect()` metodu
    // artik yok (bu, edge fonksiyonunun BOOT_ERROR ile hic ayaga kalkamama
    // sebebiydi: `SmtpClient` diye bir export de yoktu, dogrusu `SMTPClient`).
    const client = new SMTPClient({
      connection: {
        hostname: mailHost,
        port: mailPort,
        tls: true,
        auth: { username: mailUser, password: mailPassword },
      },
    });

    try {
      await client.send({
        // "From" her zaman sabit kurumsal kutu - kisisel adreslerden
        // gonderim SPF/DKIM/DMARC sorunlarina yol acar. Musterinin
        // "Yanitla" dedigi mail, asagidaki replyTo sayesinde dogrudan
        // o an giris yapmis olan personele gider.
        from: `UZAL TEKNİK <${mailUser}>`,
        to,
        cc,
        replyTo: senderEmail
          ? `${senderName || "UZAL TEKNİK"} <${senderEmail}>`
          : undefined,
        subject,
        content: plainTextFallback,
        html,
        attachments: attachmentBase64
          ? [
              {
                filename: attachmentFilename,
                contentType: "application/pdf",
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
