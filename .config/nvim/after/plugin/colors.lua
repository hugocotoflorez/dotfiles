require('kanagawa')


function colorAll(color)

	color = color or "kanagawa-wave"
	vim.cmd.colorscheme(color)

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "Normalfloat", { bg = "none" })

end

colorAll()
