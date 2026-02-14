#!/usr/bin/env python3
"""
Build a readable PDF from IOS系统开发.md.

Notes:
- We intentionally keep the Markdown parsing lightweight (headings, paragraphs,
  lists, blockquotes, code fences, horizontal rules, and simple pipe tables).
- We use ReportLab CID font (STSong-Light) for CJK text to avoid bundling fonts.
- We normalize Unicode dashes to ASCII '-' per the pdf skill guidelines.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable, List, Optional, Tuple

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import (
    HRFlowable,
    PageBreak,
    Paragraph,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from xml.sax.saxutils import escape as xml_escape


UNICODE_DASHES_RE = re.compile(r"[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]")


def normalize_dashes(text: str) -> str:
    # Enforce ASCII hyphens in the generated PDF output.
    return UNICODE_DASHES_RE.sub("-", text)


def _inline_md_to_rl_markup(text: str) -> str:
    """
    Convert a subset of inline Markdown to ReportLab Paragraph markup.

    Supported:
    - `inline code` -> Courier font
    - **bold** -> <b>...</b>
    """

    text = normalize_dashes(text)

    # Tokenize so we can XML-escape plain text, but keep tags we insert.
    out: List[str] = []
    i = 0
    while i < len(text):
        # Inline code: `...`
        if text[i] == "`":
            j = text.find("`", i + 1)
            if j == -1:
                out.append(xml_escape(text[i:]))
                break
            code = text[i + 1 : j]
            out.append(f'<font name="Courier">{xml_escape(code)}</font>')
            i = j + 1
            continue

        # Bold: **...**
        if text.startswith("**", i):
            j = text.find("**", i + 2)
            if j == -1:
                out.append(xml_escape(text[i:]))
                break
            bold = text[i + 2 : j]
            out.append(f"<b>{xml_escape(bold)}</b>")
            i = j + 2
            continue

        # Default: emit one char (we escape in chunks for speed)
        # Find next special token quickly.
        next_tick = text.find("`", i)
        next_bold = text.find("**", i)
        candidates = [p for p in (next_tick, next_bold) if p != -1]
        nxt = min(candidates) if candidates else -1
        if nxt == -1:
            out.append(xml_escape(text[i:]))
            break
        out.append(xml_escape(text[i:nxt]))
        i = nxt

    # ReportLab Paragraph uses <br/> for line breaks.
    return "".join(out).replace("\n", "<br/>")


HEADING_RE = re.compile(r"^(?P<hashes>#{1,6})\s+(?P<text>.*)$")
LIST_RE = re.compile(r"^(?P<indent>\s*)(?P<marker>(?:[-+*])|(?:\d+\.))\s+(?P<text>.*)$")
BLOCKQUOTE_RE = re.compile(r"^\s*>\s?(?P<text>.*)$")
HR_RE = re.compile(r"^\s*(?:---|\*\*\*|___)\s*$")
CODE_FENCE_RE = re.compile(r"^\s*```")
TABLE_ROW_RE = re.compile(r"^\s*\|.*\|\s*$")


def _is_table_sep_row(cells: List[str]) -> bool:
    # Markdown table separator row is something like: --- | :---: | ---:
    for c in cells:
        s = c.strip()
        if not s:
            return False
        if not re.fullmatch(r":?-{3,}:?", s):
            return False
    return True


def _parse_table_rows(lines: List[str]) -> List[List[str]]:
    rows: List[List[str]] = []
    for ln in lines:
        raw = ln.strip()
        if not raw.startswith("|"):
            continue
        # Split and drop leading/trailing empty items from pipe boundaries.
        parts = [p.strip() for p in raw.strip("|").split("|")]
        if _is_table_sep_row(parts):
            continue
        rows.append(parts)
    # Normalize row lengths (pad short rows)
    width = max((len(r) for r in rows), default=0)
    for r in rows:
        if len(r) < width:
            r.extend([""] * (width - len(r)))
    return rows


def _gather_until(lines: List[str], start: int, pred) -> Tuple[List[str], int]:
    buf: List[str] = []
    i = start
    while i < len(lines) and pred(lines[i]):
        buf.append(lines[i])
        i += 1
    return buf, i


def build_pdf(md_path: Path, out_pdf: Path) -> None:
    pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))

    styles = getSampleStyleSheet()
    base = ParagraphStyle(
        "BaseCJK",
        parent=styles["Normal"],
        fontName="STSong-Light",
        fontSize=10.5,
        leading=14,
        spaceAfter=6,
        wordWrap="CJK",
    )
    quote = ParagraphStyle(
        "QuoteCJK",
        parent=base,
        leftIndent=8 * mm,
        textColor=colors.HexColor("#444444"),
        backColor=colors.HexColor("#f7f7f7"),
        borderPadding=4,
    )
    code_style = ParagraphStyle(
        "Code",
        parent=base,
        fontName="Courier",
        fontSize=9,
        leading=11,
        leftIndent=6 * mm,
        backColor=colors.HexColor("#f4f4f4"),
    )
    h1 = ParagraphStyle("H1", parent=base, fontSize=18, leading=22, spaceAfter=10, spaceBefore=6)
    h2 = ParagraphStyle("H2", parent=base, fontSize=15, leading=19, spaceAfter=8, spaceBefore=10)
    h3 = ParagraphStyle("H3", parent=base, fontSize=13, leading=16, spaceAfter=6, spaceBefore=8)
    h4 = ParagraphStyle("H4", parent=base, fontSize=11.5, leading=14, spaceAfter=6, spaceBefore=6)

    def heading_style(level: int) -> ParagraphStyle:
        return {1: h1, 2: h2, 3: h3, 4: h4}.get(level, base)

    out_pdf.parent.mkdir(parents=True, exist_ok=True)

    doc = SimpleDocTemplate(
        str(out_pdf),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title=md_path.stem,
    )

    md_lines = md_path.read_text(encoding="utf-8").splitlines()
    story = []

    i = 0
    while i < len(md_lines):
        line = md_lines[i].rstrip("\n")

        if not line.strip():
            i += 1
            continue

        if CODE_FENCE_RE.match(line):
            # Code fence block
            code, j = _gather_until(md_lines, i + 1, lambda s: not CODE_FENCE_RE.match(s))
            # Skip closing fence if present
            i = j + 1 if j < len(md_lines) else j
            story.append(Preformatted(normalize_dashes("\n".join(code)), code_style))
            story.append(Spacer(1, 6))
            continue

        m = HEADING_RE.match(line)
        if m:
            level = len(m.group("hashes"))
            txt = m.group("text").strip()
            story.append(Paragraph(_inline_md_to_rl_markup(txt), heading_style(level)))
            story.append(Spacer(1, 4))
            i += 1
            continue

        if HR_RE.match(line):
            story.append(Spacer(1, 6))
            story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#cccccc")))
            story.append(Spacer(1, 6))
            i += 1
            continue

        if BLOCKQUOTE_RE.match(line):
            # Gather consecutive blockquote lines.
            qlines, j = _gather_until(md_lines, i, lambda s: bool(BLOCKQUOTE_RE.match(s)))
            qtxt = "\n".join(BLOCKQUOTE_RE.match(s).group("text") for s in qlines)  # type: ignore[union-attr]
            story.append(Paragraph(_inline_md_to_rl_markup(qtxt), quote))
            story.append(Spacer(1, 6))
            i = j
            continue

        if TABLE_ROW_RE.match(line):
            tbl_lines, j = _gather_until(md_lines, i, lambda s: bool(TABLE_ROW_RE.match(s)))
            rows = _parse_table_rows(tbl_lines)
            if rows:
                # Convert cells to Paragraphs for wrapping.
                table_cell_style = ParagraphStyle(
                    "TableCell",
                    parent=base,
                    fontSize=9.5,
                    leading=12,
                    spaceAfter=0,
                    spaceBefore=0,
                )
                data = [
                    [Paragraph(_inline_md_to_rl_markup(c), table_cell_style) for c in r] for r in rows
                ]
                ncols = len(rows[0])
                # Simple width distribution: last column gets more space for 3-col tables.
                usable_w = doc.width
                if ncols == 3:
                    col_widths = [usable_w * 0.22, usable_w * 0.22, usable_w * 0.56]
                else:
                    col_widths = [usable_w / ncols for _ in range(ncols)]

                t = Table(data, colWidths=col_widths, repeatRows=1)
                t.setStyle(
                    TableStyle(
                        [
                            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f0f0f0")),
                            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cccccc")),
                            ("VALIGN", (0, 0), (-1, -1), "TOP"),
                            ("LEFTPADDING", (0, 0), (-1, -1), 4),
                            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                            ("TOPPADDING", (0, 0), (-1, -1), 3),
                            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                        ]
                    )
                )
                story.append(t)
                story.append(Spacer(1, 10))
            i = j
            continue

        m = LIST_RE.match(line)
        if m:
            # Gather list items + continuation lines.
            items: List[Tuple[int, str, List[str]]] = []
            j = i
            while j < len(md_lines):
                ln = md_lines[j]
                if not ln.strip():
                    break
                m_list = LIST_RE.match(ln)
                if m_list:
                    indent_spaces = len(m_list.group("indent"))
                    marker = m_list.group("marker")
                    txt = m_list.group("text").rstrip()
                    items.append((indent_spaces, marker, [txt]))
                    j += 1
                    continue
                # Continuation line for previous list item (indented content)
                if items and (ln.startswith("  ") or ln.startswith("\t")):
                    items[-1][2].append(ln.strip())
                    j += 1
                    continue
                break

            for indent_spaces, marker, parts in items:
                indent_level = indent_spaces // 2
                left_indent = (6 + indent_level * 6) * mm
                li_style = ParagraphStyle(
                    "ListItem",
                    parent=base,
                    leftIndent=left_indent,
                    firstLineIndent=0,
                    spaceAfter=2,
                )
                txt = " ".join(p.strip() for p in parts if p.strip())
                story.append(Paragraph(_inline_md_to_rl_markup(f"{marker} {txt}"), li_style))
            story.append(Spacer(1, 6))
            i = j
            continue

        # Paragraph: gather until blank line or next block start.
        para_lines = [line]
        j = i + 1
        while j < len(md_lines):
            ln = md_lines[j]
            if not ln.strip():
                break
            if CODE_FENCE_RE.match(ln) or HEADING_RE.match(ln) or HR_RE.match(ln) or BLOCKQUOTE_RE.match(ln):
                break
            if TABLE_ROW_RE.match(ln) or LIST_RE.match(ln):
                break
            para_lines.append(ln.rstrip())
            j += 1

        ptxt = " ".join(s.strip() for s in para_lines if s.strip())
        story.append(Paragraph(_inline_md_to_rl_markup(ptxt), base))
        i = j

    def draw_footer(canvas, _doc):
        canvas.saveState()
        canvas.setFont("Helvetica", 9)
        canvas.setFillColor(colors.HexColor("#666666"))
        canvas.drawRightString(_doc.pagesize[0] - 18 * mm, 12 * mm, f"Page {_doc.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=draw_footer, onLaterPages=draw_footer)


if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parents[2]
    md = repo_root / "IOS系统开发.md"
    out = repo_root / "output" / "pdf" / "ios-system-dev-migration-checklist.pdf"
    build_pdf(md, out)
    print(out)
