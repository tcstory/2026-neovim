return {
  'akinsho/bufferline.nvim',
  version = "*",
  event = "VeryLazy",
  dependencies = 'nvim-tree/nvim-web-devicons',
  keys = {
    { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" }, 
  },
  config = function()
    require('bufferline').setup({
      options = {
        indicator = {
          style = "underline"
        },
        offsets = {
          {
            filetype = "snacks_layout_box",
            text = "Explorer",
            text_align = "left",
            separator = true,
          },
        },
      }
    })
  end
}
