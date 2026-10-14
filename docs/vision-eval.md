# Measuring AI tagging accuracy

`make eval-vision` runs a vision provider over a folder of labelled photos and prints per-field accuracy, a confusion
summary, whether confidence is trustworthy, token use and cost. Photos go through the **same image pipeline as a real upload**
(validate, rotate, strip metadata, resize) before reaching the provider, so the numbers describe what users would get.

## Targets (the command exits 1 when one is missed)

| Field | Target |
|---|---|
| category | 92% or better |
| primary colour | 85% or better |
| formality within 1 point | 80% or better |

Also reported, no target: subcategory, secondary colour (incl. "none"), pattern, formality (exact), seasons (exact set), fit, material.

## Free run on the bundled data (no account, no network)

```bash
make eval-vision
```

Uses `eval/sample_dataset/`: 50 tiny synthetic images (flat colour shapes) with labels. The **fake** provider reads hints from the file
names, so it scores high by construction (category 98%, colour 96%, formality within 1 at 100%) and the last two images are deliberately
anonymous to show a mistake table. This proves the harness, not the AI. Regenerate it with `python3 eval/make_sample_dataset.py`.

## Running it on your 300 labelled photos

1. Put the photos in one folder, for example `~/closet-eval/`. JPEG, PNG, WebP or HEIC.
2. Label them in a spreadsheet and export CSV with these columns (use the ids from `taxonomy/garment_taxonomy.v1.json`):

   `file,category,subcategory,primary_color,secondary_color,pattern,formality,seasons,fit,material`

   * `seasons` separated by `|` (`spring|summer`); leave `secondary_color`, `fit`, `material` empty when none.
   * `formality` is 1 (lounge) to 5 (formal). Label what a person would say, not what the tag says.
3. Convert and validate (typos in ids are caught here with the row number):

   ```bash
   cd api && . .venv/bin/activate
   python -m app.eval.labels_csv ~/closet-eval/labels.csv > ~/closet-eval/labels.json
   ```

4. Try a few photos first. **This sends your photos to Anthropic and costs money**, so the tool refuses to call the API unless
   you pass `--yes`:

   ```bash
   export ANTHROPIC_API_KEY=...        # never commit it; it is only read from the environment
   make eval-vision DATASET=~/closet-eval PROVIDER=claude EVAL_ARGS="--yes --limit 20"
   ```

5. Then the full run: `make eval-vision DATASET=~/closet-eval PROVIDER=claude EVAL_ARGS="--yes --json report.json"`.
   300 photos at the default settings is a few dollars; the report prints the exact cost per 1000 photos. The price table is in
   `api/app/vision/claude.py` (copied 2026-10-06); unknown models report "unknown" instead of guessing.

## Reading the report

* **Accuracy table**: per field, with `n` (some fields are optional).
* **Most common mistakes**: label -> predicted. Fix the prompt (`api/app/domain/taxonomy.py::prompt_guide`) or the label if the label was wrong.
* **Confidence check**: high-confidence answers should be right far more often than low-confidence ones; the app highlights answers under 0.7 for review.
* **Tokens / cost / latency** per call, p50 and p95.

## Using real corrections as extra data

Every correction in the app is stored (`garment_corrections`: field, AI value, user value, taxonomy version). That table is the cheapest
source of new labelled examples later; export it and turn it into a dataset with the same CSV converter.

## Safety

The Claude provider is **unverified** until you run step 4 with a real key. Nothing in CI or the tests calls the network: the adapter is covered
by `api/tests/unit/test_claude_provider.py` against a recorded-shape fake client.
