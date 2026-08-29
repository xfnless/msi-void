local map = vim.keymap.set

local opts = { noremap = true, silent = true }

local function mapdesc(mode, lhs, rhs, desc, extra)
	local o = vim.tbl_extend("force", opts, extra or {}, { desc = desc })
	map(mode, lhs, rhs, o)
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--------------------------------------------------
-- basic options
--------------------------------------------------
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.backspace = "indent,eol,start"

vim.o.undofile = true
vim.o.swapfile = false
vim.o.autoread = true
vim.o.clipboard = "unnamedplus"

vim.o.termguicolors = true
vim.o.wrap = false
vim.o.signcolumn = "yes"
vim.o.hlsearch = true

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.completeopt = "menuone,noselect,popup"
vim.o.wildmode = "lastused:full,full"
vim.o.grepprg = "rg --vimgrep"
vim.opt.wildignore:append({ "*.o", "*.a", "*.class", ".cache/*" })
vim.opt.wildignorecase = true

-- vim.opt.list = true
-- vim.opt.listchars = {
-- 	space = "·",
-- 	tab = "» ",
-- 	trail = "·",
-- }

--------------------------------------------------
-- autocmds
--------------------------------------------------
local core_group = vim.api.nvim_create_augroup("minimal_core", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
	group = core_group,
	callback = function(args)
		local dir = vim.fn.fnamemodify(args.file, ":p:h")
		vim.fn.mkdir(dir, "p")
	end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
	group = core_group,
	callback = function()
		vim.hl.on_yank({ timeout = 300 })
	end,
})

--------------------------------------------------
-- plugins
--------------------------------------------------
vim.pack.add({
	"https://github.com/nvim-mini/mini.pairs",
	"https://github.com/y9san9/y9nika.nvim",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
	"https://github.com/ibhagwan/fzf-lua",
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/MunifTanjim/nui.nvim",
	{
		src = "https://github.com/nvim-neo-tree/neo-tree.nvim",
		version = vim.version.range("3"),
	},
	"https://codeberg.org/andyg/leap.nvim",
	"https://github.com/nvim-mini/mini.comment",
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/jpe90/export-colorscheme.nvim",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/stevearc/conform.nvim",
})

--------------------------------------------------
-- filetype
--------------------------------------------------
vim.filetype.add({
	filename = {
		[".bashrc"] = "bash",
		[".bash_profile"] = "bash",
		[".bash_login"] = "bash",
		[".profile"] = "sh",
		[".bash_logout"] = "bash",
		[".bash_aliases"] = "bash",
		[".env"] = "sh",
		["Dockerfile"] = "dockerfile",
		["Containerfile"] = "dockerfile",
	},
	extension = {
		astro = "astro",
		gql = "graphql",
		graphql = "graphql",
		mdx = "markdown.mdx",
		svelte = "svelte",
	},
	pattern = {
		[".*%.env%..*"] = "sh",
	},
})

--------------------------------------------------
-- plugin setup
--------------------------------------------------
require("nvim-treesitter").setup({
	install_dir = vim.fn.stdpath("data") .. "/site",
})

local treesitter_languages = {
	"astro",
	"bash",
	"css",
	"dockerfile",
	"gitignore",
	"graphql",
	"html",
	"javascript",
	"jsdoc",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"python",
	"query",
	"regex",
	"scss",
	"sql",
	"svelte",
	"toml",
	"tsx",
	"typescript",
	"vim",
	"vimdoc",
	"vue",
	"yaml",
}

require("nvim-treesitter").install(treesitter_languages)

pcall(vim.treesitter.language.register, "markdown", { "markdown.mdx" })

local treesitter_filetypes = {
	"astro",
	"bash",
	"css",
	"dockerfile",
	"gitignore",
	"graphql",
	"html",
	"javascript",
	"javascriptreact",
	"json",
	"jsonc",
	"lua",
	"markdown",
	"markdown.mdx",
	"python",
	"scss",
	"sh",
	"sql",
	"svelte",
	"toml",
	"typescript",
	"typescriptreact",
	"vim",
	"vue",
	"yaml",
}

