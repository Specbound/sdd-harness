---
name: langchain-architecture
description: "Build LLM apps with modern LangChain — LCEL, LangGraph agents, retrievers, persistent state. Use when writing or reviewing LangChain code, porting pre-0.1 code off removed APIs (initialize_agent, ConversationBufferMemory, chain.run), or choosing LCEL vs LangGraph vs a plain SDK call."
risk: unknown
source: community
---

# LangChain Architecture

LangChain split into `langchain-core`, provider packages (`langchain-openai`, …),
`langchain-community`, and `langgraph`. Most LangChain code on the public internet —
and most of what a model recalls by default — predates that split and calls APIs that
were deprecated in 0.1 and removed since. Writing it produces an `ImportError`, not a
subtly worse app.

## Use this skill when

- Writing or reviewing LangChain code
- Porting pre-0.1 LangChain off removed APIs
- Building an agent with tools, or a RAG pipeline
- Deciding whether LangChain earns its dependency at all

## First: does this need LangChain?

Reach for the provider SDK directly when the task is one prompt, one call, one parse.
LangChain pays off when you need **swappable providers**, **retrieval plumbing**, or
**durable multi-step state**. A single `client.chat.completions.create(...)` wrapped in
LCEL is a dependency with no return.

| Need | Use |
|---|---|
| One prompt → one answer | Provider SDK directly |
| Composable prompt→model→parse, streaming, batching | LCEL |
| Tool-calling loop, branching, human-in-the-loop, resumable state | LangGraph |
| Document ingest → chunk → embed → retrieve | LangChain retrievers + a vector store |

## Removed-API migration table

This is the highest-value part of this skill. Each left-hand entry is code a model will
emit from memory and that no longer imports.

| Pre-0.1 (gone) | Current |
|---|---|
| `from langchain.llms import OpenAI` | `from langchain_openai import ChatOpenAI` |
| `initialize_agent(...)`, `AgentType.*` | `create_react_agent` from `langgraph.prebuilt` |
| `chain.run(x)` / `agent.run(x)` | `.invoke(x)` (also `.stream`, `.batch`, `.ainvoke`) |
| `LLMChain(llm=..., prompt=...)` | `prompt \| llm \| parser` (LCEL) |
| `SequentialChain`, `SimpleSequentialChain` | LCEL pipe, or a LangGraph graph if it branches |
| `ConversationBufferMemory` and the `Memory` classes | LangGraph checkpointer, or `RunnableWithMessageHistory` |
| `from langchain.embeddings import OpenAIEmbeddings` | `from langchain_openai import OpenAIEmbeddings` |
| `from langchain.vectorstores import Chroma` | `from langchain_chroma import Chroma` |

Rule of thumb for any import: if it is `from langchain.<something> import <Provider>`,
the provider moved to its own package. `langchain-community` holds the long tail.

## LCEL — composition

```python
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

llm = ChatOpenAI(model="gpt-4o", temperature=0)
prompt = ChatPromptTemplate.from_messages([
    ("system", "Summarize in one sentence."),
    ("human", "{text}"),
])

chain = prompt | llm | StrOutputParser()

chain.invoke({"text": "..."})          # single
chain.batch([{"text": "a"}, {"text": "b"}])   # parallel
for tok in chain.stream({"text": "..."}):     # token stream
    print(tok, end="")
```

Everything in a pipe is a `Runnable` and shares that interface. Structured output goes
through the model, not a parser bolted on after:

```python
from pydantic import BaseModel, Field

class Entity(BaseModel):
    name: str = Field(description="entity name")
    kind: str

structured = llm.with_structured_output(Entity)
structured.invoke("Ada Lovelace was a mathematician.")   # -> Entity(...)
```

Prefer `with_structured_output` over asking for JSON in the prompt and parsing the
string — it uses the provider's native tool/JSON-schema mode and removes a class of
parse failures entirely.

## LangGraph — agents and state

`initialize_agent` is gone; the prebuilt ReAct agent replaces it directly.

```python
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import InMemorySaver

@tool
def search_orders(customer_id: str) -> str:
    """Look up a customer's recent orders. Use for order status questions."""
    return db.query(customer_id)

agent = create_react_agent(
    model=ChatOpenAI(model="gpt-4o"),
    tools=[search_orders],
    checkpointer=InMemorySaver(),      # this is "memory" now
)

config = {"configurable": {"thread_id": "customer-42"}}
agent.invoke({"messages": [("user", "Where is my order?")]}, config)
agent.invoke({"messages": [("user", "And the one before that?")]}, config)
```

The checkpointer, keyed by `thread_id`, is what the old `Memory` classes did — and it
persists the whole graph state, not just a transcript. Swap `InMemorySaver` for a
Postgres/SQLite saver and conversations survive a restart.

The `@tool` docstring is the tool description the model selects on. A vague docstring is
the most common cause of an agent that will not call the tool it needs.

Drop to an explicit `StateGraph` when you need branching, retries, parallel fan-out, or
a human approval step; `create_react_agent` only covers the single tool-calling loop.

## RAG

```python
from langchain_openai import OpenAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma

chunks = RecursiveCharacterTextSplitter(
    chunk_size=1000, chunk_overlap=200
).split_documents(docs)

store = Chroma.from_documents(chunks, OpenAIEmbeddings(model="text-embedding-3-small"))
retriever = store.as_retriever(search_kwargs={"k": 4})

rag = (
    {"context": retriever | (lambda ds: "\n\n".join(d.page_content for d in ds)),
     "question": lambda x: x}
    | ChatPromptTemplate.from_template(
        "Answer using only the context. Say you don't know if it isn't there.\n\n"
        "{context}\n\nQ: {question}")
    | llm
    | StrOutputParser()
)
rag.invoke("What is the refund window?")
```

Retrieval quality dominates generation quality here. Before tuning the prompt, check
what the retriever actually returned — `retriever.invoke(q)` — because most bad RAG
answers are retrieval misses, not generation failures.

## Failure modes

- **Pinning `langchain` only.** The meta-package does not pull every provider. Pin each
  package you import (`langchain-core`, `langchain-openai`, `langgraph`) — they version
  independently and a mismatched `langchain-core` is a common break.
- **Treating deprecation warnings as noise.** In this library they are removal notices
  with a lead time, not style advice.
- **Agent when a chain would do.** A tool-calling loop is nondeterministic and costs
  several calls per turn. If the step order is known, write the pipe.
- **Unbounded message history.** The checkpointer grows forever by default. Trim or
  summarize before the context window, not after it errors.
- **Debugging by print.** Set `LANGCHAIN_TRACING_V2=true` and read the trace; the
  intermediate prompt is usually not what you assume.
