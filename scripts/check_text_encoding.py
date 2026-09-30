from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent

SCAN_ROOTS = [
    ROOT / "lib",
    ROOT / "web",
]

EXTENSIONS = {
    ".dart",
    ".html",
    ".js",
    ".json",
    ".yaml",
    ".yml",
    ".md",
}

# Mojibake real expresado mediante Unicode escapes.
# Nunca contiene signos ? usados por Dart.
MOJIBAKE = [
    "\u00c3\u00a1",  # ??
    "\u00c3\u00a9",  # ??
    "\u00c3\u00ad",  # ??
    "\u00c3\u00b3",  # ??
    "\u00c3\u00ba",  # ??
    "\u00c3\u00b1",  # ??
    "\u00c3\u0081",
    "\u00c3\u0089",
    "\u00c3\u008d",
    "\u00c3\u0093",
    "\u00c3\u009a",
    "\u00c3\u0091",
    "\u00c2\u00bf",  # ??
    "\u00c2\u00a1",  # ??
    "\u00c2\u00b7",  # ??
]

# Solo palabras humanas conocidas.
# No se usa el patron generico letra?letra.
SUSPICIOUS = [
    re.compile(r"\bdise\?o\b", re.I),
    re.compile(r"\bpeque\?a\b", re.I),
    re.compile(r"\bubicaci\?n\b", re.I),
    re.compile(r"\bcategor\?a\b", re.I),
    re.compile(r"\bcategor\?as\b", re.I),
    re.compile(r"\bsesi\?n\b", re.I),
    re.compile(r"\bgastronom\?a\b", re.I),
    re.compile(r"\bcomputaci\?n\b", re.I),
    re.compile(r"\bmec\?nica\b", re.I),
    re.compile(r"\bjardiner\?a\b", re.I),
    re.compile(r"\bcerrajer\?a\b", re.I),
    re.compile(r"\benerg\?a\b", re.I),
    re.compile(r"\balba\?iler", re.I),
    re.compile(r"\binformaci\?n\b", re.I),
    re.compile(r"\bpublicaci\?n\b", re.I),
    re.compile(r"\bfotograf\?a\b", re.I),
    re.compile(r"\bnotificaci\?n\b", re.I),
    re.compile(r"\bcontrase\?a\b", re.I),
    re.compile(r"\bm\?s\b", re.I),
]

invalid_utf8 = []
confirmed = []
warnings = []

for base in SCAN_ROOTS:

    if not base.exists():
        continue

    for path in base.rglob("*"):

        if (
            not path.is_file()
            or path.suffix.lower()
            not in EXTENSIONS
        ):
            continue

        try:
            raw = path.read_bytes()

            text = raw.decode(
                "utf-8",
                errors="strict",
            )

        except UnicodeDecodeError as exc:
            invalid_utf8.append(
                f"{path}:{exc.start}"
            )

            continue

        relative = path.relative_to(ROOT)

        for number, line in enumerate(
            text.splitlines(),
            start=1,
        ):

            if "\ufffd" in line:
                confirmed.append(
                    f"{relative}:{number} | "
                    f"replacement-char | "
                    f"{line.strip()}"
                )

            for bad in MOJIBAKE:
                if bad in line:
                    confirmed.append(
                        f"{relative}:{number} | "
                        f"mojibake | "
                        f"{line.strip()}"
                    )
                    break

            for pattern in SUSPICIOUS:
                if pattern.search(line):
                    warnings.append(
                        f"{relative}:{number} | "
                        f"texto sospechoso | "
                        f"{line.strip()}"
                    )
                    break


if invalid_utf8:
    print("")
    print("========================================")
    print("UTF-8 INVALIDO")
    print("========================================")

    for item in sorted(
        set(invalid_utf8)
    ):
        print(item)

    sys.exit(1)


if confirmed:
    print("")
    print("========================================")
    print("MOJIBAKE CONFIRMADO")
    print("========================================")

    for item in sorted(
        set(confirmed)
    ):
        print(item)

    sys.exit(1)


if warnings:
    print("")
    print("========================================")
    print("TEXTOS A REVISAR")
    print("========================================")

    for item in sorted(
        set(warnings)
    ):
        print(item)

    print("")
    print(
        "Advertencias solamente; "
        "no se modifica codigo."
    )


print("")
print("UTF-8 estructural: OK")

sys.exit(0)
