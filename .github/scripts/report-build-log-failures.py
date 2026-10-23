"""Expose bounded build failures through the GitHub checks API as well as logs."""

from pathlib import Path
import re
import sys


def report(directory):
    pattern = re.compile(
        r"error(?:\[|:)|error [CL]\d|FAILED:|panicked at|CMake Error|"
        r"test result: FAILED|^FAIL:|AssertionError:|^Diff in "
    )
    for log in sorted(Path(directory).glob("*.log")):
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        hits = [i for i, line in enumerate(lines) if pattern.search(line)]
        if log.name.endswith("-format.log"):
            # Formatting failures are a list of diffs; a few windows around the
            # first hits would hide the rest, so report the log from the top.
            message = "\n".join(lines)[:6500]
            message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print(f"::error title={log.name}::{message}")
            continue
        excerpt = []
        for i in hits[:3]:
            excerpt.extend(lines[max(0, i - 1):i + 8])
        excerpt.extend(lines[-4:])
        message = "\n".join(excerpt)[-6500:]
        message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error title={log.name}::{message}")


if __name__ == "__main__":
    report(sys.argv[1])
