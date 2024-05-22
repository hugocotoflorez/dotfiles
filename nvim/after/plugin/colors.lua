require('kanagawa')

transparency=false

function colorAll(color)
	color = color or "kanagawa-wave"
	vim.cmd.colorscheme(color)
end


function toggle_transparency()
    if (transparency) then
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
        vim.api.nvim_set_hl(0, "Normalfloat", { bg = "none" })
    else
        colorAll()
    end
    transparency = not transparency

end

colorAll()
toggle_transparency()
