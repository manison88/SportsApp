#!/usr/bin/env python3
"""Registers a new Swift file in the committed Witness.xcodeproj (Xcode Cloud builds from it, not from project.yml).
usage: python3 Tools/add_to_xcodeproj.py Witness/Services/NewFile.swift Witness/Services/SiblingInSameFolder.swift
"""
import re, sys, uuid, pathlib

root = pathlib.Path(__file__).resolve().parents[1]
proj = root / "Witness.xcodeproj/project.pbxproj"
new, sibling = pathlib.Path(sys.argv[1]).name, pathlib.Path(sys.argv[2]).name
text = proj.read_text()
if text.count(new) >= 4:
    print("already registered"); sys.exit(0)
ref, build = uuid.uuid4().hex[:24].upper(), uuid.uuid4().hex[:24].upper()
lines = text.split("\n")
out = []
for line in lines:
    out.append(line)
    if re.search(rf"/\* {re.escape(sibling)}( in Sources)? \*/", line):
        indent = re.match(r"\s*", line).group(0)
        if "PBXBuildFile" in line or "in Sources" in line and "isa = PBXBuildFile" in line:
            out.append(f"{indent}{build} /* {new} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {new} */; }};")
        elif "isa = PBXFileReference" in line:
            out.append(f"{indent}{ref} /* {new} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {new}; sourceTree = \"<group>\"; }};")
        elif line.strip().endswith("in Sources */,"):
            out.append(f"{indent}{build} /* {new} in Sources */,")
        elif line.strip().endswith(f"/* {sibling} */,"):
            out.append(f"{indent}{ref} /* {new} */,")
proj.write_text("\n".join(out))
print("registered", new, text.count(new), "->", "\n".join(out).count(new))
