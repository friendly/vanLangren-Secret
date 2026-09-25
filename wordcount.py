"""Word count of the rendered .docx, by section and by category.

Usage:  python wordcount.py [file.docx]     (default: vanLangren-Secret.docx)
        Render the .docx first; needs `quarto` on the PATH.

Counts what the editor actually receives, not the .qmd source, so YAML,
R chunks, URLs, image paths and HTML-only content never enter the count.
Words are counted the way Word does: whitespace-separated tokens
(so 'anyway—but' is one word), ignoring tokens with no letters/digits.

Each word is assigned to one category, using the docx paragraph styles:
  body            running prose, block quotes, lists
  headings        section and step headings
  pull quotes     PullQuote style
  footnotes       footnote text
  figure captions captions of figures (figures sit in layout tables)
  tables          data tables and their captions
  display blocks  Source Code blocks (cipher excerpt, decoded French)
  math            inline and display equations
  references      the bibliography
"""
import json, re, subprocess, sys, collections

sys.stdout.reconfigure(encoding="utf-8")

docx = sys.argv[1] if len(sys.argv) > 1 else "vanLangren-Secret.docx"
ast = json.loads(subprocess.run(
    ["quarto", "pandoc", docx, "-f", "docx+styles", "-t", "json"],
    capture_output=True, check=True).stdout)

counts = collections.defaultdict(collections.Counter)   # section -> category -> words
section = "(opening)"

def words(text):
    return sum(1 for t in text.split() if re.search(r"\w", t))

def text_of(x, cat, out):
    """Collect inline text into out[cat]; divert notes and math."""
    if isinstance(x, list):
        for y in x: text_of(y, cat, out)
        return
    if not isinstance(x, dict):
        return
    t = x.get("t")
    if t == "Str":   out[cat].append(x["c"])
    elif t in ("Space", "SoftBreak", "LineBreak"): out[cat].append(" ")
    elif t == "Math":  out["math"].append(" " + x["c"][1] + " ")
    elif t == "Note":  text_of(x["c"], "footnotes", out); out[cat].append(" ")
    elif t == "Code":  out[cat].append(x["c"][1])
    elif t in ("Para", "Plain", "Header", "LineBlock"):
        # paragraph-level elements (e.g. table cells, list items) end a word
        text_of(x["c"], cat, out); out[cat].append(" ")
    else:
        c = x.get("c")
        if c is not None: text_of(c, cat, out)

def has_image(x):
    return '"t": "Image"' in json.dumps(x)

def block(b, cat):
    global section
    t = b["t"]
    if t == "Header":
        if b["c"][0] <= 2:
            section = "".join(s["c"] if s["t"] == "Str" else " "
                              for s in b["c"][2] if s["t"] in ("Str", "Space"))
        cat = "headings"
    elif t == "Div":
        style = dict(b["c"][0][2]).get("custom-style", "")
        cat = {"Source Code": "display blocks", "Bibliography": "references",
               "PullQuote": "pull quotes", "Table Caption": "tables",
               "Footnote Text": "footnotes"}.get(style, cat)
        for bb in b["c"][1]: block(bb, cat)
        return
    elif t == "Table":
        cat = "figure captions" if has_image(b) else "tables"
    elif t == "CodeBlock":
        counts[section]["display blocks"] += words(b["c"][1])
        return
    out = collections.defaultdict(list)
    text_of(b["c"], cat, out)
    for k, v in out.items():
        counts[section][k] += words("".join(v))

for b in ast["blocks"]:
    block(b, "body")

cats = ["body", "headings", "pull quotes", "footnotes", "figure captions",
        "tables", "display blocks", "math", "references"]
tot = collections.Counter()
print(f"{'section':32s}" + "".join(f"{c[:8]:>9s}" for c in cats))
for sec, cc in counts.items():
    tot.update(cc)
    print(f"{sec[:32]:32s}" + "".join(f"{cc[c]:9d}" for c in cats))
print(f"{'TOTAL':32s}" + "".join(f"{tot[c]:9d}" for c in cats))
core = tot["body"] + tot["headings"] + tot["pull quotes"]
print(f"\nBody text (prose + headings + pull quotes): {core}")
print(f"  + footnotes:                               {core + tot['footnotes']}")
print(f"  + captions & tables:                       {core + tot['footnotes'] + tot['figure captions'] + tot['tables']}")
print(f"Everything Word would count (all of the above + display, math, refs): {sum(tot.values())}")
