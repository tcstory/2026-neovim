local M = {}
-- 对应插件 spec 中固定的 commit。升级时运行 tests/config_spec.lua 的 Neogit 用例。
M.commit = "ba2f33b64b996ff5530c4c45a3c432fb63aaa95b"
function M.setup()
  local ok_graph, unicode_graph = pcall(require, "neogit.lib.graph.unicode")
  if not ok_graph or type(unicode_graph.build) ~= "function" then
    vim.notify("Neogit graph API changed; custom graph colors were skipped", vim.log.levels.WARN)
    return
  end
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

  local ok_commit_view, commit_view = pcall(require, "neogit.buffers.commit_view")
  if not ok_commit_view or commit_view._first_parent_merge_patch_applied then
    return
  end

  if type(commit_view.new) ~= "function" or type(commit_view.update) ~= "function" then
    vim.notify("Neogit commit view API changed; merge patch was skipped", vim.log.levels.WARN)
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
    assert(commit_info, "Neogit could not read commit: " .. commit_id)
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
end
return M
