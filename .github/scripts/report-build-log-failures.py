"""Expose bounded build failures through the GitHub checks API as well as logs."""

from pathlib import Path
import re
import sys


def report(directory):
    pattern = re.compile(
        r"error(?:\[|:)|error [CL]\d|FAILED:|panicked at|CMake Error|critical default:|"
        r"test result: FAILED|FAIL!?\s*:|AssertionError:|^Diff in |"
        r"qrc:/\S*\.qml|file://\S*\.qml|Binding loop|ReferenceError:|TypeError:|"
        r"Unable to assign|Cannot read property|Cannot set property|is not a function|"
        r"Game labels:|Collections acceptance:|Interactive shell acceptance failed|QML smoke test"
    )
    for log in sorted(Path(directory).glob("*.log")):
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        hits = [i for i, line in enumerate(lines)
                if pattern.search(line) and " info qt." not in line]
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
        # CTest prefixes child output with its test number in verbose mode and
        # can also fail before QTest emits an assertion. Keep enough of the tail
        # to expose both cases without publishing an unbounded build log.
        excerpt.extend(lines[-(160 if log.name == "ctest.log" else 16):])
        message = "\n".join(excerpt)[-6500:]
        message = message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        print(f"::error title={log.name}::{message}")


if __name__ == "__main__":
    report(sys.argv[1])
