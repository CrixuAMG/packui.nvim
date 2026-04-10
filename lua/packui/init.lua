local M = {}
local ui = require("packui.ui")
local pack_path = vim.fn.stdpath("config") .. "/pack/plugins"

local function get_installed_plugins()
    local installed = {}
    local plugin_types = {"start", "opt"}

    for _, type in ipairs(plugin_types) do
        local type_path = pack_path .. "/" .. type
        if vim.fn.isdirectory(type_path) == 1 then
            local plugins = vim.fn.readdir(type_path)
            for _, name in ipairs(plugins) do
                local path = type_path .. "/" .. name
                if vim.fn.isdirectory(path) == 1 then
                    -- Try to get the repo from the plugin's git config
                    local repo = name  -- fallback to directory name
                    local git_config_path = path .. "/.git/config"
                    if vim.fn.filereadable(git_config_path) == 1 then
                        local git_config = vim.fn.readfile(git_config_path)
                        for _, line in ipairs(git_config) do
                            if line:match("^%s*url%s*=") then
                                repo = line:match("^%s*url%s*=%s*(.*)")
                                break
                            end
                        end
                    end
                    table.insert(installed, {
                        name = name,
                        path = path,
                        repo = repo,
                        type = type,
                        status = "Checking...",
                        changelog = {},
                        has_update = false
                    })
                end
            end
        end
    end
    return installed
