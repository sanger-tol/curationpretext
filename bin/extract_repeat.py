#!/usr/bin/env python3

"""
A rewrite of the extract_repeat.pl (PERL) script.
Original script written by: Yumi Sims (yy5)
Rewritten by: Damon-Lee Pointon (dp24)

Move through repeats file, line by line, and extract repeat information.
"""

import re
import sys

def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("Usage: extract_repeat.py <file>")

    file_path = sys.argv[1]
    last = None

    with open(file_path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            matched = re.match(r">(\S+)", line)
            if matched:
                last = matched.group(1)
                continue

            matched = re.match(r"(\d+)\s+-\s+(\d+)", line)
            if matched:
                print(f"{last}\t{matched.group(1)}\t{matched.group(2)}")
                continue

            sys.exit(f"Error --> {line}")

if __name__ == "__main__":
    main()