vim.api.nvim_create_autocmd("FileType", {
	group = core_group,
	pattern = treesitter_filetypes,
	callback = function()
		pcall(vim.treesitter.start)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = core_group,
	pattern = {
		"astro",
		"css",
		"graphql",
		"html",
		"javascript",
		"javascriptreact",
		"json",
		"jsonc",
		"less",
		"markdown",
		"markdown.mdx",
		"sass",
		"scss",
		"svelte",
		"typescript",
		"typescriptreact",
		"vue",
		"yaml",
	},
	callback = function()
		vim.bo.tabstop = 2
		vim.bo.shiftwidth = 2
		vim.bo.softtabstop = 2
	end,
})

require("mini.pairs").setup()
require("mini.comment").setup()

require("fzf-lua").setup({})

require("neo-tree").setup({
	close_if_last_window = true,
	filesystem = {
		follow_current_file = {
			enabled = true,
		},
		use_libuv_file_watcher = true,
	},
})

require("which-key").setup({
	preset = "classic",
	icons = {
		mappings = false,
	},
	plugins = {
		marks = true,
		registers = true,
		spelling = {
			enabled = true,
			suggestions = 20,
		},
		presets = {
			operators = false,
			motions = false,
			text_objects = false,
			windows = false,
			nav = false,
			z = false,
			g = false,
		},
	},
	win = {
		no_overlap = false,
		height = { min = 4, max = 30 },
		padding = { 0, 1 },
		title = false,
	},
	layout = {
		width = { min = 12, max = 24 },
		spacing = 1,
	},
	expand = 1,
})

local wk = require("which-key")
wk.add({
	{ "<leader>c", group = "code" },
	{ "<leader>x", group = "lists" },
	{ "<leader>y", group = "yank" },

	{ "gc", desc = "toggle comment", mode = { "n", "x" } },
	{ "gcc", desc = "toggle comment line", mode = "n" },
})

