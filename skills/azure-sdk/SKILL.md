---
name: azure-sdk
description: "Azure SDK reference across Python, TS, .NET, Java, Rust: package/client names, DefaultAzureCredential auth, retry/pagination/LRO for Storage, Cosmos DB, Key Vault, Event Hub/Grid, Service Bus, AI Foundry, Search, Monitor, ARM. Use when picking an Azure client or debugging auth/retry/pagination."
---

# Azure SDK (cross-language)

Consolidated reference for the Azure SDK family: 118 per-service, per-language skills
merged into one map. Use the table to find the right package + client class, then the
pattern sections for auth, retry, pagination, and long-running operations — these are
near-identical across services within a language, so they're documented once here
instead of per service.

## Package naming convention

Once you know the service "suffix" (e.g. `storage-blob`, `keyvault-secrets`), the
package name is usually mechanical:

| Lang | Pattern | Example |
|---|---|---|
| Python | `azure-<suffix>` | `azure-storage-blob` |
| TypeScript | `@azure/<suffix>` (raw/REST-only SDKs: `@azure-rest/<suffix>`) | `@azure/storage-blob`, `@azure-rest/ai-content-safety` |
| .NET | `Azure.<Suffix>` (PascalCase, mgmt = `Azure.ResourceManager.<Rp>`) | `Azure.Storage.Blobs` |
| Java | `com.azure:azure-<suffix>` | `com.azure:azure-storage-blob` |
| Rust | `azure_<suffix>` (snake_case) | `azure_storage_blob` |

Exceptions worth knowing: Java `azure-data-appconfiguration` (not `azure-appconfiguration`),
Java/.NET Key Vault use `Azure.Security.KeyVault.*` / `com.azure:azure-security-keyvault-*`
(not `keyvault-*`), TS translation/content-safety ship as raw REST clients under
`@azure-rest/*` with a different ergonomics (no high-level wrapper).

## DefaultAzureCredential per language

All languages but Rust use `DefaultAzureCredential`; Rust's newer SDK generation uses
`DeveloperToolsCredential` (CLI/azd-only chain — no env var or managed-identity hop,
by design, for local dev) plus `ManagedIdentityCredential` for prod.

```python
# Python
from azure.identity import DefaultAzureCredential
credential = DefaultAzureCredential()
```
```typescript
// TypeScript
import { DefaultAzureCredential } from "@azure/identity";
const credential = new DefaultAzureCredential();
```
```csharp
// .NET
using Azure.Identity;
var credential = new DefaultAzureCredential();
```
```java
// Java
DefaultAzureCredential credential = new DefaultAzureCredentialBuilder().build();
```
```rust
// Rust
use azure_identity::DeveloperToolsCredential;
let credential = DeveloperToolsCredential::new(None)?;
```

Credential chain order (py/ts/dotnet/java, roughly): Environment → Workload Identity →
Managed Identity → (IDE credentials: VS/VS Code) → Azure CLI → Azure PowerShell →
Azure Developer CLI → (Interactive Browser, opt-in only).

### Env vars (same names across all 5 languages)

```bash
# Service principal — secret
AZURE_TENANT_ID=<tenant-id>
AZURE_CLIENT_ID=<client-id>
AZURE_CLIENT_SECRET=<client-secret>

# Service principal — certificate
AZURE_CLIENT_CERTIFICATE_PATH=<path-to-pem-or-pfx>
AZURE_CLIENT_CERTIFICATE_PASSWORD=<optional>

# User-assigned managed identity
AZURE_CLIENT_ID=<managed-identity-client-id>

# Workload identity (Kubernetes)
AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/tokens/azure-identity
```

Sovereign clouds: pass an `AuthorityHost` / `authorityHost` option
(`AzureAuthorityHosts.AzureGovernment`, `AzureChina`, etc.) — do not hardcode login URLs.

## Retry, pagination, LRO — the three patterns every client shares

**Retry**: built into the transport pipeline, exponential backoff by default. Configure
via client options (`retry_total`/`RetryMode` in py, `retryOptions` in ts,
`ClientOptions.Retry` in .NET, `RetryOptions` in Java, `RetryPolicy` builder in Rust).
Don't hand-roll retry loops around SDK calls — you'll double-retry on top of the
pipeline's own backoff.

**Pagination**: iterator-based, never manual offset math.
- Python: `for item in client.list_x():` or `.by_page()` for page-level control.
- TypeScript: `for await (const item of client.listX())`.
- .NET: `await foreach (var item in client.GetXAsync())` (returns `AsyncPageable<T>`).
- Java: `PagedIterable<T>` / `PagedFlux<T>` (reactive).
- Rust: `.into_stream()` on list operations.

