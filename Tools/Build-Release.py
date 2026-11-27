"""Build an installable addon-only ZIP; no installers, tests or runtime state."""
from pathlib import Path
import re
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / "app/addons/ThreatArrows"
version = re.search(r"^## Version: (.+)$", (addon / "ThreatArrows.toc").read_text(), re.M)[1].strip()
assert re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", version)
files = ["ThreatArrows.toc", "ThreatArrows.lua", "Media/ArrowStyles.tga", "Media/ColorWheel.tga", "LICENSE.txt"]
output = root / "dist" / ("ThreatArrows-" + version + ".zip")
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(addon / name, "ThreatArrows/" + name)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert archive.namelist() == ["ThreatArrows/" + name for name in files]
    for name in files:
        assert archive.read("ThreatArrows/" + name) == (addon / name).read_bytes()
print(output)
print("Verified: addon folder at ZIP root, exact source bytes, no installers or private state.")
