#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, csv, os, sys, hashlib, zipfile, re, unicodedata, json
import datetime as dt

CATS = {"book":"📘 Книги","doc":"📄 Документи","video":"🎥 Відео","concept":"🧭 Концепти"}

ROOT   = r"C:\CHECHA_CORE"
C12    = os.path.join(ROOT, "C12")
C03LOG = os.path.join(ROOT, "C03", "LOG.md")
C05ARC = os.path.join(ROOT, "C05", "ARCHIVE.md")
ZIPDIR = os.path.join(ROOT, "C05", "Archive")
C09KPI = os.path.join(ROOT, "C09", "KPI.md")
LOCK   = os.path.join(ROOT, "C11", ".vault_bot.lock")

def ensure(path, default=""):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as f: f.write(default)

def read_text_guess(path):
    for enc in ("utf-8","utf-8-sig","utf-16","utf-16-le","utf-16-be","cp1251","cp1252"):
        try:
            with open(path,"r",encoding=enc) as f: return f.read()
        except UnicodeDecodeError: continue
    with open(path,"rb") as f: return f.read().decode("utf-8","replace")

def normalize_text(s): return unicodedata.normalize("NFKC", (s or "")).strip().lower()

def sanitize_md(s):
    s = s.replace("\\","\\\\")
    for ch, rep in [("[","\\["),("]","\\]"),("(","\\("),(")","\\)"),("*","\\*"),("_","\\_")]:
        s = s.replace(ch, rep)
    return s

def extract_existing(content):
    # map: title_norm -> link_norm ('' if none)
    m = {}
    for line in content.splitlines():
        m1 = re.match(r'^\s*-\s+\*\*(.+?)\*\*\s+—\s+(.*)$', line)
        if m1:
            title = normalize_text(m1.group(1))
            link = ""
            m2 = re.search(r'\(\[линк\]\((.*?)\)\)', line)
            if m2: link = normalize_text(m2.group(1))
            if title not in m or (m[title]=="" and link!=""):
                m[title] = link
    return m

def replace_bullet_if_no_link(content, title, new_line):
    # якщо є маркер з тим самим title і без ([линк](…)) — замінюємо перший
    lines = content.splitlines()
    title_pat = re.escape(title)
    for i, line in enumerate(lines):
        if re.search(r'^\s*-\s+\*\*' + title_pat + r'\*\*\s+—\s+.*$', line) and '([линк](' not in line:
            lines[i] = new_line
            return "\n".join(lines), True
    return content, False

def count_by_sections(content):
    counts = {k:0 for k in CATS.keys()}
    current = None
    for line in content.splitlines():
        if line.strip() == f"## {CATS['book']}": current='book'; continue
        if line.strip() == f"## {CATS['doc']}": current='doc'; continue
        if line.strip() == f"## {CATS['video']}": current='video'; continue
        if line.strip() == f"## {CATS['concept']}": current='concept'; continue
        if current and re.match(r'^\s*-\s+\*\*', line): counts[current]+=1
    return counts, sum(counts.values())

def insert_after_section(content, section_title, lines_to_add):
    if not lines_to_add: return content
    lines = content.splitlines()
    heading = f"## {section_title}"
    idxs = [i for i,l in enumerate(lines) if l.strip()==heading]
    if not idxs:
        if lines and lines[-1].strip()!="": lines.append("")
        lines.append(heading); lines.append("")
        idxs=[len(lines)-2]
    i = idxs[-1] + 1
    while i < len(lines) and lines[i].strip()=="":
        i += 1
    block = [""] + lines_to_add + [""]
    lines[i:i] = block
    return "\n".join(lines)

def sha256(p):
    h=hashlib.sha256()
    with open(p,"rb") as f:
        for ch in iter(lambda:f.read(8192), b""): h.update(ch)
    return h.hexdigest()

