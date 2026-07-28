#!/bin/bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- Sources Tests
fi

python3 - "$@" <<'PY'
import pathlib
import re
import sys

forbidden_patterns = {
    "syncShutdownGracefully": re.compile(r"\bsyncShutdownGracefully\s*\("),
    "DispatchSemaphore": re.compile(r"\bDispatchSemaphore\b"),
    "blocking wait": re.compile(r"\.wait\s*\("),
    "synchronous dispatch": re.compile(r"\.sync\s*(?:\(|\{)"),
    "process wait": re.compile(r"\bwaitUntilExit\s*\("),
}


def swift_files(path: pathlib.Path):
    if path.is_file() and path.suffix == ".swift":
        yield path
    elif path.is_dir():
        yield from path.rglob("*.swift")


def deinit_blocks(source: str):
    for match in re.finditer(r"\bdeinit\b", source):
        opening_brace = source.find("{", match.end())
        if opening_brace < 0:
            continue
        depth = 0
        for index in range(opening_brace, len(source)):
            character = source[index]
            if character == "{":
                depth += 1
            elif character == "}":
                depth -= 1
                if depth == 0:
                    yield match.start(), source[match.start() : index + 1]
                    break


findings = []
for raw_path in sys.argv[1:]:
    path = pathlib.Path(raw_path)
    for swift_file in swift_files(path):
        source = swift_file.read_text(encoding="utf-8")
        for offset, block in deinit_blocks(source):
            for label, pattern in forbidden_patterns.items():
                if pattern.search(block):
                    line = source.count("\n", 0, offset) + 1
                    findings.append(f"{swift_file}:{line}: {label} in deinit")

if findings:
    print("Synchronous shutdown risk detected:", file=sys.stderr)
    for finding in findings:
        print(finding, file=sys.stderr)
    sys.exit(1)

print("OK: no synchronous shutdown calls found in deinit")
PY
