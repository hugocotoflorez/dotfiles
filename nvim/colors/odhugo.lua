local c = {
    -- Color de fondo.
    bg       = '#282c35', -- Color de fondo.
    fg       = '#abb2bf', -- Color de texto principal.
    black    = '#1e2127', -- Color negro
    red      = '#e06c75', -- Color rojo
    green    = '#98c379', -- Color verde
    yellow   = '#e5c07b', -- Color amarillo
    blue     = '#61afef', -- Color azul
    magenta  = '#c678dd', -- Color magenta
    cyan     = '#56b6c2', -- Color cian
    white    = '#abb2bf', -- Color blanco
    br_black = '#5c6370', -- Color negro brillante
    br_white = '#ffffff', -- Color blanco brillante
}

local defaults = {
    variables = { fg = c.white },
    types = { fg = c.cyan },
    values = { fg = c.red },
    functions = { fg = c.blue },
    operators = { fg = c.white, bold = true },
    keywords = { fg = c.magenta, italic = true },
    strings = { fg = c.green },
    bg = c.bg -- o "NONE" para transparencia
}

-- Normal y ventanas flotantes
vim.api.nvim_set_hl(0, "Normal", { fg = c.fg, bg = defaults.bg })  -- Texto normal con fondo especificado.
vim.api.nvim_set_hl(0, "NormalFloat", { fg = c.fg, bg = c.black }) -- Texto en ventanas flotantes con fondo negro.
vim.api.nvim_set_hl(0, "FloatBorder", { fg = c.white })            -- Bordes de ventanas flotantes con color blanco.

vim.api.nvim_set_hl(0, "Error", { fg = c.red })                    -- Mensajes de error.
vim.api.nvim_set_hl(0, "WarningMsg", { fg = c.yellow })            -- Mensajes de advertencia.

-- Pmenu para ventanas flotantes
vim.api.nvim_set_hl(0, "Pmenu", { fg = c.fg, bg = c.bg })                   -- Menú flotante de autocompletado.
vim.api.nvim_set_hl(0, "PmenuSel", { fg = c.fg, bg = c.black })             -- Selección en el menú flotante.
vim.api.nvim_set_hl(0, "PmenuSbar", { bg = defaults.bg })                   -- Barra de desplazamiento en el menú flotante.
vim.api.nvim_set_hl(0, "PmenuThumb", { bg = defaults.bg })                  -- "Thumb" de la barra de desplazamiento.
-- Fondo transparente para componentes adicion
vim.api.nvim_set_hl(0, "Whitespace", { fg = c.br_black, bg = defaults.bg }) -- Espacios en blanco visibles.
vim.api.nvim_set_hl(0, "NonText", { fg = c.br_black, bg = defaults.bg })    -- Caracteres no textuales como el `~` al final de las líneas vacías.
vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = c.bg, bg = defaults.bg })      -- Oculta el `~` en las líneas vacías.

-- Línea de comandos y separadores
vim.api.nvim_set_hl(0, "StatusLine", { fg = c.white, bg = c.black })       -- Línea de estado.
vim.api.nvim_set_hl(0, "FoldColumn", { bg = "NONE" })                      -- Columna de plegado con fondo transparente.
vim.api.nvim_set_hl(0, "Folded", { bg = "NONE" })                          -- Texto plegado con fondo transparente.
vim.api.nvim_set_hl(0, "SignColumn", { fg = c.white, bg = defaults.bg })   -- Columna de signos con fondo especificado.
vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#292d35" })                  -- Columna de color para resaltar la columna actual.
vim.api.nvim_set_hl(0, "StatusLineNC", { fg = c.br_black, bg = c.black })  -- Línea de estado inactiva.
vim.api.nvim_set_hl(0, "VertSplit", { fg = c.br_black, bg = c.br_black })  -- Separación vertical entre ventanas.
vim.api.nvim_set_hl(0, "WinSeparator", { fg = c.br_black, bg = c.bg })     -- Separadores de ventana.
vim.api.nvim_set_hl(0, "DiagnosticSignError", { fg = c.red })              -- Signo de error de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticSignWarn", { fg = c.yellow })            -- Signo de advertencia de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticSignInfo", { fg = c.blue })              -- Signo de información de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticSignHint", { fg = c.cyan })              -- Signo de sugerencia de diagnóstico
vim.api.nvim_set_hl(0, "ErrorMsg", { fg = c.red, bg = c.bg, bold = true }) -- Mensajes de error en comandos
vim.api.nvim_set_hl(0, "DiagnosticError", { fg = c.red })                  -- Signo de error de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticWarn", { fg = c.yellow })                -- Signo de advertencia de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = c.blue })                  -- Signo de información de diagnóstico
vim.api.nvim_set_hl(0, "DiagnosticHint", { fg = c.cyan })                  -- Signo de sugerencia de diagnóstico

