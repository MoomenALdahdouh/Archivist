#!/bin/zsh
set -euo pipefail
# Install Finder right-click actions and register Archivist with Launch Services.
# macOS shows these under Finder → Quick Actions, and often as Services.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="${1:-$ROOT/dist/Archivist.app}"
APP_DST="/Applications/Archivist.app"
SERVICES="$HOME/Library/Services"

if [[ ! -d "$APP_SRC" ]]; then
  echo "Archivist.app not found at $APP_SRC. Run Scripts/package-app.sh first." >&2
  exit 1
fi

# Generate Automator Quick Actions into the app bundle, then install the app.
APP_SERVICES="$APP_SRC/Contents/Library/Services"
mkdir -p "$APP_SERVICES"

python3 - "$APP_SERVICES" "$APP_DST" <<'PY'
import os, plistlib, sys, uuid

services_dir, app_dst = sys.argv[1], sys.argv[2]
cli = os.path.join(app_dst, "Contents/MacOS/archivemgr")

def script(fmt: str) -> str:
    return f'''#!/bin/zsh
CLI={cli!r}
if [[ ! -x "$CLI" ]]; then
  osascript -e 'display alert "Archivist is not installed" message "Put Archivist.app in /Applications, then try again."'
  exit 1
fi
files=("$@")
if [[ ${{#files[@]}} -eq 0 ]]; then
  exit 1
fi
parent="$(dirname -- "${{files[1]}}")"
if [[ ${{#files[@]}} -eq 1 ]]; then
  base="$(basename -- "${{files[1]}}")"
  name="${{base%.*}}"
  [[ "$name" == "$base" ]] && name="$base"
else
  name="Archive"
fi
ext="{fmt}"
dest="$parent/${{name}}.$ext"
n=1
while [[ -e "$dest" ]]; do
  dest="$parent/${{name}} ${{n}}.$ext"
  n=$((n+1))
done
"$CLI" create "${{files[@]}}" "$dest" --format {fmt} --overwrite alwaysReplace
open -R -- "$dest"
'''

