return {
  {
    name = "native-fcitx5-rime",
    dir = vim.fn.stdpath("config") .. "/lua/fcitx",
    event = "VeryLazy",
    config = function()
      require("fcitx").setup()
    end,
  },
}
