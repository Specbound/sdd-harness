---
name: document-parsing
description: Parse PDF/DOCX/XLSX/PPTX/images locally with liteparse for RAG ingestion, agent vision workflows, or structured data extraction. Invoke before building any RAG pipeline or processing documents.
metadata:
  type: skill
  triggers:
    - parsing or extracting text from documents
    - building RAG pipelines
    - document ingestion
    - PDF extraction
    - batch document processing
    - screenshot generation for vision models
---

# Document Parsing with LiteParse

## When to Activate

- Any document (PDF, DOCX, XLSX, PPTX, image) needs to become text or JSON
- **Building a RAG pipeline** — invoke this before `rag-implementation`
- Generating page screenshots for vision model workflows
- Batch-processing a directory of documents
- Need spatial output (JSON with bounding boxes) for table extraction

## When NOT to Use

- Dense multi-column layouts, charts, handwriting, or pure-scan PDFs with low OCR quality → use LlamaParse cloud
- Creating/generating documents → `pdf-official`, `docx-official`, `xlsx-official`

---

## Phase 1: Install

```bash
# Python (recommended for agentic workflows)
pip install liteparse

# Node.js / CLI
npm i @llamaindex/liteparse       # includes `lit` CLI

# Rust CLI only
cargo install liteparse

# Browser (WASM — text extraction only, no OCR)
npm i @llamaindex/liteparse-wasm
```

Prerequisites for non-PDF formats:
- **DOCX / XLSX / PPTX / ODP**: `sudo apt install libreoffice` | `brew install libreoffice`
- **Images (JPG/PNG/TIFF/WEBP/SVG)**: `sudo apt install imagemagick` | `brew install imagemagick`

---

## Phase 2: Choose Output Format

| Goal | Format | When |
|------|--------|------|
| RAG ingestion (plain text chunks) | `text` (default) | Feeding embedding model |
| Table / layout extraction | `json` | Need bounding boxes or column detection |
| Vision model input | screenshot | Passing page images to multimodal model |

---

## Phase 3: CLI Patterns

```bash
# Parse single document → text (stdout)
lit parse document.pdf

# JSON output with bounding boxes
lit parse document.pdf --format json

# Specific pages only
lit parse document.pdf --target-pages "1-5,10"

# Disable OCR (faster, text-layer PDFs only)
lit parse document.pdf --no-ocr

# Password-protected PDF
lit parse document.pdf --password secret

# Batch process directory → output dir
lit batch-parse ./docs/ ./output/

# Generate page screenshots at 150 DPI
lit screenshot document.pdf -o ./screenshots/ --dpi 150
```

---

## Phase 4: Python API (agentic / RAG workflows)

```python
import liteparse

# Parse to plain text — ready for chunking
result = liteparse.parse("document.pdf")
text = result.text                         # full document as string

# Parse to JSON with spatial layout
result = liteparse.parse("document.pdf", format="json")
for page in result.pages:
    for block in page.blocks:
        print(block.text, block.bbox)      # bbox: [x1, y1, x2, y2]

# Screenshot pages for vision model
screenshots = liteparse.screenshot("document.pdf", dpi=150)
for i, img_bytes in enumerate(screenshots):
    with open(f"page_{i}.png", "wb") as f:
        f.write(img_bytes)

# Custom OCR server (EasyOCR, PaddleOCR, or custom)
result = liteparse.parse("scan.pdf", ocr_server_url="http://localhost:8000")
```

OCR server contract — `POST /ocr` must return:
```json
{ "results": [{ "text": "...", "bbox": [x1, y1, x2, y2], "confidence": 0.98 }] }
```

---

## Phase 5: RAG Handoff

After parsing, hand off to `rag-implementation`:

```python
import liteparse
# from your_rag_pipeline import chunk, embed, upsert

raw_text = liteparse.parse("document.pdf").text
# chunk → embed → upsert using rag-implementation patterns
```

Chunking strategy by output type:
- **Text output** → fixed-size chunking (512 tokens, 64 overlap) — simple, works for prose
- **JSON output** → chunk by `block.text`, carry `block.bbox` as metadata for spatial filtering
- **Scanned PDFs** → always enable OCR; bundled Tesseract preferred over HTTP server (lower latency, no network call)

---

## Phase 6: When to Escalate to Cloud (LlamaParse)

Switch to [LlamaParse](https://cloud.llamaindex.ai) when:
- Multi-column layout reconstruction is incorrect
- Dense financial / scientific tables are mangled
- Handwritten text present
- Tesseract OCR accuracy insufficient for purely-scanned PDFs
