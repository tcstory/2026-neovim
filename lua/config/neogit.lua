local M = {}
function M.setup(opts)
  require("neogit").setup(opts)

  vim.api.nvim_create_user_command("NeogitLogRefs", function(command_opts)
    local invalid_refs = vim.tbl_filter(function(ref)
      local result = vim
        .system({ "git", "rev-parse", "--verify", "--quiet", ref .. "^{commit}" }, {
          text = true,
        })
        :wait()

      return result.code ~= 0
    end, command_opts.fargs)

    if #invalid_refs > 0 then
      vim.notify("NeogitLogRefs: invalid git ref(s): " .. table.concat(invalid_refs, ", "), vim.log.levels.ERROR)
      return
    end

    local args = vim.list_extend(vim.deepcopy(command_opts.fargs), {
      "--graph",
      "--decorate",
      "--color",
    })

    require("neogit").action("log", "log_current", args)()
  end, {
    nargs = "+",
    desc = "Open a Neogit graph for the specified refs",
    complete = function(arg_lead)
      return vim.tbl_filter(function(ref)
        return vim.startswith(ref, arg_lead)
      end, require("neogit.lib.git").refs.list_branches())
    end,
  })

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

  require("config.neogit_compat").setup()
end
return M
