import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type HookPayload = {
  user?: {
    phone?: string | null;
  };
  sms?: {
    otp?: string | null;
  };
};

type SmsRuMessageResult = {
  status?: string;
  status_code?: number;
  status_text?: string;
  sms_id?: string;
};

type SmsRuResponse = {
  status?: string;
  status_code?: number;
  status_text?: string;
  sms?: Record<string, SmsRuMessageResult>;
};

function errorResponse(message: string, status = 500) {
  return new Response(
    JSON.stringify({
      error: {
        http_code: status,
        message,
      },
    }),
    {
      status,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      },
    },
  );
}

function normalizeRussianPhone(value: unknown) {
  const digits = String(value ?? "").replace(/\D/g, "");
  if (digits.length === 10) return `7${digits}`;
  if (digits.length === 11 && digits.startsWith("8")) {
    return `7${digits.slice(1)}`;
  }
  if (digits.length === 11 && digits.startsWith("7")) return digits;
  return "";
}

function isSixDigitOtp(value: string) {
  return /^\d{6}$/.test(value);
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return errorResponse("Метод не поддерживается", 405);
  }

  const hookSecret = Deno.env.get("SEND_SMS_HOOK_SECRET")?.trim() ?? "";
  const smsRuApiId = Deno.env.get("SMS_RU_API_ID")?.trim() ?? "";
  const smsRuSender = Deno.env.get("SMS_RU_SENDER")?.trim() ?? "";
  const testMode =
    (Deno.env.get("SMS_RU_TEST_MODE")?.trim().toLowerCase() ?? "false") ===
      "true";

  if (!hookSecret || !smsRuApiId) {
    return errorResponse("Сервис отправки кодов не настроен", 500);
  }

  try {
    const rawPayload = await request.text();
    const verificationSecret = hookSecret.replace(/^v1,whsec_/, "");
    const webhook = new Webhook(verificationSecret);
    const payload = webhook.verify(
      rawPayload,
      Object.fromEntries(request.headers),
    ) as HookPayload;

    const phone = normalizeRussianPhone(payload.user?.phone);
    const otp = String(payload.sms?.otp ?? "").trim();
    if (!phone || !isSixDigitOtp(otp)) {
      return errorResponse("Некорректные данные для отправки кода", 400);
    }

    const params = new URLSearchParams({
      api_id: smsRuApiId,
      to: phone,
      msg: `Код входа в AppСтрой: ${otp}. Никому его не сообщайте.`,
      json: "1",
    });
    if (smsRuSender) params.set("from", smsRuSender);
    if (testMode) params.set("test", "1");

    const response = await fetch("https://sms.ru/sms/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=utf-8",
      },
      body: params,
      signal: AbortSignal.timeout(4000),
    });

    const rawResponse = await response.text();
    let result: SmsRuResponse;
    try {
      result = JSON.parse(rawResponse) as SmsRuResponse;
    } catch {
      console.error("SMS.RU returned a non-JSON response", response.status);
      return errorResponse("Сервис SMS вернул некорректный ответ", 502);
    }

    const messageResult = result.sms?.[phone];
    const accepted =
      response.ok &&
      result.status === "OK" &&
      result.status_code === 100 &&
      messageResult?.status === "OK" &&
      messageResult.status_code === 100;

    if (!accepted) {
      console.error("SMS.RU rejected auth message", {
        httpStatus: response.status,
        statusCode: result.status_code,
        messageStatusCode: messageResult?.status_code,
      });
      return errorResponse(
        messageResult?.status_text ||
          result.status_text ||
          "Не удалось отправить код входа",
        502,
      );
    }

    return new Response("{}", {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    console.error("Auth SMS hook failed", {
      name: error instanceof Error ? error.name : "UnknownError",
      message: error instanceof Error ? error.message : String(error),
    });
    return errorResponse("Не удалось отправить код входа", 500);
  }
});
