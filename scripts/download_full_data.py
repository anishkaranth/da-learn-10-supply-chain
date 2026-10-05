#!/usr/bin/env python3
"""Download the full DataCo Smart Supply Chain dataset into data/raw_full/ (UTF-8, LF) and verify SHA-256.

Source  : Constante, Fabian; Silva, Fernando; Pereira, Antonio (2019), "DataCo SMART SUPPLY CHAIN FOR BIG DATA ANALYSIS",
          Mendeley Data, V5, doi:10.17632/8gx2fvg2k6.5  (https://data.mendeley.com/datasets/8gx2fvg2k6/5)
Kaggle  : https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis (same files)
Licence : CC BY 4.0 (Mendeley Data record)

1. Try the Mendeley original (Windows-1252, CRLF) and check its published SHA-256.
2. If Mendeley fails (its file server returns intermittent 502 / JSON error bodies), fall back to a GitHub mirror whose
   bytes equal the original with CRLF -> LF (checked: identical after line-ending normalisation).
Either way the pipeline reads data/raw_full/<name> = original decoded as cp1252, LF line endings, written as UTF-8, and
that output is checked against OUT_SHA so both routes give the same bytes. Originals are kept in data/orig/ (gitignored).
tokenized_access_logs.csv (95 MB web access logs, same Mendeley record) is not used here.
"""
import hashlib, pathlib, time, urllib.request

MENDELEY = "https://data.mendeley.com/public-files/datasets/8gx2fvg2k6/files/{fid}/file_downloaded"
MIRROR = "https://raw.githubusercontent.com/McGill-MMA-EnterpriseAnalytics/DataCo_Supply_Chain/main/data/raw/{name}"
FILES = {  # name: (mendeley file id, sha256 mendeley original, sha256 github mirror, sha256 utf-8 output)
    "DataCoSupplyChainDataset.csv": ("72784be5-36d3-44fe-b75d-0edbf1999f65",
        "fa6d022ed437155e1a2f0378710602848703c8a7f203f7ff5d77805bf8480aa6",
        "994b3c8d24049cc46bf20e8161fedece9a9b95376cc0dc929921d76cf6b9bc0d", None),
    "DescriptionDataCoSupplyChain.csv": ("29dc7b05-dda6-4834-8354-5b5cc44430df",
        "9828e34669bd6d77e3b4463364cc44a5d52446b5e246fc258758cfe592566c4b",
        "1812b786861128b67c88dd979379b124915b43da099e0617a34c11d4daea03b7", None),
}
OUT_SHA = {}  # filled below from the committed checksum file
root = pathlib.Path(__file__).resolve().parents[1]
orig, out = root / "data" / "orig", root / "data" / "raw_full"
orig.mkdir(parents=True, exist_ok=True); out.mkdir(parents=True, exist_ok=True)
sums = root / "data" / "raw_full.sha256"
if sums.exists():
    OUT_SHA = dict(line.split()[::-1] for line in sums.read_text().splitlines() if line.strip())


def fetch(url, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "curl/8.5.0"})  # default urllib agent gets 403
            with urllib.request.urlopen(req, timeout=600) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            print(f"  attempt {i + 1} failed: {e}")
            time.sleep(3 * (i + 1))
    return b""


ok = True
for name, (fid, sha_m, sha_g, _) in FILES.items():
    cached = orig / name
    raw = cached.read_bytes() if cached.exists() else b""
    if hashlib.sha256(raw).hexdigest() not in (sha_m, sha_g):
        print("downloading", name, "from Mendeley")
        raw = fetch(MENDELEY.format(fid=fid))
        if hashlib.sha256(raw).hexdigest() != sha_m:
            print("  Mendeley copy missing or wrong checksum -> GitHub mirror")
            raw = fetch(MIRROR.format(name=name))
        cached.write_bytes(raw)
    got = hashlib.sha256(raw).hexdigest()
    route = "mendeley" if got == sha_m else "github-mirror" if got == sha_g else None
    text = raw.decode("cp1252").replace("\r\n", "\n")
    (out / name).write_text(text, encoding="utf-8", newline="")
    out_sha = hashlib.sha256((out / name).read_bytes()).hexdigest()
    good = route is not None and OUT_SHA.get(name, out_sha) == out_sha
    ok &= good
    print(f"{name}: {len(raw):,d} source bytes via {route or 'NONE (checksum mismatch ' + got + ')'}; "
          f"data/raw_full/{name} {(out / name).stat().st_size:,d} B UTF-8 sha256 {out_sha} {'OK' if good else 'MISMATCH'}")
raise SystemExit(0 if ok else 1)