require("conform").setup({
	formatters_by_ft = {
		astro = { "prettier" },
		css = { "prettier" },
		graphql = { "prettier" },
		html = { "prettier" },
		javascript = { "prettier" },
		javascriptreact = { "prettier" },
		json = { "prettier" },
		jsonc = { "prettier" },
		less = { "prettier" },
		lua = { "stylua" },
		markdown = { "prettier" },
		["markdown.mdx"] = { "prettier" },
		sass = { "prettier" },
		scss = { "prettier" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		svelte = { "prettier" },
		typescript = { "prettier" },
		typescriptreact = { "prettier" },
		vue = { "prettier" },
		yaml = { "prettier" },
	},
	default_format_opts = {
		timeout_ms = 1000,
		lsp_format = "fallback",
	},
	notify_on_error = true,
	notify_no_formatters = true,
})

vim.o.background = "light"
vim.cmd.colorscheme("y9nika")

local leap = require("leap")

--------------------------------------------------
-- helper functions
--------------------------------------------------
local function toggle_loclist()
	local winid = vim.fn.getloclist(0, { winid = 0 }).winid
	if winid > 0 then
		vim.cmd("lclose")
	else
		vim.diagnostic.setloclist({ open = true })
	end
end

local function toggle_quickfix()
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win.quickfix == 1 then
			vim.cmd("cclose")
			return
		end
	end
	vim.cmd("copen")
end

--------------------------------------------------
-- keymaps: core
--------------------------------------------------
mapdesc("n", "<leader>w", "<cmd>w<cr>", "write file")
mapdesc("n", "q", "<cmd>bd<cr>", "close buffer")
mapdesc("n", "<leader>q", "q", "record macro")

mapdesc("n", "<leader>yf", function()
	vim.fn.setreg('"', vim.fn.expand("%:t"))
end, "yank filename")

--------------------------------------------------
-- keymaps: search / files
--------------------------------------------------
mapdesc("n", "<leader>f", function()
	require("fzf-lua").files()
end, "find files")

mapdesc("n", "<leader>g", function()
	require("fzf-lua").live_grep()
end, "live grep")

mapdesc("x", "<leader>g", function()
	require("fzf-lua").grep_visual()
end, "grep selection")

mapdesc("n", "<leader>F", function()
	require("fzf-lua").oldfiles()
end, "recent files")

mapdesc("n", "<leader>R", function()
	require("fzf-lua").resume()
end, "resume picker")

mapdesc("n", "gb", function()
	local filename = vim.fn.expand("%:t")
	if filename == "" then
		return
	end
	require("fzf-lua").grep({ search = filename })
end, "grep current filename in project")

mapdesc("n", "<leader>e", "<cmd>Neotree toggle reveal<cr>", "toggle file explorer")

--------------------------------------------------
-- keymaps: buffers / diagnostics / lists
--------------------------------------------------
mapdesc("n", "<leader>h", "<cmd>bprevious<cr>", "previous buffer")
mapdesc("n", "<leader>l", "<cmd>bnext<cr>", "next buffer")

mapdesc("n", "[d", function()
	vim.diagnostic.goto_prev()
end, "previous diagnostic")
mapdesc("n", "]d", function()
	vim.diagnostic.goto_next()
end, "next diagnostic")

mapdesc("n", "<leader>xl", toggle_loclist, "toggle location list")
mapdesc("n", "<leader>xq", toggle_quickfix, "toggle quickfix list")

mapdesc("n", "<leader>b", function()
	require("fzf-lua").buffers()
end, "pick buffers")

--------------------------------------------------
-- keymaps: comment
--------------------------------------------------
mapdesc("n", "<leader>/", function()
	local line = vim.fn.line(".")
	require("mini.comment").toggle_lines(line, line)
end, "toggle comment line")

mapdesc("x", "<leader>/", function()
	local l1 = vim.fn.line("v")
	local l2 = vim.fn.line(".")
	if l1 > l2 then
		l1, l2 = l2, l1
	end
	require("mini.comment").toggle_lines(l1, l2)
end, "toggle comment selection")

--------------------------------------------------
-- keymaps: terminal / input
--------------------------------------------------
mapdesc("t", "<Esc>", [[<C-\><C-n>]], "terminal normal mode")
mapdesc("i", "<Esc>", [[<Esc><Cmd>silent! call system("fcitx5-remote -c")<CR>]], "escape and close fcitx")
mapdesc("n", "<leader>t", "<cmd>term<cr>", "open terminal")

--------------------------------------------------
-- keymaps: motion
--------------------------------------------------
mapdesc({ "n", "x", "o" }, "s", function()
	leap.leap({ target_windows = { vim.api.nvim_get_current_win() } })
end, "leap in current window")

mapdesc({ "n", "x", "o" }, "S", function()
	leap.leap({ target_windows = vim.api.nvim_list_wins() })
end, "leap in all windows")

------------------------------------------------------------
-- LSP
------------------------------------------------------------

vim.diagnostic.config({
	virtual_text = true,
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

local function executable(cmd)
	return vim.fn.executable(cmd) == 1
end

local function enable_if(cmd, server)
	if executable(cmd) then
		vim.lsp.enable(server)
	end
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = core_group,
	callback = function(args)
		local bufnr = args.buf
		local client = vim.lsp.get_client_by_id(args.data.client_id)

		local lsp_map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, {
				buffer = bufnr,
				silent = true,
				desc = desc,
			})
		end

		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
			vim.lsp.completion.enable(true, client.id, bufnr, {
				autotrigger = true,
			})
			lsp_map("i", "<C-x><C-o>", function()
				vim.lsp.completion.get()
			end, "trigger completion")
		end

		lsp_map("n", "gd", vim.lsp.buf.definition, "LSP definition")
		lsp_map("n", "gD", vim.lsp.buf.declaration, "LSP declaration")
		lsp_map("n", "gr", vim.lsp.buf.references, "LSP references")
		lsp_map("n", "gi", vim.lsp.buf.implementation, "LSP implementation")
		lsp_map("n", "K", vim.lsp.buf.hover, "LSP hover")
		lsp_map("n", "<leader>rn", vim.lsp.buf.rename, "LSP rename")
		lsp_map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP code action")
		lsp_map("n", "gl", vim.diagnostic.open_float, "Diagnostic float")
		lsp_map("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
		lsp_map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
		lsp_map("n", "<leader>ce", function()
			vim.lsp.buf.code_action({
				apply = true,
				context = {
					only = { "source.fixAll.eslint" },
					diagnostics = {},
				},
			})
		end, "ESLint fix all")

		if client and (client.name == "ts_ls" or client.name == "eslint") then
			client.server_capabilities.documentFormattingProvider = false
			client.server_capabilities.documentRangeFormattingProvider = false
		end
	end,
})

------------------------------------------------------------
-- Server overrides
------------------------------------------------------------

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
				library = vim.api.nvim_get_runtime_file("", true),
			},
			telemetry = {
				enable = false,
			},
		},
	},
})