-- Pestañas
vim.api.nvim_set_hl(0, "TabLine", { fg = c.fg, bg = defaults.bg }) -- Línea de pestañas.
vim.api.nvim_set_hl(0, "TabLineSel", { fg = c.fg, bg = c.black })  -- Pestaña seleccionada.
vim.api.nvim_set_hl(0, "TabLineFill", { fg = c.fg })               -- Relleno de la línea de pestañas.

-- Palabras clave y directivas de preprocesador
vim.api.nvim_set_hl(0, "PreProc", defaults.keywords)     -- Directivas del preprocesador.
vim.api.nvim_set_hl(0, "Keyword", defaults.keywords)     -- Palabras clave como `for`, `while`, `if`.
vim.api.nvim_set_hl(0, "Conditional", defaults.keywords) -- Condicionales como `if`, `else`.
vim.api.nvim_set_hl(0, "Special", { fg = c.fg })         -- Palabras especiales.

-- Nombres de funciones y operadores
vim.api.nvim_set_hl(0, "Function", defaults.functions) -- Nombres de funciones.
vim.api.nvim_set_hl(0, "Operator", defaults.operators) -- Operadores como `+`, `-`, `=`.

-- Tipos de datos y valores
vim.api.nvim_set_hl(0, "Type", defaults.types)                  -- Tipos de datos como `int`, `char`, y tipos antes de una función.
vim.api.nvim_set_hl(0, "Number", defaults.values)               -- Números.
vim.api.nvim_set_hl(0, "Character", defaults.strings)           -- Caracteres individuales.
vim.api.nvim_set_hl(0, "Boolean", defaults.values)              -- Literales booleanos.
vim.api.nvim_set_hl(0, "Constant", { fg = c.red, bold = true }) -- Constantes generales.
vim.api.nvim_set_hl(0, "String", { fg = c.green })              -- Literales de cadena.

-- Variables, identificadores y delimitadores
vim.api.nvim_set_hl(0, "Variable", defaults.variables) -- Variables.
vim.api.nvim_set_hl(0, "Identifier", { fg = c.white }) -- Identificadores como nombres de variables.
vim.api.nvim_set_hl(0, "Delimiter", { fg = c.white })  -- Delimitadores como `;`, `,`, `.`.

-- Comentarios y documentación
vim.api.nvim_set_hl(0, "Comment", { fg = c.br_black, italic = true }) -- Comentarios en el código.
vim.api.nvim_set_hl(0, "DocComment", { fg = c.br_black, italic = true})             -- Comentarios de documentación.

-- Números de línea
vim.api.nvim_set_hl(0, "LineNr", { fg = c.br_black, bg = defaults.bg })                 -- Números de línea.
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = c.white, bold = true, bg = defaults.bg }) -- Número de línea actual resaltado.

-- Comentarios `TODO`, `FIXME`, etc.
vim.api.nvim_set_hl(0, "Todo", { fg = c.green, italic = true }) -- Comentarios `TODO`.
vim.api.nvim_set_hl(0, "Debug", { fg = c.red, italic = true })  -- Declaraciones de depuración.

-- Títulos y negrita
vim.api.nvim_set_hl(0, "Title", { fg = c.blue, bold = true }) -- Títulos de ventanas.
vim.api.nvim_set_hl(0, "Bold", { bold = true })               -- Negrita para cualquier texto.