**Long-running operations** (create/delete on mgmt resources, big indexers, etc.) return
a poller, not the final result:
- Python: `poller = client.begin_create_or_update(...); result = poller.result()`.
- .NET: `ArmOperation<T>` / `Operation<T>` — `await op.WaitForCompletionAsync()`.
- Java: `SyncPoller<...>` — `.getFinalResult()`.
- TS: `await client.beginCreateOrUpdateAndWait(...)` (convenience) or `.beginCreateOrUpdate()` + `.pollUntilDone()`.

## Async variants

- Python: mirror submodule, `azure.identity.aio` / `azure.storage.blob.aio`, same class
  names, `async with` + `await`; close credentials explicitly or use a context manager.
- TypeScript: the SDK is async-only (Promises) — there is no separate sync client.
- .NET: every method has an `Async` suffix returning `Task<T>`; sync overloads exist
  alongside, not separately versioned.
- Java: suffix `AsyncClient` (e.g. `BlobServiceAsyncClient`, `CosmosAsyncClient`),
  reactor `Mono`/`Flux` return types, vs. the default sync `...Client`.
- Rust: the SDK is async-only (tokio), no separate sync client.

## Service → package/client map

"—" = no skill for that language in this group. Client names only (see naming
convention above for the package). Multiple clients per cell = typical pairing
(service-level client, resource-level client).

| Service | Python | TypeScript | .NET | Java | Rust |
|---|---|---|---|---|---|
| Identity (auth) | DefaultAzureCredential | DefaultAzureCredential | DefaultAzureCredential | DefaultAzureCredential | DeveloperToolsCredential |
| Storage Blob | BlobServiceClient | BlobServiceClient/BlobClient | — | BlobServiceClient/BlobClient | BlobClient |
| Storage Queue | QueueClient/QueueServiceClient | QueueClient/QueueServiceClient | — | — | — |
| Storage File Share | ShareServiceClient | ShareServiceClient/FileClient | — | — | — |
| Storage File Datalake | DataLakeServiceClient | — | — | — | — |
| Key Vault Secrets | SecretClient | SecretClient | SecretClient (Security.KeyVault.Secrets)¹ | SecretClient | SecretClient |
| Key Vault Keys | KeyClient | KeyClient/CryptographyClient | KeyClient/CryptographyClient | KeyClient/CryptographyClient | KeyClient |
| Key Vault Certificates | CertificateClient¹ | — | — | — | CertificateClient |
| Cosmos DB | CosmosClient | CosmosClient | — | CosmosClient/CosmosAsyncClient | CosmosClient |
| Data Tables | TableClient/TableServiceClient | — | — | TableServiceClient | — |
| Event Hubs | EventHubProducer/ConsumerClient | EventHubProducer/ConsumerClient | EventProcessorClient/EventHubProducerClient | EventProcessorClient | ProducerClient |
| Event Grid | EventGridPublisherClient | — | EventGridPublisherClient | EventGridPublisherClient | — |
| Service Bus | ServiceBusClient | ServiceBusClient | ServiceBusClient | — | — |
| App Configuration | AzureAppConfigurationClient | AppConfigurationClient | — | ConfigurationClient/ConfigurationAsyncClient | — |
| Search Documents | SearchClient/SearchIndexClient | SearchClient/SearchIndexClient | SearchClient/SearchIndexClient | — | — |
| Container Registry | ContainerRegistryClient | — | — | — | — |
| Monitor Query | LogsQueryClient/MetricsQueryClient | — | — | LogsQueryClient/MetricsQueryClient | — |
| Monitor Ingestion | LogsIngestionClient | — | — | LogsIngestionClient | — |
| Monitor OpenTelemetry | configure_azure_monitor() | useAzureMonitor() | AddAzureMonitor...() | AzureMonitorExporter | — |
| Maps Search | — | — | MapsSearchClient | — | — |
| Web PubSub | WebPubSubServiceClient (messaging-webpubsubservice) | WebPubSubServiceClient | — | WebPubSubServiceClient | — |
| Playwright Testing | — | service endpoint via @azure/playwright | ArmClient (mgmt only) | — | — |
| Postgres (driver, not Azure SDK) | — | `pg.Client` + AAD token as password | — | — | — |
| Speech-to-text (REST, no SDK) | raw HTTP via requests | — | — | — | — |
| AI: Projects (Foundry) | AIProjectClient | AIProjectClient | AIProjectClient | AIProjectClient | — |
| AI: Agents Persistent | — | — | PersistentAgentsClient | PersistentAgentsClient | — |
| AI: OpenAI | — | — | AzureOpenAIClient | — | — |
| AI: Content Safety | ContentSafetyClient | ContentSafetyClient (raw REST) | — | ContentSafetyClient | — |
| AI: Content Understanding | ContentUnderstandingClient | — | — | — | — |
| AI: Document Intelligence | — | DocumentIntelligenceClient (raw REST) | DocumentIntelligenceClient | DocumentAnalysisClient (legacy name: Form Recognizer) | — |
| AI: Text Analytics | TextAnalyticsClient | — | — | — | — |
| AI: Translation Text | TextTranslationClient | TextTranslationClient (raw REST) | — | — | — |
| AI: Translation Document | DocumentTranslationClient | DocumentTranslationClient (raw REST) | — | — | — |
| AI: Vision Image Analysis | ImageAnalysisClient | — | — | ImageAnalysisClient | — |
| AI: Transcription | TranscriptionClient | — | — | — | — |
| AI: Voice Live | VoiceLiveClient | VoiceLiveClient | VoiceLiveClient | VoiceLiveClient/VoiceLiveAsyncClient | — |
| AI: ML (Azure ML) | MLClient | — | — | — | — |
| AI: Anomaly Detector | — | — | — | MultivariateClient | — |
| Agent Framework (Foundry agents) | AzureAIAgentClient via AzureAIAgentsProvider | — | — | — | — |
| Communication: Chat | — | — | — | ChatClient/CommunicationTokenCredential | — |
| Communication: SMS | — | — | — | SmsClient | — |
| Communication: Call Automation | — | — | — | CallAutomationClient | — |
| Communication: Calling Server (deprecated → Call Automation) | — | — | — | CallingServerClient | — |
| Communication: Common | — | — | — | CommunicationTokenCredential | — |
| Compute Batch | — | — | — | BatchClient | — |
| Functions (runtime, not a data-plane SDK) | v2 decorator model | v4 programming model | isolated worker model | — | — |
| Entra Authentication Events (Functions ext) | — | — | WebJobsAuthenticationEventsTrigger handlers | — | — |