def write_workflow(menu_name: str, bundle_id: str, command: str):
    root = os.path.join(services_dir, f"{menu_name}.workflow")
    contents = os.path.join(root, "Contents")
    resources = os.path.join(contents, "Resources")
    os.makedirs(resources, exist_ok=True)
    info = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleIdentifier": bundle_id,
        "CFBundleName": menu_name,
        "CFBundleShortVersionString": "1.0",
        "NSServices": [{
            "NSMenuItem": {"default": menu_name},
            "NSMessage": "runWorkflowAsService",
            "NSIconName": "NSActionTemplate",
            "NSBackgroundColorName": "gray",
            "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
            "NSSendFileTypes": ["public.item", "public.content", "public.data"],
        }],
    }
    with open(os.path.join(contents, "Info.plist"), "wb") as fh:
        plistlib.dump(info, fh, fmt=plistlib.FMT_XML)
    in_uuid = str(uuid.uuid4()).upper()
    out_uuid = str(uuid.uuid4()).upper()
    act_uuid = str(uuid.uuid4()).upper()
    wflow = {
        "AMApplicationBuild": "523",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [{
            "action": {
                "AMAccepts": {
                    "Container": "List",
                    "Optional": False,
                    "Types": ["com.apple.cocoa.path"],
                },
                "AMActionVersion": "2.0.3",
                "AMApplication": ["Automator"],
                "AMParameterProperties": {
                    "COMMAND_STRING": {},
                    "CheckedForUserDefaultShell": {},
                    "inputMethod": {},
                    "shell": {},
                    "source": {},
                },
                "AMProvides": {
                    "Container": "List",
                    "Types": ["com.apple.cocoa.string"],
                },
                "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
                "ActionName": "Run Shell Script",
                "ActionParameters": {
                    "COMMAND_STRING": command,
                    "CheckedForUserDefaultShell": True,
                    "inputMethod": 1,
                    "shell": "/bin/zsh",
                    "source": "",
                },
                "BundleIdentifier": "com.apple.RunShellScript",
                "CFBundleVersion": "2.0.3",
                "CanShowSelectedItemsWhenRun": False,
                "CanShowWhenRun": True,
                "Category": ["AMCategoryUtilities"],
                "Class Name": "RunShellScriptAction",
                "InputUUID": in_uuid,
                "Keywords": ["Shell", "Archive", "Compress"],
                "OutputUUID": out_uuid,
                "UUID": act_uuid,
                "UnlocalizedApplications": ["Automator"],
            }
        }],
        "connectors": {},
        "workflowMetaData": {
            "serviceApplicationBundleID": "com.apple.finder",
            "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
            "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": 0,
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    }
    payload = plistlib.dumps(wflow, fmt=plistlib.FMT_XML)
    with open(os.path.join(contents, "document.wflow"), "wb") as fh:
        fh.write(payload)
    with open(os.path.join(resources, "document.wflow"), "wb") as fh:
        fh.write(payload)
    print(f"Wrote {root}")

write_workflow("Compress with Archivist", "app.archivist.service.compressRar", script("rar"))
write_workflow("Compress to ZIP with Archivist", "app.archivist.service.compressZip", script("zip"))
write_workflow("Compress to 7Z with Archivist", "app.archivist.service.compress7z", script("7z"))
PY

echo "Installing $APP_SRC → $APP_DST"
killall Archivist 2>/dev/null || true
if [[ -d "$APP_DST" ]]; then
  rm -rf "$APP_DST"
fi
cp -R "$APP_SRC" "$APP_DST"

mkdir -p "$SERVICES"
# Replace previous Archivist Quick Actions.
rm -rf "$SERVICES/Compress with Archivist.workflow" \
       "$SERVICES/Compress to ZIP with Archivist.workflow" \
       "$SERVICES/Compress to 7Z with Archivist.workflow"
cp -R "$APP_DST/Contents/Library/Services/"*.workflow "$SERVICES/" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP_DST"
  "$LSREGISTER" -f "$SERVICES/Compress with Archivist.workflow" || true
  "$LSREGISTER" -f "$SERVICES/Compress to 7Z with Archivist.workflow" || true
fi

python3 - <<'PY'
import subprocess

keys = [
    "app.archivist.Archivist - Compress with Archivist - compressHereRAR",
    "app.archivist.Archivist - Compress to ZIP (Archivist) - compressHereZIP",
    "app.archivist.Archivist - Compress to 7Z (Archivist) - compressHere7Z",
    "app.archivist.Archivist - Extract Here (Archivist) - extractHere",
    "app.archivist.Archivist - Extract to… (Archivist) - extractTo",
    "app.archivist.Archivist - Test Archive (Archivist) - testArchive",
    "app.archivist.service.compressRar - Compress with Archivist - runWorkflowAsService",
    "app.archivist.service.compressZip - Compress to ZIP with Archivist - runWorkflowAsService",
    "app.archivist.service.compress7z - Compress to 7Z with Archivist - runWorkflowAsService",
]
value = "{ enabled_context_menu = 1; enabled_services_menu = 1; }"
for key in keys:
    subprocess.run(
        ["defaults", "write", "pbs", "NSServicesStatus", "-dict-add", key, value],
        check=False,
    )
print("Enabled Archivist items in the Services database")
PY

if [[ -x /System/Library/CoreServices/pbs ]]; then
  /System/Library/CoreServices/pbs -flush || true
  /System/Library/CoreServices/pbs -update || true
fi
killall -u "$USER" pbs 2>/dev/null || true

# Launch once so Launch Services records the running app as a services provider.
open -g -a "$APP_DST" || true

echo
echo "Installed Archivist to /Applications and Finder actions to ~/Library/Services."
echo "Right-click files in Finder, then look for:"
echo "  • Compress with Archivist"
echo "  • Quick Actions → Compress with Archivist"
echo "  • Services → Compress with Archivist"
echo
echo "If it still does not appear: System Settings → Keyboard → Keyboard Shortcuts → Services,"
echo "enable the Archivist items under Files and Folders, then right-click again."
