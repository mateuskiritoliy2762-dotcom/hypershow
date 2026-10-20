"""Ponte entre esta pasta e o Roblox Studio via Studio MCP (substitui o Script Sync).

Uso:
  python tools/studio.py push              envia os .luau da pasta para o Studio
  python tools/studio.py run <arq.luau> [Edit|Server|Client]
  python tools/studio.py play start|stop
  python tools/studio.py output            imprime o Output do Studio
  python tools/studio.py shot <saida.png> [cx cy cz lx ly lz]   captura a tela (câmera opcional)
  python tools/studio.py call <tool> '<json>'

Mapeamento (mesma convenção do Script Sync):
  Nome.server.luau -> Script, Nome.client.luau -> LocalScript, Nome.luau -> ModuleScript
  pastas -> Folder. Instâncias criadas pelo push levam o atributo SyncedFromDisk;
  as que não existem mais no disco são apagadas no próximo push.
"""
import base64, json, os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = {
    "ServerScriptService": 'game:GetService("ServerScriptService")',
    "ReplicatedStorage": 'game:GetService("ReplicatedStorage")',
    "StarterPlayerScripts": 'game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")',
}


class Studio:
    def __init__(self):
        exe = os.path.expandvars(r"%LOCALAPPDATA%\Roblox\mcp.bat")
        self.p = subprocess.Popen(["cmd.exe", "/c", exe], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, text=True, encoding="utf-8")
        self._id = 0
        self._rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                 "clientInfo": {"name": "hypershow-tools", "version": "1"}})
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        self.studio_id = self._find_studio()

    def _send(self, msg):
        self.p.stdin.write(json.dumps(msg) + "\n")
        self.p.stdin.flush()

    def _rpc(self, method, params):
        self._id += 1
        self._send({"jsonrpc": "2.0", "id": self._id, "method": method, "params": params})
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise SystemExit("Studio MCP fechou a conexão")
            r = json.loads(line)
            if r.get("id") == self._id:
                return r

    def _find_studio(self):
        # O servidor demora alguns segundos para enxergar o Studio depois de iniciar.
        for _ in range(30):
            text, _ = self.call("list_roblox_studios", {}, with_id=False)
            studios = json.loads(text).get("studios", [])
            if studios:
                return studios[0]["id"]
            time.sleep(0.5)
        raise SystemExit("Nenhum Roblox Studio conectado. Abra o Studio com o MCP ligado.")

    def call(self, tool, args, with_id=True):
        if with_id:
            args = {"studio_id": self.studio_id, **args}
        r = self._rpc("tools/call", {"name": tool, "arguments": args})
        res = r.get("result", r)
        self.images = [c["data"] for c in res.get("content", []) if c.get("type") == "image"]
        text = "\n".join(c.get("text", "") for c in res.get("content", []))
        return text, bool(res.get("isError"))

    def luau(self, code, datamodel="Edit"):
        return self.call("execute_luau", {"datamodel_type": datamodel, "code": code})

    def close(self):
        self.p.terminate()


def _long_string(s):
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + s + "]" + eq + "]"


def _collect():
    """Lista (raiz, caminho relativo em partes, classe, fonte) de todos os .luau."""
    items = []
    for root in TARGETS:
        base = os.path.join(ROOT, root)
        for dirpath, _, files in os.walk(base):
            for f in sorted(files):
                if not f.endswith(".luau"):
                    continue
                rel = os.path.relpath(os.path.join(dirpath, f), base).replace("\\", "/").split("/")
                name = rel[-1][:-5]
                cls = "ModuleScript"
                if name.endswith(".server"):
                    name, cls = name[:-7], "Script"
                elif name.endswith(".client"):
                    name, cls = name[:-7], "LocalScript"
                with open(os.path.join(dirpath, f), encoding="utf-8") as fh:
                    items.append((root, rel[:-1] + [name], cls, fh.read()))
    return items


def build_push_code():
    entries = []
    for root, parts, cls, src in _collect():
        path = "{" + ",".join(json.dumps(p) for p in parts) + "}"
        entries.append(f'{{root={json.dumps(root)}, path={path}, class="{cls}", source={_long_string(src)}}},')
    roots = ",".join(f"[{json.dumps(k)}]={v}" for k, v in TARGETS.items())
    return f"""
local roots = {{{roots}}}
local entries = {{
{chr(10).join(entries)}
}}
local keep = {{}}
local created, updated, removed = 0, 0, 0
for _, e in entries do
	local parent = roots[e.root]
	for i = 1, #e.path - 1 do
		local f = parent:FindFirstChild(e.path[i])
		if not f then
			f = Instance.new("Folder")
			f.Name = e.path[i]
			f:SetAttribute("SyncedFromDisk", true)
			f.Parent = parent
		end
		keep[f] = true
		parent = f
	end
	local name = e.path[#e.path]
	local inst = parent:FindFirstChild(name)
	if inst and inst.ClassName ~= e.class then
		inst:Destroy()
		inst = nil
	end
	if not inst then
		inst = Instance.new(e.class)
		inst.Name = name
		inst:SetAttribute("SyncedFromDisk", true)
		inst.Parent = parent
		created += 1
	elseif (inst :: any).Source ~= e.source then
		updated += 1
	end
	(inst :: any).Source = e.source
	keep[inst] = true
end
local stale = {{}}
for _, r in roots do
	for _, d in r:GetDescendants() do
		if d:GetAttribute("SyncedFromDisk") and not keep[d] then
			table.insert(stale, d)
		end
	end
end
for _, d in stale do
	if d.Parent then
		d:Destroy()
		removed += 1
	end
end
return string.format("push ok: %d arquivos, %d criados, %d atualizados, %d removidos", #entries, created, updated, removed)
"""


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "push"
    s = Studio()
    try:
        if cmd == "push":
            text, err = s.luau(build_push_code())
        elif cmd == "run":
            with open(sys.argv[2], encoding="utf-8") as fh:
                text, err = s.luau(fh.read(), sys.argv[3] if len(sys.argv) > 3 else "Edit")
        elif cmd == "play":
            text, err = s.call("start_stop_play", {"is_start": sys.argv[2] == "start"})
        elif cmd == "output":
            text, err = s.call("get_console_output", {})
        elif cmd == "shot":
            args = {"capture_id": f"ScreenCapture_{int(time.time())}"}
            if len(sys.argv) >= 9:
                v = [float(x) for x in sys.argv[3:9]]
                args.update(camera_position=v[:3], look_at_position=v[3:])
            text, err = s.call("screen_capture", args)
            if s.images:
                with open(sys.argv[2], "wb") as fh:
                    fh.write(base64.b64decode(s.images[0]))
                text = "imagem salva em " + sys.argv[2]
        elif cmd == "call":
            text, err = s.call(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else {})
        else:
            raise SystemExit(__doc__)
    finally:
        s.close()
    print(text)
    sys.exit(1 if err else 0)


if __name__ == "__main__":
    main()
