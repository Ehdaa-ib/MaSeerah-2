import re
import sys
from pathlib import Path


def region_class_pattern(n: int) -> re.Pattern:
    # mirrors the Dart token matcher: region_?N as a whole class token
    return re.compile(rf"(?:\s|^)region_?{n}(?:\s|$)", re.I)


def extract_enclosing_g(svg: str, region: int) -> str | None:
    token = region_class_pattern(region)
    m = re.search(r'<path\b[^>]*class="([^"]+)"[^>]*>', svg, flags=re.I)
    if not m:
        return None

    # find the first path tag that matches region token
    start = 0
    found_path_start = None
    for m2 in re.finditer(r'<path\b[^>]*class="([^"]+)"[^>]*>', svg, flags=re.I):
        cls = m2.group(1) or ""
        if token.search(cls):
            found_path_start = m2.start()
            break
    if found_path_start is None:
        return None

    g_start = svg.rfind("<g", 0, found_path_start)
    if g_start < 0:
        return None

    depth = 1
    first_end = svg.find(">", g_start)
    if first_end == -1:
        return None
    i = first_end + 1
    while i < len(svg):
        next_open = svg.find("<g", i)
        next_close = svg.find("</g", i)
        if next_close == -1:
            return None
        if next_open != -1 and next_open < next_close:
            depth += 1
            open_end = svg.find(">", next_open)
            if open_end == -1:
                return None
            i = open_end + 1
            continue
        depth -= 1
        close_end = svg.find(">", next_close)
        if close_end == -1:
            return None
        i = close_end + 1
        if depth == 0:
            return svg[g_start:i]
    return None


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: python tooling/svg_extract_region_group.py images/map.svg 5")
        return 2
    p = Path(sys.argv[1])
    region = int(sys.argv[2])
    svg = p.read_text(encoding="utf-8", errors="ignore")
    g = extract_enclosing_g(svg, region)
    print("found", bool(g))
    if not g:
        return 1
    print("len", len(g))
    print("paths", len(re.findall(r"<path\\b", g, flags=re.I)))
    print("contains_Vector_class", bool(re.search(r'class=\"[^\"]*Vector[^\"]*\"', g, flags=re.I)))
    print("first_400", g[:400].replace("\\n", " "))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

