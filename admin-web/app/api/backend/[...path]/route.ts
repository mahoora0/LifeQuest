const backendBase = (process.env.BACKEND_API_BASE_URL || "http://localhost:8080/api").replace(/\/$/, "");

async function forward(request: Request) {
  const incoming = new URL(request.url);
  const marker = "/api/backend/";
  const path = incoming.pathname.slice(incoming.pathname.indexOf(marker) + marker.length);
  const target = `${backendBase}/${path}${incoming.search}`;
  const headers = new Headers();
  const authorization = request.headers.get("authorization");
  if (authorization) headers.set("authorization", authorization);
  const contentType = request.headers.get("content-type");
  if (contentType) headers.set("content-type", contentType);

  const response = await fetch(target, {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : await request.arrayBuffer(),
  });
  return new Response(response.body, {
    status: response.status,
    headers: { "content-type": response.headers.get("content-type") || "application/json" },
  });
}

export const GET = forward;
export const POST = forward;
export const PATCH = forward;
export const DELETE = forward;
