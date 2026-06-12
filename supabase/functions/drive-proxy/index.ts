import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.13.1/index.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};

// ─── Google OAuth2 Access Token Exchange ─────────────────────────────────────
async function getGoogleAccessToken(email: string, privateKey: string): Promise<string> {
  const cleanedKey = privateKey.replace(/\\n/g, "\n");
  
  const jwt = await new SignJWT({
    scope: "https://www.googleapis.com/auth/drive",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(email)
    .setSubject(email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(await importPKCS8(cleanedKey, "RS256"));

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Google OAuth exchange failed: ${errorText}`);
  }

  const data = await response.json();
  return data.access_token;
}

// ─── Main Deno Serve Handler ──────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // 1. Handle CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const path = url.pathname.split("/").pop();

  try {
    // 2. Authenticate the incoming client JWT using Supabase auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    const token = authHeader.replace(/^Bearer\s+/i, "");
    let isAuthorized = false;

    if (token === supabaseAnonKey || (serviceRoleKey && token === serviceRoleKey)) {
      isAuthorized = true;
    } else {
      // Fallback: verify as a user session JWT
      const supabase = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (!authError && user) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      return new Response(JSON.stringify({ error: "Unauthorized session JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Load Google Drive Service Account Secrets
    const serviceAccountEmail = Deno.env.get("GD_SERVICE_ACCOUNT_EMAIL");
    const serviceAccountKey = Deno.env.get("GD_PRIVATE_KEY");
    const parentFolderId = Deno.env.get("GD_PARENT_FOLDER_ID");

    if (!serviceAccountEmail || !serviceAccountKey) {
      return new Response(
        JSON.stringify({
          error: "Google Drive proxy secrets are not configured in your Supabase dashboard.",
          setupInstructions: "Set 'GD_SERVICE_ACCOUNT_EMAIL' and 'GD_PRIVATE_KEY' in your Supabase project secrets.",
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Handle Route: GET /info (returns service account email for client sharing)
    if (req.method === "GET" && path === "info") {
      return new Response(JSON.stringify({ serviceAccountEmail }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Handle Route: POST /upload
    if (req.method === "POST" && path === "upload") {
      const filename = url.searchParams.get("name") || `file_${Date.now()}.enc`;
      const token = await getGoogleAccessToken(serviceAccountEmail, serviceAccountKey);

      // Construct a raw multipart/related body to attach folder parent and file name
      const boundary = "boundary_nosus_gdrive_upload";
      const metadata = {
        name: filename,
        parents: parentFolderId ? [parentFolderId] : undefined,
      };

      const metadataPart = `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n`;
      const mediaHeader = `--${boundary}\r\nContent-Type: application/octet-stream\r\n\r\n`;
      const mediaFooter = `\r\n--${boundary}--`;

      const encoder = new TextEncoder();
      const metadataBytes = encoder.encode(metadataPart);
      const mediaHeaderBytes = encoder.encode(mediaHeader);
      const mediaFooterBytes = encoder.encode(mediaFooter);
      const fileBytes = new Uint8Array(await req.arrayBuffer());

      // Combine parts
      const body = new Uint8Array(
        metadataBytes.length + mediaHeaderBytes.length + fileBytes.length + mediaFooterBytes.length
      );
      let offset = 0;
      body.set(metadataBytes, offset); offset += metadataBytes.length;
      body.set(mediaHeaderBytes, offset); offset += mediaHeaderBytes.length;
      body.set(fileBytes, offset); offset += fileBytes.length;
      body.set(mediaFooterBytes, offset);

      const uploadResponse = await fetch("https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": `multipart/related; boundary=${boundary}`,
        },
        body,
      });

      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
        return new Response(JSON.stringify({ error: `Google Drive upload failed: ${errorText}` }), {
          status: uploadResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const data = await uploadResponse.json();
      return new Response(JSON.stringify({ fileId: data.id }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 5. Handle Route: GET /download
    if (req.method === "GET" && path === "download") {
      const fileId = url.searchParams.get("fileId");
      if (!fileId) {
        return new Response(JSON.stringify({ error: "Missing fileId parameter" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const token = await getGoogleAccessToken(serviceAccountEmail, serviceAccountKey);
      const driveResponse = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`, {
        headers: {
          "Authorization": `Bearer ${token}`,
        },
      });

      if (!driveResponse.ok) {
        const errorText = await driveResponse.text();
        return new Response(JSON.stringify({ error: `Google Drive file retrieval failed: ${errorText}` }), {
          status: driveResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Pipe the Google Drive stream directly back to the client response
      return new Response(driveResponse.body, {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": driveResponse.headers.get("Content-Type") || "application/octet-stream",
          "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
          "Pragma": "no-cache",
        },
      });
    }

    // 6. Handle Route: DELETE /delete
    if (req.method === "DELETE" && path === "delete") {
      const fileId = url.searchParams.get("fileId");
      if (!fileId) {
        return new Response(JSON.stringify({ error: "Missing fileId parameter" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const token = await getGoogleAccessToken(serviceAccountEmail, serviceAccountKey);
      const deleteResponse = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}`, {
        method: "DELETE",
        headers: {
          "Authorization": `Bearer ${token}`,
        },
      });

      if (!deleteResponse.ok && deleteResponse.status !== 404) {
        const errorText = await deleteResponse.text();
        return new Response(JSON.stringify({ error: `Google Drive file deletion failed: ${errorText}` }), {
          status: deleteResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Route not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