vim.lsp.config("eslint", {
	before_init = function(_, config)
		local root_dir = config.root_dir

		if root_dir then
			config.settings = config.settings or {}
			config.settings.workspaceFolder = {
				uri = vim.uri_from_fname(root_dir),
				name = vim.fn.fnamemodify(root_dir, ":t"),
			}
		end
	end,

	settings = {
		validate = "on",
		packageManager = "npm",
		useESLintClass = false,
		run = "onType",
		quiet = false,
		format = false,
		onIgnoredFiles = "off",

		workingDirectory = {
			mode = "auto",
		},

		codeAction = {
			disableRuleComment = {
				enable = true,
				location = "separateLine",
			},
			showDocumentation = {
				enable = true,
			},
		},

		codeActionOnSave = {
			enable = false,
			mode = "all",
		},

		problems = {
			shortenToSingleLine = false,
		},
	},
})

local function npm_global_package(name)
	if not executable("npm") then
		return nil
	end

	local result = vim.system({ "npm", "root", "-g" }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end

	local path = vim.trim(result.stdout) .. "/" .. name
	if vim.fn.isdirectory(path) == 1 then
		return path
	end

	return nil
end

local vue_language_server_path = npm_global_package("@vue/language-server")

if vue_language_server_path then
	vim.lsp.config("ts_ls", {
		init_options = {
			plugins = {
				{
					name = "@vue/typescript-plugin",
					location = vue_language_server_path,
					languages = { "vue" },
					configNamespace = "typescript",
				},
			},
		},
		filetypes = {
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"vue",
		},
	})
end

vim.lsp.config("emmet_language_server", {
	filetypes = {
		"astro",
		"css",
		"html",
		"javascriptreact",
		"less",
		"sass",
		"scss",
		"svelte",
		"typescriptreact",
		"vue",
	},
})

vim.lsp.config("tailwindcss", {
	settings = {
		tailwindCSS = {
			classAttributes = {
				"class",
				"className",
				"class:list",
				"classList",
				"ngClass",
			},
		},
	},
})

vim.lsp.config("yamlls", {
	settings = {
		yaml = {
			keyOrdering = false,
		},
	},
})

------------------------------------------------------------
-- Enable servers
------------------------------------------------------------

enable_if("typescript-language-server", "ts_ls")
enable_if("vscode-eslint-language-server", "eslint")
enable_if("vscode-html-language-server", "html")
enable_if("vscode-css-language-server", "cssls")
enable_if("vscode-json-language-server", "jsonls")
enable_if("vue-language-server", "vue_ls")
enable_if("tailwindcss-language-server", "tailwindcss")
enable_if("emmet-language-server", "emmet_language_server")
enable_if("yaml-language-server", "yamlls")
enable_if("svelte-language-server", "svelte")
enable_if("astro-ls", "astro")
enable_if("lua-language-server", "lua_ls")
enable_if("bash-language-server", "bashls")
enable_if("sql-language-server", "sqlls")

------------------------------------------------------------
-- Format
------------------------------------------------------------

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
	require("conform").format({
		async = false,
		timeout_ms = 1000,
		lsp_format = "fallback",
	})
end, {
	desc = "Format current file",
})