¹ Python's `azure-keyvault` skill bundles Secrets/Keys/Certificates in one package;
.NET has no standalone "keyvault-secrets" skill in this group (only
`security-keyvault-keys`) — use `Azure.Security.KeyVault.Secrets` directly if needed.

## ARM / management-plane services

~19 of the 118 source skills are control-plane (ARM) SDKs, not data-plane clients. They
all follow one of two shapes and differ only by resource-provider namespace:

- **.NET**: `new ArmClient(new DefaultAzureCredential())`, then
  `armClient.GetDefaultSubscription().Get<Rp>Collection().CreateOrUpdate(...)` — every
  write is an LRO (`ArmOperation<T>`). Package = `Azure.ResourceManager.<Rp>`.
- **Python**: `<Rp>MgmtClient(credential, subscription_id)`, then
  `client.<resource>.begin_create_or_update(...).result()`. Package = `azure-mgmt-<rp>`.

Resource providers covered: API Center, API Management, Application Insights, Bot
Service, Fabric, Cosmos DB, Durable Task, MySQL, Playwright, PostgreSQL, Redis, SQL,
plus three partner/marketplace RPs (Arize AI Observability Eval, MongoDB Atlas, Weights
& Biases) that are .NET-only and thinner (fewer operations, CRUD on the RP resource
only — check the partner's own docs for data-plane APIs).

## Gotchas

- **Rust auth differs by design**: `DeveloperToolsCredential` (not `DefaultAzureCredential`)
  is CLI/azd-only — it will not pick up env-var or managed-identity credentials. Use
  `ManagedIdentityCredential` explicitly in Rust for production/Azure-hosted workloads.
- **TS "raw REST" clients** (content-safety, document-intelligence, translation) are
  generated from OpenAPI and have a different call shape (`client.path(...).post({...})`)
  than the hand-written high-level clients — don't assume the same method names as py/.NET.
- **Duplicate-looking skills**: `azure-cosmos-db-py` and `azure-cosmos-py` both target
  package `azure-cosmos`/`CosmosClient` but have substantially different bodies (not a
  clean duplicate) — worth a dedup pass upstream.
- **Form Recognizer → Document Intelligence rename**: Java still ships the old
  `DocumentAnalysisClient`/`azure-ai-formrecognizer` naming; .NET/TS already use
  `DocumentIntelligenceClient`. Don't mix the two in the same codebase.
- **Communication Services is Java-only** in this skill set — no py/ts/dotnet coverage
  exists upstream for chat/SMS/call-automation.
- **Never hardcode credentials**: always env vars or managed identity; reuse one
  credential instance across multiple clients (all 5 languages are thread-safe here);
  close async credentials explicitly (`await credential.close()` / `credential.Dispose()`).
- **Suggesters/vectorizers in Search** must be defined at index-creation time — cannot
  be added to an existing index.
- Several mgmt skills (`azure-mgmt-botservice-py`, `azure-mgmt-fabric-py`) have a blank
  `package:` in their source frontmatter — verify the actual PyPI name
  (`azure-mgmt-botservice`, `azure-mgmt-fabric`) before relying on it.
