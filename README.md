# JSON Embed

A neovim plugin for easily editing languages embedded into json

![Usage](./usage.mov)

## Installation

**lazy.nvim**

```lua
  {
    "richardmarbach/json-embed.nvim",
    name = "json-embed",
    cmd = { "JSONEmbedEdit" },
    keys = {
      {
        "n",
        "<leader>je",
        function()
          require("json-embed").edit_embedded()

          -- Example of how to format the content immediately when the buffer is opened
          local buf = vim.api.nvim_get_current_buf()
          require("conform").format({ timeout_ms = 5000, lsp_fallback = true, buf = buf })
        end,
        silent = true,
        desc = "Edit json embedded language under cursor",
      },
    },
    opts = { ft = "sql" },
  },

```
