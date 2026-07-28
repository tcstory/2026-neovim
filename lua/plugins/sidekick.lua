return {
  "folke/sidekick.nvim",
  opts = {
    nes = {
      enabled = false,
    },
    copilot = {
      status = {
        enabled = false,
      },
    },
    cli = {
      win = {
        layout = "right",
        split = {
          width = 80,
        },
      },
      tools = {
        codex = {
          -- Equivalent to the zsh alias: codex-cli='proxy-ns codex '
          cmd = { "proxy-ns", "codex" },
        },
      },
    },
  },
  keys = {
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ name = "codex", focus = true })
      end,
      desc = "Toggle Codex",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select({ filter = { installed = true } })
      end,
      desc = "Select AI CLI",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "Close AI CLI",
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("sidekick.cli").send({ msg = "{selection}" })
      end,
      mode = "x",
      desc = "Send Selection",
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      mode = { "n", "x" },
      desc = "Select AI Prompt",
    },
  },
}
