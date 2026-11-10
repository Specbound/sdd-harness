---
name: m365-agents
description: Build multichannel Teams/M365/Copilot Studio agents with the Microsoft 365 Agents SDK (.NET, Python, TypeScript) — AgentApplication routing, hosting, auth, streaming, Copilot Studio client. Use with Microsoft.Agents, microsoft_agents, or @microsoft/agents-* packages.
---

# Microsoft 365 Agents SDK

One SDK family, three languages, same shape: an `AgentApplication` registers activity handlers, a host process (ASP.NET Core / aiohttp / Express) receives channel traffic and dispatches it through an adapter, and an optional Copilot Studio client talks directly to a Copilot Studio agent.

## Before implementation
- Use the microsoft-docs MCP to verify current API signatures for `AgentApplication`, hosting setup, and auth options — this SDK moves fast.
- Confirm package versions (NuGet / PyPI / npm) before wiring up samples.
- Python note: recent versions renamed the import root from `microsoft.agents` to `microsoft_agents` (underscores) — a frequent breaking-change trap.

## Install

```bash
# .NET
dotnet add package Microsoft.Agents.Hosting.AspNetCore
dotnet add package Microsoft.Agents.Authentication.Msal
dotnet add package Microsoft.Agents.CopilotStudio.Client

# Python
pip install microsoft-agents-hosting-core microsoft-agents-hosting-aiohttp \
  microsoft-agents-activity microsoft-agents-authentication-msal \
  microsoft-agents-copilotstudio-client python-dotenv aiohttp

# TypeScript / Node
npm install @microsoft/agents-hosting @microsoft/agents-hosting-express \
  @microsoft/agents-activity @microsoft/agents-copilotstudio-client
```

## Core pattern: register handlers, start a host

**.NET** (ASP.NET Core, `AgentApplication` subclass):
```csharp
public sealed class MyAgent : AgentApplication {
    public MyAgent(AgentApplicationOptions options) : base(options) {
        OnConversationUpdate(ConversationUpdateEvents.MembersAdded, WelcomeAsync);
        OnActivity(ActivityTypes.Message, OnMessageAsync, rank: RouteRank.Last);
        OnTurnError(OnTurnErrorAsync);
    }
    // handlers: Task Foo(ITurnContext turnContext, ITurnState turnState, CancellationToken ct)
}
// Program.cs
builder.AddAgentApplicationOptions();
builder.AddAgent<MyAgent>();
builder.Services.AddSingleton<IStorage, MemoryStorage>();
builder.Services.AddAgentAspNetAuthentication(builder.Configuration);
app.MapPost("/api/messages", async (HttpRequest req, HttpResponse res, IAgentHttpAdapter adapter, IAgent agent, CancellationToken ct)
    => await adapter.ProcessAsync(req, res, agent, ct));
```
Config lives in `appsettings.json` under `TokenValidation`, `AgentApplication`, `Connections.ServiceConnection` (ClientId/ClientSecret/TenantId), `ConnectionsMap`.

**Python** (aiohttp):
```python
AGENT_APP = AgentApplication[TurnState](...)

@AGENT_APP.conversation_update("membersAdded")
async def on_members_added(context: TurnContext, _state: TurnState):
    await context.send_activity("Welcome!")

@AGENT_APP.message("/status")          # string match
@AGENT_APP.message(re.compile(r"^hi$")) # or regex
async def on_status(context: TurnContext, _state: TurnState):
    await context.send_activity("Status: OK")

@AGENT_APP.activity("message")          # fallback catch-all
async def on_message(context: TurnContext, _state: TurnState):
    await context.send_activity(f"Echo: {context.activity.text}")

@AGENT_APP.error
async def on_error(context: TurnContext, error: Exception): ...
```
Config via env vars (`CONNECTIONS__SERVICE_CONNECTION__SETTINGS__*`) loaded with `load_configuration_from_env(environ)`; wire `jwt_authorization_middleware` into the aiohttp `Application`, serve via `start_agent_process(req, agent, adapter)` on `POST /api/messages`.

**TypeScript** (Express):
```typescript
const agent = new AgentApplication<TurnState>();
agent.onConversationUpdate("membersAdded", async (context: TurnContext) => {
  await context.sendActivity("Welcome to the agent.");
});
agent.onMessage("hello", async (context: TurnContext) => {
  await context.sendActivity(`Echo: ${context.activity.text}`);
});
startServer(agent);
```
Config via env vars (`TENANT_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `PORT`, Azure OpenAI vars).

## Streaming responses (Python & TypeScript)
Both SDKs expose `context.streaming_response` / `context.streamingResponse` for incremental AI output:
1. Set metadata: `set_feedback_loop(True)`, `set_generated_by_ai_label(True)`, `set_sensitivity_label(...)`.
2. `queue_informative_update(...)` for a status line, then `queue_text_chunk(...)` per streamed delta.
3. **Always** call `end_stream()` in a `finally` block so the channel closes the stream cleanly even on error.

## Invoke activities
Handle `ActivityTypes.invoke` explicitly and reply with an `InvokeResponse` activity (`{type: invokeResponse, value: {status: 200}}`) — required for adaptive-card actions and Teams task modules across all three languages.

## Copilot Studio direct-to-engine client
All three expose a `CopilotClient`/`CopilotStudioClient` that talks straight to a Copilot Studio agent (bypassing the channel/bot framework):
- Acquire a token (MSAL interactive/silent in .NET and Python; a bearer-token provider function in TS).
- `client.StartConversationAsync()` / `start_conversation(True)` / `startConversationAsync()` → async stream of activities.
- `client.AskQuestionAsync("Hello!", conversationId)` to send a turn and read replies.
- TS additionally ships `CopilotStudioWebChat.createConnection(client, ...)` to drop a Copilot Studio agent into a WebChat UI.

## Best practices (all languages)
1. Keep one `AgentApplication`/handler set per concern — don't overload a single fallback handler.
2. `MemoryStorage` is dev-only — use persisted storage (Blob/CosmosDB/etc.) in production.
3. Require auth on `/api/messages` in production (`TokenValidation.Enabled`, `RequireAuthorization()`, `jwt_authorization_middleware`).
4. Load secrets from configuration providers/env vars/Key Vault — never hardcode.
5. Reuse HTTP clients and cache MSAL tokens instead of re-acquiring per request.
6. Always use `CancellationToken`/async cancellation plumbing through handlers.

## Reference links
- SDK overview: https://learn.microsoft.com/en-us/microsoft-365/agents-sdk/
- Copilot Studio integration: https://learn.microsoft.com/en-us/microsoft-365/agents-sdk/integrate-with-mcs
- .NET samples: https://github.com/microsoft/agents
- Python samples: https://github.com/microsoft/Agents-for-python
- Node samples: https://github.com/microsoft/Agents/tree/main/samples/nodejs
