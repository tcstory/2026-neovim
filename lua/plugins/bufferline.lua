return {
  'akinsho/bufferline.nvim',
  version = "*",
  event = "VeryLazy",
  dependencies = 'nvim-tree/nvim-web-devicons',
  keys = {
    { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "buffer line cycle next" },
    { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "buffer line cycle prev" }, 
  },
  config = function()
    require('bufferline').setup({
      options = {
        indicator = {
          style = "underline"
        }
      }
    })
  end
}
