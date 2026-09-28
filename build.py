"""Baut StealACritter.rbxlx aus src/ (ohne Rojo).

    python build.py

Regeln wie bei Rojo: *.server.luau -> Script, *.client.luau -> LocalScript,
*.luau -> ModuleScript, Ordner -> Folder.
"""
import os
import xml.dom.minidom
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.abspath(__file__))
OUTPUT = os.path.join(ROOT, "StealACritter.rbxlx")

# (Service, Unterordner-Name oder None = direkt in den Service, Quellpfad)
TREE = [
    ("ReplicatedStorage", "Shared", "src/shared"),
    ("ServerScriptService", "Server", "src/server"),
    ("StarterPlayer/StarterPlayerScripts", None, "src/client"),
]

_ref = 0


def next_ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(class_name, name, children="", source=None):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{class_name}" referent="{next_ref()}"><Properties>{props}</Properties>{children}</Item>'


def script_info(filename):
    for suffix, class_name in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return class_name, filename[: -len(suffix)]
    return None, None


def dir_children(path):
    out = ""
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            out += item("Folder", entry, dir_children(full))
            continue
        class_name, name = script_info(entry)
        if class_name:
            with open(full, encoding="utf-8") as f:
                out += item(class_name, name, source=f.read().replace("\r\n", "\n"))
    return out


def main():
    services = {}
    for service_path, folder, src in TREE:
        content = dir_children(os.path.join(ROOT, src))
        if folder:
            content = item("Folder", folder, content)
        services.setdefault(service_path, "")
        services[service_path] += content

    # verschachtelte Services (StarterPlayer/StarterPlayerScripts) zusammenbauen
    body = ""
    starter_player_children = ""
    for service_path, content in services.items():
        parts = service_path.split("/")
        if len(parts) == 2:
            starter_player_children += item(parts[1], parts[1], content)
        else:
            body += item(parts[0], parts[0], content)
    if starter_player_children:
        body += item("StarterPlayer", "StarterPlayer", starter_player_children)

    document = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        "<External>null</External><External>nil</External>"
        f"{body}</roblox>"
    )
    xml.dom.minidom.parseString(document.encode("utf-8"))  # Wohlgeformtheit pruefen
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(document)
    print(f"Built {OUTPUT} ({_ref} instances)")


if __name__ == "__main__":
    main()
