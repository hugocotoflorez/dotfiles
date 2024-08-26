local c = {
    bg       = '#282c34', -- Color de fondo.
    fg       = '#abb2bf', -- Color de texto principal.
    black    = '#1e2127', -- Color negro (para fondo oscuro y línea de comandos).
    red      = '#e06c75', -- Color rojo (para tipos de datos y errores).
    green    = '#98c379', -- Color verde (para cadenas de texto).
    yellow   = '#e5c07b', -- Color amarillo (para valores como números y caracteres).
    blue     = '#61afef', -- Color azul (para nombres de funciones).
    magenta  = '#c678dd', -- Color magenta (para palabras clave y directivas de preprocesador).
    cyan     = '#56b6c2', -- Color cian (para identificadores y operadores).
    white    = '#abb2bf', -- Color blanco (para variables, puntos, comas, flechas).
    br_black = '#5c6370', -- Color negro brillante (para números de línea).
    br_white = '#ffffff', -- Color blanco brillante (para resaltar elementos importantes).
}

-- Normal y ventanas flotantes
vim.api.nvim_set_hl(0, "Normal", { fg = c.fg, bg = c.bg })           -- Texto normal con fondo especificado.
vim.api.nvim_set_hl(0, "NormalFloat", { fg = c.fg, bg = c.black })   -- Texto en ventanas flotantes con fondo negro.
vim.api.nvim_set_hl(0, "FloatBorder", { fg = c.blue, bg = c.black }) -- Bordes de ventanas flotantes con azul para destacar.

-- Pmenu para ventanas flotantes
vim.api.nvim_set_hl(0, "Pmenu", { fg = c.white, bg = c.black })   -- Menú flotante de autocompletado.
vim.api.nvim_set_hl(0, "PmenuSel", { fg = c.black, bg = c.blue }) -- Selección en el menú flotante.
vim.api.nvim_set_hl(0, "PmenuSbar", { bg = c.br_black })          -- Barra de desplazamiento en el menú flotante.
vim.api.nvim_set_hl(0, "PmenuThumb", { bg = c.blue })             -- "Thumb" de la barra de desplazamiento.

-- Fondo transparente para componentes adicionales
vim.api.nvim_set_hl(0, "Whitespace", { fg = c.br_black, bg = "NONE" }) -- Espacios en blanco visibles.
vim.api.nvim_set_hl(0, "NonText", { fg = c.br_black, bg = "NONE" })    -- Caracteres no textuales como el `~` al final de las líneas vacías.
vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = c.bg, bg = "NONE" })      -- Oculta el `~` en las líneas vacías.

-- Línea de comandos y separadores
vim.api.nvim_set_hl(0, "StatusLine", { fg = c.white, bg = c.black })      -- Línea de estado.
vim.api.nvim_set_hl(0, "StatusLineNC", { fg = c.br_black, bg = c.black }) -- Línea de estado inactiva.
vim.api.nvim_set_hl(0, "VertSplit", { fg = c.br_black, bg = c.black })    -- Separación vertical entre ventanas.
vim.api.nvim_set_hl(0, "WinSeparator", { fg = c.br_black, bg = c.bg })    -- Separadores de ventana.

-- Pestañas
vim.api.nvim_set_hl(0, "TabLine", { fg = c.white, bg = c.black })        -- Línea de pestañas.
vim.api.nvim_set_hl(0, "TabLineSel", { fg = c.blue, bg = c.br_black })   -- Pestaña seleccionada.
vim.api.nvim_set_hl(0, "TabLineFill", { fg = c.br_black, bg = c.black }) -- Relleno de la línea de pestañas.

-- Palabras clave y directivas de preprocesador
vim.api.nvim_set_hl(0, "PreProc", { fg = c.magenta, italic = true })     -- Directivas del preprocesador.
vim.api.nvim_set_hl(0, "Keyword", { fg = c.magenta, italic = true })     -- Palabras clave como `for`, `while`, `if`.
vim.api.nvim_set_hl(0, "Conditional", { fg = c.magenta, italic = true }) -- Condicionales como `if`, `else`.
vim.api.nvim_set_hl(0, "Repeat", { fg = c.magenta, italic = true })      -- Bucles como `for`, `while`.

-- Nombres de funciones y operadores
vim.api.nvim_set_hl(0, "Function", { fg = c.blue }) -- Nombres de funciones.
vim.api.nvim_set_hl(0, "Operator", { fg = c.white})  -- Operadores como `+`, `-`, `=`.

