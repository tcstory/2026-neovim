return {
  "NeogitOrg/neogit",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required

    -- Only one of these is needed.
    "esmuellert/codediff.nvim",      -- optional

    -- For a custom log pager
    "m00qek/baleia.nvim",            -- optional

    -- Only one of these is needed.
    "folke/snacks.nvim",             -- optional
  },
  cmd = "Neogit",
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" }
  },
  opts = {
    graph_style = "unicode",
    integrations = {
      codediff = true,
      snacks = true,
    },
    diff_viewer = "codediff",
  },
  config = function(_, opts)
    require("neogit").setup(opts)

    local ok_commit_view, commit_view = pcall(require, "neogit.buffers.commit_view")
    if not ok_commit_view or commit_view._first_parent_merge_patch_applied then
      return
    end

    local git = require("neogit.lib.git")
    local parser = require("neogit.buffers.commit_view.parsing")
    local neogit_config = require("neogit.config")

    local function build_commit_info(commit_id)
      local cmd = git.cli.show.args("--diff-merges=first-parent", commit_id).format("fuller")
      if neogit_config.values.commit_date_format ~= nil then
        cmd = cmd.args("--date=format:" .. neogit_config.values.commit_date_format)
      end

      local commit_info = git.log.parse(cmd.call({ trim = false }).stdout)[1]
      commit_info.commit_arg = commit_id
      return commit_info
    end

    local function build_commit_overview(commit_id)
      return parser.parse_commit_overview(
        git.cli.show.stat.oneline.args("--diff-merges=first-parent", commit_id).call({ hidden = true }).stdout
      )
    end

    function commit_view.new(commit_id, filter)
      local commit_info = build_commit_info(commit_id)

      local instance = {
        item_filter = filter,
        commit_info = commit_info,
        commit_overview = build_commit_overview(commit_id),
        commit_signature = neogit_config.values.commit_view.verify_commit and git.log.verify_commit(commit_id) or {},
        buffer = nil,
      }

      setmetatable(instance, { __index = commit_view })
      return instance
    end

    function commit_view:update(commit_id, filter)
      assert(commit_id, "commit id cannot be nil")

      self.item_filter = filter
      self.commit_info = build_commit_info(commit_id)
      self.commit_overview = build_commit_overview(commit_id)
      self.commit_signature = neogit_config.values.commit_view.verify_commit and git.log.verify_commit(commit_id) or {}

      self.buffer.ui:render(
        unpack(
          require("neogit.buffers.commit_view.ui").CommitView(
            self.commit_info,
            self.commit_overview,
            self.commit_signature,
            self.item_filter
          )
        )
      )

      self.buffer:win_call(vim.cmd, "normal! gg")
    end

    commit_view._first_parent_merge_patch_applied = true
  end,
}
