# httpyac-nvim

A NeoVim wrapper plugin for [httpyac](https://httpyac.github.io/) CLI - Send HTTP requests from `.http` files directly within NeoVim with async execution and dedicated output buffer.

## Features

- ⚡ **Async Execution** - Non-blocking HTTP requests using `vim.uv`
- 📝 **Send Requests** - Execute request at cursor or all requests in buffer
- 🎨 **Syntax Highlighting** - Color-coded HTTP responses with status codes
- 🔍 **Fuzzy Navigation** - Jump to requests/variables with integrated picker
- 🌍 **Environment Management** - Switch between dev/staging/prod environments
- 📤 **Dedicated Output** - Persistent vertical split buffer for responses
- 🔗 **Session Mode** - Persistent cookies, `$global` variables, and OAuth tokens across requests
- 🔌 **Seamless Integration** - Works with snacks.nvim and which-key.nvim

## Session Mode

By default, httpyac-nvim spawns a fresh `httpyac` CLI process per request, which loses all state between calls.  **Session mode** launches a long-lived Node.js sidecar that uses httpyac as a library, keeping the same process alive so that:

- **Cookies** set by one request are automatically sent to subsequent requests.
- **`$global` variables** (e.g. auth tokens extracted from a login response) persist for the entire Neovim session.
- **OAuth tokens** are cached and refreshed in-process — no re-authentication on every call.

> **Scope:** Session state is per-Neovim-session and lives only in memory. Closing Neovim (or calling `<leader>Rxr` Reset) discards all state.

### Session Keymaps

All keymaps are buffer-local and active in `.http` files under the `<leader>Rx` prefix:

| Keymap        | Action                              | Description                                  |
|---------------|-------------------------------------|----------------------------------------------|
| `<leader>Rxs` | `send_request_at_cursor_session()`  | Send request at cursor (persistent session)  |
| `<leader>RxS` | `send_all_session()`                | Send all requests in buffer (session)        |
| `<leader>Rxr` | `reset_session()`                   | Clear `$global`, cookies, OAuth tokens       |
| `<leader>Rxv` | `show_session_globals()`            | Inspect current `$global` in a float window  |
| `<leader>Rxi` | `session_status()`                  | Show sidecar status and global var count     |

### Example Workflow — Login then Authenticated Call

```http
### Step 1 — Login and store the token globally
POST https://api.example.com/auth/login
Content-Type: application/json

{
  "username": "{{username}}",
  "password": "{{password}}"
}

{{
  // Post-response script: save token into $global
  $global.token = response.parsedBody.token;
}}

###

### Step 2 — Use the stored token (same session)
GET https://api.example.com/users/me
Authorization: Bearer {{$global.token}}
```

1. Place the cursor on the `POST` request and press `<leader>Rxs` — the token is captured.
2. Place the cursor on the `GET` request and press `<leader>Rxs` — it uses `$global.token` automatically.
3. Press `<leader>Rxv` to inspect all stored globals in a floating window.
4. Press `<leader>Rxr` to clear the session when done.

### Requirements for Session Mode

- **`node`** must be in `PATH` (already required by httpyac itself).
- httpyac must be installed globally (`npm install -g httpyac` or via Homebrew).

The sidecar process starts automatically on the first session request and shuts down cleanly when Neovim exits.

## Requirements

### Required

- **NeoVim** 0.10+ (for `vim.uv` support)
- **[httpyac](https://httpyac.github.io/)** CLI tool
  ```bash
  npm install -g httpyac
  # or
  yarn global add httpyac
  ```
- **[snacks.nvim](https://github.com/folke/snacks.nvim)** - For pickers
- **[which-key.nvim](https://github.com/folke/which-key.nvim)** - For keymap registration

### Optional

- Treesitter parser for `http` files (recommended for better syntax highlighting in source files)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "asd-noor/httpyac-nvim",
  dependencies = {
    "folke/snacks.nvim",
    "folke/which-key.nvim",
    {
        "nvim-treesitter/nvim-treesitter",
        opts = {
            ensure_installed = { "http" }
        }
    }
  },
  ft = "http", -- Load on http filetype
  config = function()
    require("httpyac-nvim").setup({})
  end,
}
```

### Manual Installation

1. Clone repository to your NeoVim plugin directory:
   ```bash
   git clone https://github.com/noor/httpyac-nvim.git ~/.local/share/nvim/site/pack/plugins/start/httpyac-nvim
   ```
2. Ensure dependencies are installed
3. Restart NeoVim

## Setup

Basic setup (optional - plugin auto-initializes):

```lua
require("httpyac-nvim").setup({})
```

## Usage

### Quick Start

1. Create a `.http` file:

```http
### Simple GET request
GET https://httpbin.org/get

### POST with JSON body
POST https://httpbin.org/post
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com"
}

### Using variables
@baseUrl = https://api.github.com
@username = octocat

GET {{baseUrl}}/users/{{username}}
```

2. Open in NeoVim:
   ```bash
   nvim requests.http
   ```

3. Send requests:
   - Position cursor on a request line
   - Press `<leader>Rs` to send request at cursor
   - Press `<leader>RS` to send all requests in buffer

### Default Keymaps

All keymaps are buffer-local and only active in `.http` files:

| Keymap       | Action                              | Description                           |
|--------------|-------------------------------------|---------------------------------------|
| `<leader>Rs` | `send_request_at_cursor()`         | Send HTTP request at cursor position  |
| `<leader>RS` | `send_all_requests()`              | Send all HTTP requests in buffer      |
| `<leader>Re` | `view_custom_env()`                | View current httpyac environment      |
| `<leader>RE` | `set_custom_env()`                 | Set httpyac environment file          |
| `<leader>Rr` | `jump_to_request()`                | Jump to HTTP request (fuzzy picker)   |
| `<leader>Rv` | `jump_to_variable()`               | Jump to HTTP variable (fuzzy picker)  |

> **Note:** Default leader key is usually `<Space>`

### Lua API

You can call functions directly from Lua:

```lua
local httpyac = require("httpyac-nvim")

-- Send request at cursor
httpyac.send_request_at_cursor()

-- Send request with custom options
httpyac.send_request_at_cursor({"--verbose"})

-- Send all requests
httpyac.send_all_requests()

-- Environment management
httpyac.set_custom_env()
httpyac.view_custom_env()

-- Navigation
httpyac.jump_to_request()
httpyac.jump_to_variable()
```

## Environment Files

httpyac supports environment files for managing variables across different contexts (dev, staging, production).

### Setting Environment

**Method 1: Using keymap**
```
<leader>RE  " Opens file picker to select environment file
```

**Method 2: Using Lua function**
```lua
require("httpyac-nvim").set_custom_env()
```

**Method 3: Using environment variable**
```bash
export HTTPYAC_ENV=/path/to/httpyac.config.js
nvim requests.http
```

### Environment File Example

Create `httpyac.config.js`:

```javascript
module.exports = {
  environments: {
    dev: {
      baseUrl: "http://localhost:3000",
      token: "dev-token-123"
    },
    staging: {
      baseUrl: "https://staging.api.example.com",
      token: "staging-token-456"
    },
    prod: {
      baseUrl: "https://api.example.com",
      token: "prod-token-789"
    }
  }
};
```

Use in your `.http` file:

```http
GET {{baseUrl}}/api/users
Authorization: Bearer {{token}}
```

See [httpyac documentation](https://httpyac.github.io/guide/environments.html) for more details.

## Syntax Highlighting

The plugin provides custom syntax highlighting for HTTP responses in the output buffer (`HTTPYAC_OUT`):

- **HTTP Methods** - GET, POST, PUT, DELETE, etc.
- **Status Codes** - Color-coded by category:
  - `2xx` Success (green)
  - `3xx` Redirect (cyan)
  - `4xx` Client Error (yellow)
  - `5xx` Server Error (red)
- **Headers** - Header names and values
- **JSON** - Strings, numbers, booleans
- **URLs** - Request paths

For `.http` source files, we recommend using [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with the `http` parser.

## Health Check

Verify all dependencies are properly installed:

```vim
:checkhealth httpyac-nvim
```

The health check verifies:
- ✓ httpyac CLI installation and version
- ✓ snacks.nvim availability
- ✓ which-key.nvim availability
- ✓ NeoVim version (0.10+)
- ✓ HTTPYAC_ENV status

## Advanced Usage

### Custom httpyac CLI Options

Pass additional options to httpyac CLI:

```lua
-- Send with verbose output
require("httpyac-nvim").send_request_at_cursor({"--verbose"})

-- Send with specific output format
require("httpyac-nvim").send_request_at_cursor({"--output", "body"})
```

### Multiple Environments

Switch environments on-the-fly:

1. Press `<leader>RE`
2. Select environment file from picker
3. Press `<leader>Re` to verify current environment
4. Send requests - they'll use the selected environment

## Troubleshooting

### Plugin doesn't load for .http files

**Check:**
1. File has `.http` extension or `:set filetype=http` manually
2. Dependencies are installed: `:Lazy` to check plugin status
3. Run `:checkhealth httpyac-nvim`

### Syntax highlighting not working in output

**Check:**
1. Output buffer filetype: `:set ft?` (should be `httpyacout`)
2. File exists: `ls ~/.config/nvim/.../syntax/httpyacout.vim`
3. Run `:checkhealth httpyac-nvim`

### httpyac command not found

**Install httpyac CLI:**
```bash
npm install -g httpyac
# Verify installation
httpyac --version
```

### Keymaps not working

**Check:**
1. You're in a buffer with `filetype=http`
2. which-key.nvim is installed and loaded
3. Try calling functions directly: `:lua require("httpyac-nvim").send_request_at_cursor()`

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

For local development:

```lua
-- In your init.lua
{
  dir = "/path/to/httpyac-nvim",
  name = "httpyac-nvim",
  dependencies = {
    "folke/snacks.nvim",
    "folke/which-key.nvim",
  },
  ft = "http",
}
```

## License

MIT License - see LICENSE file for details

## Related Projects

- [httpyac](https://httpyac.github.io/) - The underlying CLI tool
- [rest.nvim](https://github.com/rest-nvim/rest.nvim) - Alternative HTTP client for NeoVim
- [kulala.nvim](https://github.com/mistweaverco/kulala.nvim) - Another .http file client

## Credits

- Built on top of [httpyac](https://httpyac.github.io/) by Andreas Wassner
- Inspired from [nvim-httpyac](https://github.com/abidibo/nvim-httpyac/)
- Uses [snacks.nvim](https://github.com/folke/snacks.nvim) for pickers
- Uses [which-key.nvim](https://github.com/folke/which-key.nvim) for keybindings

---

**Note:** This plugin is a wrapper around the httpyac CLI. For httpyac-specific features and advanced usage, refer to the [official httpyac documentation](https://httpyac.github.io/).
