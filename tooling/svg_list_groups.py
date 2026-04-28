import re
import sys
from pathlib import Path


def list_group_ids(svg_path: Path) -> list[str]:
    pat = re.compile(r'<g\s+[^>]*?id="([^"]+)"', re.IGNORECASE)
    ids: list[str] = []
    buf = ""
    with svg_path.open("r", encoding="utf-8", errors="ignore") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            data = buf + chunk
            ids.extend(m.group(1) for m in pat.finditer(data))
            buf = data[-200:]

    seen: set[str] = set()
    out: list[str] = []
    for x in ids:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python tooling/svg_list_groups.py images/map.svg")
        return 2
    svg_path = Path(sys.argv[1])
    txt = svg_path.read_text(encoding="utf-8", errors="ignore")
    ids = list_group_ids(svg_path)
    print("len_chars", len(txt))
    print("g_open", len(re.findall(r"<g\\b", txt, re.IGNORECASE)))
    print("g_close", len(re.findall(r"</g>", txt, re.IGNORECASE)))
    print("id_attr", len(re.findall(r'\\bid=\"', txt, re.IGNORECASE)))
    print()
    print("unique_group_ids", len(ids))
    for i, x in enumerate(ids, start=1):
        print(f"{i:03d} {x}")
    print()
    print("first_lines")
    for i, line in enumerate(txt.splitlines()[:40], start=1):
        print(f"{i:02d} {line[:200]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