-- Configuración de Treesitter
vim.api.nvim_set_hl(0, "@function", defaults.functions)          -- Nombres de funciones.
vim.api.nvim_set_hl(0, "@function.macro", defaults.functions)    -- Nombres de funciones.
vim.api.nvim_set_hl(0, "@function.attribute", defaults.keywords) -- Atributos de funciones.
vim.api.nvim_set_hl(0, "@attribute", defaults.keywords)          -- Atributos como `__attribute__`.
vim.api.nvim_set_hl(0, "@method", { fg = c.blue })               -- Métodos de objetos.
vim.api.nvim_set_hl(0, "@keyword.function", defaults.keywords)   -- Palabras clave de funciones.
vim.api.nvim_set_hl(0, "@parameter", defaults.values)            -- Parámetros de funciones.
vim.api.nvim_set_hl(0, "@keyword", defaults.keywords)            -- Palabras clave generales.
vim.api.nvim_set_hl(0, "@variable", defaults.variables)          -- Variables.
vim.api.nvim_set_hl(0, "@constant", { fg = c.red, bold = true }) -- Constantes.
vim.api.nvim_set_hl(0, "@string", { fg = c.green })              -- Cadenas de texto.
vim.api.nvim_set_hl(0, "@number", defaults.values)               -- Números.
vim.api.nvim_set_hl(0, "@operator", defaults.operators)          -- Operadores.
vim.api.nvim_set_hl(0, "@type", defaults.types)                  -- Tipos de datos.
vim.api.nvim_set_hl(0, "@type.builtin", defaults.types)          -- Tipos de datos incorporados.
vim.api.nvim_set_hl(0, "@tag", { fg = c.yellow })                -- Etiquetas como las de HTML.
vim.api.nvim_set_hl(0, "@tag.attribute", { fg = c.yellow })      -- Atributos en etiquetas HTML.

-- Configuración de LSP
vim.api.nvim_set_hl(0, "LspReferenceText", { bg = c.br_black })                            -- Resaltar referencias de texto.
vim.api.nvim_set_hl(0, "LspReferenceRead", { bg = c.br_black })                            -- Resaltar referencias de lectura.
vim.api.nvim_set_hl(0, "LspReferenceWrite", { bg = c.br_black })                           -- Resaltar referencias de escritura.
vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", { fg = c.bg, bg = c.yellow })        -- Parámetro activo en la firma de la función.
vim.api.nvim_set_hl(0, "LspDiagnosticsError", { fg = c.red })                              -- Mensajes de error en LSP.
vim.api.nvim_set_hl(0, "LspDiagnosticsWarning", { fg = c.yellow })                         -- Mensajes de advertencia en LSP.
vim.api.nvim_set_hl(0, "LspDiagnosticsVirtualTextError", { fg = c.red, bg = c.bg })        -- Error en texto virtual
vim.api.nvim_set_hl(0, "LspDiagnosticsVirtualTextWarning", { fg = c.yellow, bg = c.bg })   -- Advertencia en texto virtual
vim.api.nvim_set_hl(0, "LspDiagnosticsVirtualTextInformation", { fg = c.blue, bg = c.bg }) -- Información en texto virtual
vim.api.nvim_set_hl(0, "LspDiagnosticsVirtualTextHint", { fg = c.cyan, bg = c.bg })        -- Sugerencia en texto virtual
vim.api.nvim_set_hl(0, "LspDiagnosticsInformation", { fg = c.blue, bg = c.bg })            -- Información de LSP
vim.api.nvim_set_hl(0, "LspDiagnosticsHint", { fg = c.cyan, bg = c.bg })                   -- Sugerencias de LSP

-- Configuración del color de los comandos y elementos relacionados
vim.api.nvim_set_hl(0, "Cmdline", { bg = c.black, fg = c.fg })       -- Línea de comandos en la parte inferior del editor.
vim.api.nvim_set_hl(0, "CmdlineEnter", { bg = c.black, fg = c.fg })  -- Cuando entras en el modo de línea de comandos.
vim.api.nvim_set_hl(0, "CmdlineChange", { bg = c.black, fg = c.fg }) -- Cuando cambias el texto en la línea de comandos.
vim.api.nvim_set_hl(0, "CmdlinePos", { bg = c.black, fg = c.fg })    -- La posición del cursor en la línea de comandos.
vim.api.nvim_set_hl(0, "CmdlineBlock", { bg = c.black, fg = c.fg })  -- Bloques de texto en la línea de comandos.
vim.api.nvim_set_hl(0, "ModeMsg", { fg = c.blue })                   -- Mensajes de modo (por ejemplo, "INSERT", "NORMAL").
vim.api.nvim_set_hl(0, "MoreMsg", { fg = c.green })                  -- Mensajes de paginación (por ejemplo, "Press ENTER or type command to continue").
vim.api.nvim_set_hl(0, "CmdlinePrompt", { fg = c.blue })             -- Configuración del color del prompt `:` en la línea de comandos.
vim.api.nvim_set_hl(0, "CmdlineInfo", { fg = c.white })              -- Opcional: Configuración del texto de información en la línea de comandos.