-- Tipos de datos y valores
vim.api.nvim_set_hl(0, "Type", { fg = c.white, bold = true })        -- Tipos de datos como `int`, `char`, y tipos antes de una función.
vim.api.nvim_set_hl(0, "Number", { fg = c.yellow })                -- Números.
vim.api.nvim_set_hl(0, "Character", { fg = c.yellow })             -- Caracteres individuales.
vim.api.nvim_set_hl(0, "Boolean", { fg = c.yellow })               -- Literales booleanos.
vim.api.nvim_set_hl(0, "Constant", { fg = c.yellow, bold = true }) -- Constantes generales.

-- Variables, identificadores y delimitadores
vim.api.nvim_set_hl(0, "Variable", { fg = c.white })   -- Variables.
vim.api.nvim_set_hl(0, "Identifier", { fg = c.white}) -- Identificadores como nombres de variables.
vim.api.nvim_set_hl(0, "Delimiter", { fg = c.white })  -- Delimitadores como `;`, `,`, `.`.

-- Cadenas de texto
vim.api.nvim_set_hl(0, "String", { fg = c.green }) -- Literales de cadena.

-- Comentarios y documentación
vim.api.nvim_set_hl(0, "Comment", { fg = c.br_black, italic = true })    -- Comentarios en el código.
vim.api.nvim_set_hl(0, "DocComment", { fg = c.br_black, italic = true }) -- Comentarios de documentación.

-- Números de línea
vim.api.nvim_set_hl(0, "LineNr", { fg = c.br_black })                 -- Números de línea.
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = c.white, bold = true }) -- Número de línea actual resaltado.

-- Comentarios `TODO`, `FIXME`, etc.
vim.api.nvim_set_hl(0, "Todo", { fg = c.green, italic = true }) -- Comentarios `TODO`.
vim.api.nvim_set_hl(0, "Debug", { fg = c.red, italic = true })  -- Declaraciones de depuración.

-- Títulos y negrita
vim.api.nvim_set_hl(0, "Title", { fg = c.blue, bold = true }) -- Títulos de ventanas.
vim.api.nvim_set_hl(0, "Bold", { bold = true })               -- Negrita para cualquier texto.

-- Configuración de Treesitter
vim.api.nvim_set_hl(0, "@function", { fg = c.blue })                           -- Nombres de funciones.
vim.api.nvim_set_hl(0, "@method", { fg = c.blue })                             -- Métodos de objetos.
vim.api.nvim_set_hl(0, "@keyword.function", { fg = c.magenta, italic = true }) -- Palabras clave de funciones.
vim.api.nvim_set_hl(0, "@parameter", { fg = c.yellow})                          -- Parámetros de funciones.
vim.api.nvim_set_hl(0, "@keyword", { fg = c.magenta, italic = true })          -- Palabras clave generales.
vim.api.nvim_set_hl(0, "@variable", { fg = c.red})                          -- Variables.
vim.api.nvim_set_hl(0, "@constant", { fg = c.yellow, bold = true })                         -- Constantes.
vim.api.nvim_set_hl(0, "@string", { fg = c.green })                            -- Cadenas de texto.
vim.api.nvim_set_hl(0, "@number", { fg = c.yellow})                           -- Números.
vim.api.nvim_set_hl(0, "@operator", { fg = c.white})                            -- Operadores.
vim.api.nvim_set_hl(0, "@type", { fg = c.white, bold = true })  -- Tipos de datos.
vim.api.nvim_set_hl(0, "@type.builtin", { fg = c.white, bold = true })           -- Tipos de datos.
vim.api.nvim_set_hl(0, "@tag", { fg = c.yellow})                                -- Etiquetas como las de HTML.
vim.api.nvim_set_hl(0, "@tag.attribute", { fg = c.yellow })                    -- Atributos en etiquetas HTML.

-- Configuración de LSP
vim.api.nvim_set_hl(0, "LspReferenceText", { bg = c.br_black })                     -- Resaltar referencias de texto.
vim.api.nvim_set_hl(0, "LspReferenceRead", { bg = c.br_black })                     -- Resaltar referencias de lectura.
vim.api.nvim_set_hl(0, "LspReferenceWrite", { bg = c.br_black })                    -- Resaltar referencias de escritura.
vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", { fg = c.bg, bg = c.yellow }) -- Parámetro activo en la firma de la función.
