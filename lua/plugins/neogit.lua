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

    local unicode_graph = require("neogit.lib.graph.unicode")
    if not unicode_graph._user_lane_colors_applied then
      local original_build = unicode_graph.build
      local lane_colors = { "Red", "Yellow", "Green", "Cyan", "Blue", "Purple", "Orange", "White" }
      local graph_chars = {
        ["•"] = true,
        ["│"] = true,
        ["┊"] = true,
        ["┬"] = true,
        ["┤"] = true,
        ["├"] = true,
        ["┼"] = true,
        ["┴"] = true,
        ["╯"] = true,
        ["╰"] = true,
        ["╮"] = true,
        ["╭"] = true,
        ["─"] = true,
      }

      unicode_graph.build = function(commits)
        local graph = original_build(commits)

        for _, line in ipairs(graph) do
          for idx, cell in ipairs(line) do
            if graph_chars[cell.text] then
              local lane = math.floor((idx - 1) / 2)
              cell.color = lane_colors[(lane % #lane_colors) + 1]
            end
          end
        end

        return graph
      end

      unicode_graph._user_lane_colors_applied = true
    end

    local function set_neogit_graph_highlights()
      local set = vim.api.nvim_set_hl

      set(0, "NeogitGraphRed", { fg = "#f38ba8" })
      set(0, "NeogitGraphBoldRed", { fg = "#f38ba8", bold = true })
      set(0, "NeogitGraphGreen", { fg = "#a6e3a1" })
      set(0, "NeogitGraphBoldGreen", { fg = "#a6e3a1", bold = true })
      set(0, "NeogitGraphYellow", { fg = "#f9e2af" })
      set(0, "NeogitGraphBoldYellow", { fg = "#f9e2af", bold = true })
      set(0, "NeogitGraphBlue", { fg = "#89b4fa" })
      set(0, "NeogitGraphBoldBlue", { fg = "#89b4fa", bold = true })
      set(0, "NeogitGraphPurple", { fg = "#cba6f7" })
      set(0, "NeogitGraphBoldPurple", { fg = "#cba6f7", bold = true })
      set(0, "NeogitGraphCyan", { fg = "#94e2d5" })
      set(0, "NeogitGraphBoldCyan", { fg = "#94e2d5", bold = true })
      set(0, "NeogitGraphWhite", { fg = "#cdd6f4" })
      set(0, "NeogitGraphBoldWhite", { fg = "#cdd6f4", bold = true })
      set(0, "NeogitGraphGray", { fg = "#7f849c" })
      set(0, "NeogitGraphBoldGray", { fg = "#7f849c", bold = true })
      set(0, "NeogitGraphOrange", { fg = "#fab387" })
      set(0, "NeogitGraphBoldOrange", { fg = "#fab387", bold = true })
      set(0, "NeogitGraphAuthor", { fg = "#fab387" })
    end

    set_neogit_graph_highlights()

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("UserNeogitGraphHighlights", { clear = true }),
      callback = set_neogit_graph_highlights,
    })

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
