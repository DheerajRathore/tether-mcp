# Tether

Tether is a macOS menu-bar app that lets AI clients such as Claude Desktop read your Apple Notes through the Model Context Protocol (MCP).

- Runs entirely on your Mac. No hosted server.
- Read-only. Tether never modifies your notes.
- Asks for your approval before a new client can connect.

**Status:** early development. There is no packaged release yet, so you need to build it from source. Notes come first; Reminders, Calendar, Messages and Mail are planned for later.

## What works today

| Tool | What it does |
| --- | --- |
| `notes_search` | Searches note titles and contents. Returns id, title, folder, modified date and a locked flag. Supports folder, date and limit filters. |
| `notes_read` | Reads one note as Markdown (tables and checklists included). Password-locked notes are refused. Output is capped at 50,000 characters. |
| `ping` | Health check. |

With these, an AI client can find notes and then summarise or explain them. It does so by calling `notes_search`, then `notes_read`.

## How it works

Claude Desktop → `tether-cli` (stdio) → Tether app (Bonjour + local TCP) → Apple Notes

The app runs a local MCP server and reads your notes through a folder you choose. `tether-cli` is a small relay that lets stdio-based clients reach the app.

## Privacy and safety

- Everything stays on your Mac. Tether has no network service beyond the local connection.
- When a client connects for the first time, Tether asks you to **Allow** or **Deny** it. "Always trust" remembers the client by name.
- The client name is reported by the client itself, so "Always trust" is a convenience, not strong security.
- Locked notes are never read.
- Tether only reads notes from the folder you grant access to.

## Build from source

Requires macOS and Xcode. *(Add the minimum macOS and Xcode versions here.)*

1. Clone the repo and open the Xcode project.
2. Build and run the Tether app. It appears in the menu bar.
3. Choose the Apple Notes folder when prompted (`group.com.apple.notes`).
4. Add Tether to Claude Desktop's config, pointing at your built `tether-cli`. *(Setup steps to be added; there is no one-click setup yet.)*
5. Restart Claude Desktop and approve the connection when Tether asks.

Try it with non-sensitive notes first.

## Roadmap

- Per-tool switches and a Settings window
- One-click "Configure Claude Desktop" button
- Reminders and Calendar (create only, with confirmation before writing)
- Messages and Mail (read-only, off by default)
- Packaged release (`.dmg`)

## License

*(Add license.)*

Not affiliated with or endorsed by Apple. Apple Notes is a trademark of Apple Inc.
