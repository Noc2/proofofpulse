import { createServer } from "node:http";
import { createApi } from "./app.js";

export function startServer({ port = process.env.PORT ?? 8787, host = "127.0.0.1" } = {}) {
  const api = createApi();
  const server = createServer(async (request, response) => {
    const webRequest = new Request(`http://${request.headers.host}${request.url}`, {
      method: request.method,
      headers: request.headers,
      body: request.method === "GET" || request.method === "HEAD" ? undefined : request,
      duplex: "half"
    });

    const webResponse = await api(webRequest);
    response.writeHead(webResponse.status, Object.fromEntries(webResponse.headers));
    response.end(await webResponse.text());
  });

  server.listen(port, host, () => {
    const address = server.address();
    console.log(`Proof of Pulse API listening on http://${address.address}:${address.port}`);
  });

  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  startServer();
}
