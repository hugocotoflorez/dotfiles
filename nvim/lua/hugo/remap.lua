vim.g.mapleader = " "

vim.keymap.set("n", "<leader>w", ":wall<CR>")
vim.keymap.set("n", "<leader>q", ":wall<CR>:qall<CR>")

vim.keymap.set("n", "<leader>tp", ":lua require(\"precognition\").toggle()<cr>:HardTimeToggle<cr>")
vim.keymap.set("n", "<leader>c", "_i//<Esc>_")
vim.keymap.set("v", "<leader>c", "c/*\n/<Esc>kp")

vim.keymap.set("n", "<leader>tt", ":lua toggle_transparency()<CR>")

vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
vim.keymap.set("n", "J", "mzJ`z")

vim.keymap.set("n", "md", ":Markview<CR>")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

-- greatest remap ever
vim.keymap.set("x", "<leader>p", [["_dP]])

-- next greatest remap ever : asbjornHaland
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({"n", "v"}, "<leader>d", [["_d]])
vim.keymap.set("n", "<C-a>", "ggVG")

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<leader><leader>", vim.lsp.buf.format)

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })
vim.keymap.set("n", "<leader>r", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])


vim.keymap.set("n", "<leader>tt", ":lua toggle_transparency()<CR>")

vim.keymap.set('x', '<leader>r', ':<C-u>lua InputReplace()<CR>', { noremap = true, silent = true })

function InputReplace()
  local old_word = vim.fn.input('Replace: ')
  local new_word = vim.fn.input('With: ', old_word)
  vim.cmd('\'<,\'>s/' .. old_word .. '/' .. new_word .. '/gI')
end

