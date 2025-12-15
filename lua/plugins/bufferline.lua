return {
  'akinsho/bufferline.nvim', 
  version = "*", 
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = function()
    require('bufferline').setup({
      options = {
        left_mouse_command = false,
        right_mouse_command = false,
        indicator = {
          style = "underline"
        }
      }
    })
  end
}