def main():
    # --- lock ---
    try:
        fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(fd, str(os.getpid()).encode("utf-8")); os.close(fd)
    except FileExistsError:
        print("SKIP: another run is active (lock exists)."); sys.exit(0)

    try:
        ap=argparse.ArgumentParser()
        ap.add_argument("--items", required=True)
        ap.add_argument("--zip", action="store_true")
        ap.add_argument("--items-clear", action="store_true")
        ap.add_argument("--release", default="auto")
        ap.add_argument("--release-prefix", default="v2.3")
        args=ap.parse_args()

        # load items CSV (BOM-safe) + normalize keys
        items=[]
        with open(args.items, newline="", encoding="utf-8-sig") as f:
            rdr = csv.DictReader(f)
            for row in rdr:
                norm = { (k or "").lstrip("\ufeff").strip().lower(): (v or "").strip()
                         for k,v in row.items() }
                items.append(norm)

        # validate items
        valid=[]; errors=[]
        for r in items:
            cat = (r.get("category") or "").lower()
            title = r.get("title") or ""
            brief = r.get("brief") or ""
            link  = r.get("link")  or ""
            if cat not in CATS or not title or not brief:
                errors.append(r); continue
            valid.append({"category":cat, "title":title, "brief":brief, "link":link})

        # index
        index_path = os.path.join(C12, "INDEX.md")
        ensure(index_path, "# INDEX — v2.1 FirstBuild\n\n## 📘 Книги\n## 📄 Документи\n## 🎥 Відео\n## 🧭 Концепти\n")
        content = read_text_guess(index_path)
        existing_map = extract_existing(content)

        # prepare additions per category with sanitization
        added = 0; replaced = 0
        to_add = {k:[] for k in CATS.keys()}
        for r in valid:
            title = r["title"].strip()
            brief = r["brief"].strip()
            link  = r["link"].strip()
            key_t = normalize_text(title)
            key_l = normalize_text(link)

            line = f"- **{sanitize_md(title)}** — {sanitize_md(brief)}"
            if link:
                # безпечні посилання тільки http(s)
                if re.match(r'(?i)^\s*(https?://)', link):
                    line += f" ([линк]({link}))"
                else:
                    # якщо лінк «небезпечний» — ігноруємо його
                    key_l = ""; link = ""

            # дубль?
            if key_t in existing_map and (existing_map[key_t]==key_l or (existing_map[key_t]!="" and key_l=="")):
                continue
            # якщо в індексі був той самий title без лінка, а зараз є лінк — пробуємо замінити рядок
            if key_t in existing_map and existing_map[key_t]=="" and key_l!="":
                content, did = replace_bullet_if_no_link(content, sanitize_md(title), line)
                if did:
                    replaced += 1
                    existing_map[key_t] = key_l
                    continue
            # інакше додамо в свою секцію
            to_add[r["category"]].append(line)
            existing_map[key_t] = key_l
            added += 1

        # вмонтувати нові рядки в секції
        for k, lines in to_add.items():
            content = insert_after_section(content, CATS[k], lines)

        with open(index_path,"w",encoding="utf-8") as f: f.write(content)

        # KPI (рахуємо вже по фінальному контенту)
        counts, total = count_by_sections(content)
        ensure(C09KPI, "| date | total | book | doc | video | concept |\n|---|---:|---:|---:|---:|---:|\n")
        today = dt.date.today().isoformat()
        with open(C09KPI, "a", encoding="utf-8") as f:
            f.write(f"| {today} | {total} | {counts['book']} | {counts['doc']} | {counts['video']} | {counts['concept']} |\n")

        # ZIP (optional)
        rel = args.release
        if rel=="auto":
            rel = f"{args.release_prefix}.{dt.datetime.now().strftime('%Y.%m.%d_%H%M%S')}"
        rel_tag = f"C12_{rel}"
        sha = "-"
        if args.zip:
            os.makedirs(ZIPDIR, exist_ok=True)
            zip_path = os.path.join(ZIPDIR, f"{rel_tag}_ReleaseBundle.zip")
            with zipfile.ZipFile(zip_path,"w",zipfile.ZIP_DEFLATED) as z:
                for name in ("README.md","INDEX.md","C12-FLOW.md"):
                    p = os.path.join(C12, name)
                    if os.path.exists(p): z.write(p, arcname=name)
                manifest = {
                    "release": rel_tag,
                    "created_at": dt.datetime.now().isoformat(timespec="seconds"),
                    "files": ["README.md","INDEX.md","C12-FLOW.md"],
                    "counts": counts, "total": total
                }
                z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
            sha = sha256(zip_path)
            with open(zip_path + ".sha256","w",encoding="utf-8") as f:
                f.write(f"{sha}  {os.path.basename(zip_path)}\n")

        # LOG + ARCHIVE рядок
        ensure(C03LOG, "# C03 — LOG\n\n| Дата | Реліз | Статус | Хеш (SHA256) |\n|---|---|---|---|\n")
        ensure(C05ARC, "# C05 — Archive\n\n| Дата | Реліз | Опис | SHA256 |\n|---|---|---|---|\n")
        row = f"| {dt.date.today().isoformat()} | {rel_tag}_ReleaseBundle | ✅ AutoUpdate ({added} items, {replaced} replaced) | {sha} |"
        with open(C03LOG,"a",encoding="utf-8") as f: f.write(row+"\n")
        with open(C05ARC,"a",encoding="utf-8") as f: f.write(row+"\n")

        # очистити items.csv (якщо треба)
        if args.items_clear:
            with open(args.items,"w",encoding="utf-8") as f:
                f.write("category,title,link,brief\n")

        print("OK:", {"release": rel_tag, "added": added, "replaced": replaced, "sha256": sha, "kpi_total": total})

    finally:
        try: os.remove(LOCK)
        except FileNotFoundError: pass

if __name__=="__main__":
    main()