end

    local function redraw(buf, plugins)
        -- Sort plugins by status priority: Updating > Update failed > Update available > Up to date
        table.sort(plugins, function(a, b)
            local status_priority = {
                ["Updating..."] = 1,
                ["Error"] = 2,
                ["Fetch Failed"] = 2,
                ["Update Available"] = 3,
                ["Up to date"] = 4,
                ["Checking..."] = 5
            }
            local priority_a = status_priority[a.status] or 99
            local priority_b = status_priority[b.status] or 99
            
            if priority_a ~= priority_b then
                return priority_a < priority_b
            end
            return a.name < b.name
        end)

        local display_lines = {}
        local highlights = {}
        local plugin_map = {}
        local ns_id = vim.api.nvim_create_namespace("PackUI")

        -- Static Header
        table.insert(display_lines, "  PackUI Manager")
        table.insert(highlights, {line = 0, start_col = 0, end_col = -1, hl_group = "PackUIHeader"})
        table.insert(display_lines, "  (u)pdate  (U)pdate all  (C)heck  (d)elete  (q)uit")
        table.insert(highlights, {line = 1, start_col = 0, end_col = -1, hl_group = "PackUIChangelog"})
        table.insert(display_lines, string.rep("─", 80))
        table.insert(display_lines, "")

        -- Group plugins by status
        local grouped_plugins = {}
        for _, p in ipairs(plugins) do
            if not grouped_plugins[p.status] then
                grouped_plugins[p.status] = {}
            end
            table.insert(grouped_plugins[p.status], p)
        end

        -- Define section headers and their order
        local sections = {
            {"Updating...", "UPDATING"},
            {"Error", "UPDATE FAILED"},
            {"Fetch Failed", "UPDATE FAILED"},
            {"Update Available", "UPDATE AVAILABLE"},
            {"Up to date", "UP TO DATE"}
        }

        -- Add each section if it has plugins
        for _, section in ipairs(sections) do
            local status = section[1]
            local header = section[2]
            
            if grouped_plugins[status] and #grouped_plugins[status] > 0 then
                -- Add section header
                table.insert(display_lines, "  " .. header)
                table.insert(highlights, {line = #display_lines - 1, start_col = 0, end_col = -1, hl_group = "PackUIHeader"})
                table.insert(display_lines, string.rep("─", 80))
                
                -- Add plugins in this section
                for _, p in ipairs(grouped_plugins[status]) do
                    local p_lines = ui.render_plugin(p)
                    for i, line_data in ipairs(p_lines) do
                        local current_line = #display_lines
                        table.insert(display_lines, line_data.content)
                        if i == 1 then plugin_map[current_line + 1] = p end
                        
                        for _, hl in ipairs(line_data.highlights) do
                            table.insert(highlights, {
                                line = current_line,
                                start_col = hl[1],
                                end_col = hl[2],
                                hl_group = hl[3]
                            })
                        end
                    end
                    table.insert(display_lines, "")
                end
                
                -- Add spacing between sections (except after the last one)
                if status ~= sections[#sections][1] then
                    table.insert(display_lines, "")
                end
            end
        end

        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
        
        for _, hl in ipairs(highlights) do
            vim.api.nvim_buf_add_highlight(buf, ns_id, hl.hl_group, hl.line, hl.start_col, hl.end_col)
        end
        
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
        return plugin_map
    end

function M.open()
    ui.setup_highlights()
    local plugins = get_installed_plugins()
    local buf = vim.api.nvim_create_buf(false, true)
    
    local width = 85
    local height = 28
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width, height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        border = "rounded",
        title = " PackUI v1.0 ", title_pos = "center",
    })

    vim.wo[win].cursorline = true
    local current_plugin_map = redraw(buf, plugins)

    -- Async checks
    for _, p in ipairs(plugins) do
        vim.fn.jobstart({"git", "-C", p.path, "fetch"}, {
            on_exit = function(_, code)
                if code == 0 then
                    vim.fn.jobstart({"git", "-C", p.path, "log", "HEAD..@{u}", "--oneline", "--max-count=4"}, {
                        stdout_buffered = true,
                        on_stdout = function(_, data)
                            local logs = {}
                            for _, line in ipairs(data) do
                                if line ~= "" then table.insert(logs, line:sub(1, 70)) end
                            end
                            p.has_update = #logs > 0
                            p.status = p.has_update and "Update Available" or "Up to date"
                            p.changelog = logs
                            vim.schedule(function()
                                if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end
                            end)
                        end
                    })
                else
                    p.status = "Error"
                    vim.schedule(function() if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end end)
                end
            end
        })
    end

    local function get_plugin_at_cursor() return current_plugin_map[vim.api.nvim_win_get_cursor(win)[1]] end

    local function update_plugin()
        local p = get_plugin_at_cursor()
        if not p then return end
        p.status = "Updating..."
        redraw(buf, plugins)
        vim.fn.jobstart({"git", "-C", p.path, "pull"}, {
            on_exit = function(_, code)
                vim.schedule(function()
                    p.status = code == 0 and "Up to date" or "Error"
                    if code == 0 then p.has_update = false; p.changelog = {} end
                    if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end
                end)
            end
        })
    end

    local function delete_plugin()
        local p = get_plugin_at_cursor()
        if not p or vim.fn.confirm("Delete " .. p.name .. "?", "&Yes\n&No", 2) ~= 1 then return end
        vim.fn.delete(p.path, "rf")
        for i, item in ipairs(plugins) do if item == p then table.remove(plugins, i); break end end
        current_plugin_map = redraw(buf, plugins)
    end

    local function update_all_plugins()
        for _, p in ipairs(plugins) do
            if p.has_update then
                p.status = "Updating..."
                redraw(buf, plugins)
                vim.fn.jobstart({"git", "-C", p.path, "pull"}, {
                    on_exit = function(_, code)
                        vim.schedule(function()
                            p.status = code == 0 and "Up to date" or "Error"
                            if code == 0 then p.has_update = false; p.changelog = {} end
                            if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end
                        end)
                    end
                })
            end
        end
    end

    local function check_for_updates()
        -- Reset all plugins to checking state
        for _, p in ipairs(plugins) do
            p.status = "Checking..."
            p.has_update = false
            p.changelog = {}
        end
        redraw(buf, plugins)
        
        -- Re-run the async checks
        for _, p in ipairs(plugins) do
            vim.fn.jobstart({"git", "-C", p.path, "fetch"}, {
                on_exit = function(_, code)
                    if code == 0 then
                        vim.fn.jobstart({"git", "-C", p.path, "log", "HEAD..@{u}", "--oneline", "--max-count=4"}, {
                            stdout_buffered = true,
                            on_stdout = function(_, data)
                                local logs = {}
                                for _, line in ipairs(data) do
                                    if line ~= "" then table.insert(logs, line:sub(1, 70)) end
                                end
                                p.has_update = #logs > 0
                                p.status = p.has_update and "Update Available" or "Up to date"
                                p.changelog = logs
                                vim.schedule(function()
                                    if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end
                                end)
                            end
                        })
                    else
                        p.status = "Error"
                        vim.schedule(function() if vim.api.nvim_buf_is_valid(buf) then current_plugin_map = redraw(buf, plugins) end end)
                    end
                end
            })
        end
    end

    vim.keymap.set("n", "u", update_plugin, { buffer = buf, silent = true })
    vim.keymap.set("n", "U", update_all_plugins, { buffer = buf, silent = true })
    vim.keymap.set("n", "d", delete_plugin, { buffer = buf, silent = true })
    vim.keymap.set("n", "C", check_for_updates, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, silent = true })
end

function M.setup()
    vim.api.nvim_create_user_command("PackUI", function() M.open() end, {})
end

return M