-- Mensajes de error y advertencia en pantalla
vim.api.nvim_set_hl(0, "TroubleText", { fg = c.fg, bg = c.bg })           -- Texto en Trouble.
vim.api.nvim_set_hl(0, "TroubleNormal", { fg = c.fg, bg = c.bg })         -- Normal en la ventana de Trouble.
vim.api.nvim_set_hl(0, "TroubleCount", { fg = c.yellow })                 -- Contador en la barra de Trouble.
vim.api.nvim_set_hl(0, "TroubleIcon", { fg = c.blue })                    -- Iconos en Trouble.
vim.api.nvim_set_hl(0, "TroubleIndent", { fg = c.cyan })                  -- Indentación en Trouble.
vim.api.nvim_set_hl(0, "TroubleTextLineNumber", { fg = c.fg, bg = c.bg }) -- Números de línea en Trouble.
vim.api.nvim_set_hl(0, "TroubleError", { fg = c.red, bg = c.bg })         -- Errores en Trouble.
vim.api.nvim_set_hl(0, "TroubleWarning", { fg = c.yellow, bg = c.bg })    -- Advertencias en Trouble.
vim.api.nvim_set_hl(0, "TroubleInformation", { fg = c.blue, bg = c.bg })  -- Información en Trouble.
vim.api.nvim_set_hl(0, "TroubleHint", { fg = c.cyan, bg = c.bg })         -- Sugerencias en Trouble.

vim.api.nvim_set_hl(0, "Visual", { bg = c.black })                        -- Selección en modo visual.
vim.api.nvim_set_hl(0, "VisualNOS", { bg = c.black })                     -- Selección visual en modo normal.

vim.api.nvim_set_hl(0, "DiffAdd", { fg = c.green, bg = c.bg })            -- Diferencias añadidas en modo diff.
vim.api.nvim_set_hl(0, "DiffChange", { fg = c.yellow, bg = c.bg })        -- Diferencias cambiadas en modo diff.
vim.api.nvim_set_hl(0, "DiffDelete", { fg = c.red, bg = c.bg })           -- Diferencias eliminadas en modo diff.
vim.api.nvim_set_hl(0, "DiffText", { fg = c.blue, bg = c.bg })            -- Texto de diferencias en modo diff.

vim.api.nvim_set_hl(0, "TelescopePrompt", { fg = c.fg, bg = c.black })    -- Prompts en Telescope.
vim.api.nvim_set_hl(0, "TelescopeResults", { fg = c.fg, bg = c.bg })      -- Resultados de búsqueda en Telescope.
vim.api.nvim_set_hl(0, "TelescopePreview", { fg = c.fg, bg = c.black })   -- Vista previa en Telescope.

vim.api.nvim_set_hl(0, "GitGutterAdd", { fg = c.green })                  -- Adiciones en el archivo.
vim.api.nvim_set_hl(0, "GitGutterChange", { fg = c.yellow })              -- Cambios en el archivo.
vim.api.nvim_set_hl(0, "GitGutterDelete", { fg = c.red })                 -- Eliminaciones en el archivo.

vim.api.nvim_set_hl(0, "LualineNormal", { fg = c.fg, bg = c.bg })         -- Estado normal en Lualine.
vim.api.nvim_set_hl(0, "LualineInsert", { fg = c.green, bg = c.bg })      -- Estado de inserción en Lualine.
vim.api.nvim_set_hl(0, "LualineVisual", { fg = c.cyan, bg = c.bg })       -- Estado visual en Lualine.

vim.api.nvim_set_hl(0, "NvimTreeFolderIcon", { fg = c.blue })             -- Iconos de carpeta en Nvim-tree.
vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = c.blue })             -- Nombres de carpeta en Nvim-tree.
vim.api.nvim_set_hl(0, "NvimTreeOpenedFolderName", { fg = c.green })      -- Carpeta abierta en Nvim-tree.
vim.api.nvim_set_hl(0, "NvimTreeRootFolder", { fg = c.cyan })             -- Carpeta raíz en Nvim-tree.
vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName", { fg = c.fg })          -- Carpeta vacía en Nvim-tree.
