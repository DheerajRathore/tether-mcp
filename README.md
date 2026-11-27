# Tether

Tether is a macOS menu-bar app that lets AI clients such as Claude Desktop read your Apple Notes through the Model Context Protocol (MCP).

- **Runs entirely on your Mac.** No hosted server.
- **Read-only.** Tether never modifies your notes.
- **Asks for your approval** before a new client can connect.

> **Status: early release (0.x).** Notes come first. Reminders, Calendar, Messages and Mail are planned for later.

## What works today

| Tool | What it does |
|---|---|
| `notes_search` | Searches note titles and contents. Returns id, title, folder, modified date and a locked flag. Supports folder, date and limit filters. |
| `notes_read` | Reads one note as Markdown (tables and checklists included). Password-locked notes are refused. Output is capped at 50,000 characters. |
| `ping` | Health check. |

An AI client finds notes with `notes_search`, then summarises or explains them with `notes_read`.

## Install

1. Download `Tether-x.y.z.dmg` from [Releases](https://github.com/DheerajRathore/tether-mcp/releases) and drag Tether to **Applications**.
2. Tether isn't notarized yet, so macOS blocks the first launch. Open it once, then go to **System Settings → Privacy & Security → Open Anyway**.
   Fallback: `xattr -dr com.apple.quarantine /Applications/Tether.app`
3. Keep the app in `/Applications`. The Claude Desktop config points at the CLI inside the app, so moving it later breaks the path (the app will tell you to click Update).

## Set up

1. Click the link icon in the menu bar, then **Choose Notes folder…** and pick `group.com.apple.notes`.
2. Under **Claude Desktop**, click **Configure Claude Desktop**. Grant access to the Claude folder and confirm. Tether adds one entry to `claude_desktop_config.json` and saves a `.bak` backup first. Your other servers are untouched.
3. Quit Claude Desktop (Cmd+Q), reopen it, and start a new chat.
4. Approve the connection when Tether asks.

If Tether isn't running when Claude Desktop starts, the CLI launches it for you (the server must be enabled in the popover).

Try it with non-sensitive notes first, for example: *"Use notes_search with query 'Tether Test' and summarise the first result."*

## How it works

Claude Desktop → `tether-cli` (stdio) → Tether app (Bonjour + local TCP) → Apple Notes

The app runs a local MCP server and reads your notes through a folder you choose. `tether-cli` is a small relay, bundled inside the app, that lets stdio-based clients reach it.

## Privacy and safety

- Tether has no network service beyond the local connection.
- Notes you ask an AI client to read are passed to that client, and then to whatever service it uses. Tether can't control that, so choose what you ask about.
- The first time a client connects, Tether asks you to Allow or Deny it. "Always trust" remembers the client by name, and **Reset trusted clients** in the popover clears the list.
- The client name is reported by the client itself, so "Always trust" is a convenience, not strong security.
- Locked notes are never read.
- Tether only reads notes from the folder you grant access to.

## Other MCP clients

Any client that accepts a stdio command can use the bundled CLI, for example:

```bash
claude mcp add tether -- /Applications/Tether.app/Contents/MacOS/tether-cli
```

ChatGPT connectors need a remote HTTPS server, so they can't use Tether.

## Troubleshooting

- **Tools missing in Claude Desktop:** quit it completely (Cmd+Q) and reopen it, then start a new chat.
- **Claude answers "ping" without calling the tool:** test with `notes_search` and ask it to show the raw result.
- **Two Tether icons in the menu bar:** an old copy is still running. Quit both and relaunch one (`pkill -x Tether`).
- **Status says the config points to a different location:** click **Update Claude Desktop Config**.

## Build from source

Requires macOS and Xcode. (Add the minimum macOS and Xcode versions here.)

1. Clone the repo and open the Xcode project.
2. Build and run the **Tether** scheme. The app appears in the menu bar.
3. Follow **Set up** above. The Configure button writes the path of the CLI inside your build.
4. To build a release image: `/Tether/scripts/build-dmg.sh 0.1.0`

## Roadmap

- Per-tool switches and a Settings window (including launch at login)
- Reminders and Calendar (create only, with confirmation before writing)
- Messages and Mail (read-only, off by default)
- Notarized release, Homebrew cask, automatic updates

## License

MIT

Not affiliated with or endorsed by Apple. Apple Notes is a trademark of Apple Inc.
