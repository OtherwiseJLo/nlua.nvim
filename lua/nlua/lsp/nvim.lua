local cache_location = vim.fn.stdpath('cache')
local bin_folder = jit.os

local library = {}

local path = vim.split(package.path, ";")

-- this is the ONLY correct way to setup your path
table.insert(path, "lua/?.lua")
table.insert(path, "lua/?/init.lua")

local function add(lib)
    for _, p in pairs(vim.fn.expand(lib, false, true)) do
        p = vim.loop.fs_realpath(p)
        library[p] = true
    end
end

-- add runtime
add("$VIMRUNTIME")

-- add your config
add("~/.config/nvim")

-- add plugins
-- if you're not using packer, then you might need to change the paths below
-- add("~/.local/share/nvim/site/pack/packer/opt/*")
add("~/.local/share/nvim/site/pack/packer/start/*")

local nlua_nvim_lsp = {
    base_directory = string.format("%s/nlua/sumneko_lua/lua-language-server/",
                                   cache_location),

    bin_location = string.format(
        "%s/nlua/sumneko_lua/lua-language-server/bin/%s/lua-language-server",
        cache_location, bin_folder)
}

local sumneko_command = function()
    return {
        nlua_nvim_lsp.bin_location, "-E",
        string.format("%s/main.lua", nlua_nvim_lsp.base_directory)
    }
end

local function get_lua_runtime()
    local result = {};
    for _, path in pairs(vim.api.nvim_list_runtime_paths()) do
        local lua_path = path .. "/lua/";
        if vim.fn.isdirectory(lua_path) then result[lua_path] = true end
    end

    -- This loads the `lua` files from nvim into the runtime.
    result[vim.fn.expand("$VIMRUNTIME/lua")] = true

    -- TODO: Figure out how to get these to work...
    --  Maybe we need to ship these instead of putting them in `src`?...
    result[vim.fn.expand("~/build/neovim/src/nvim/lua")] = true

    return result;
end

nlua_nvim_lsp.setup = function(nvim_lsp, config)
    local cmd = config.cmd or sumneko_command()
    local executable = cmd[1]

    if vim.fn.executable(executable) == 0 then
        print("Could not find sumneko executable:", executable)
        return
    end

    if vim.fn.filereadable(cmd[3]) == 0 then
        print("Could not find resulting build files", cmd[3])
        return
    end

    nvim_lsp.sumneko_lua.setup({
        -- delete root from workspace to make sure we don't trigger duplicate warnings
        on_new_config = function(config, root)
            local libs = vim.tbl_deep_extend("force", {}, library)
            libs[root] = nil
            config.settings.Lua.workspace.library = libs
            return config
        end,
        cmd = cmd,

        -- Lua LSP configuration
        settings = {
            Lua = {
                runtime = {
                    version = "LuaJIT",
                    -- Path setup
                    path = path
                },

                completion = {
                    -- You should use real snippets
                    keywordSnippet = "Disable"
                },

                diagnostics = {
                    enable = true,
                    disable = config.disabled_diagnostics or {"trailing-space"},
                    globals = vim.list_extend(
                        {
                            -- Neovim
                            "vim", -- Busted
                            "describe", "it", "before_each", "after_each",
                            "teardown", "pending", "clear"
                        }, config.globals or {})
                },

                workspace = {
                    library = library,
                    maxPreload = 1000,
                    preloadFileSize = 1000
                }
            }
        },

        -- Runtime configurations
        filetypes = {"lua"},

        on_attach = config.on_attach,
        handlers = config.handlers
    })
end

nlua_nvim_lsp.hover = function() vim.lsp.buf.hover() end

return nlua_nvim_lsp
