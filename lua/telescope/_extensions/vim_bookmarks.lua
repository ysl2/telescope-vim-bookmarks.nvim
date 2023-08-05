local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local entry_display = require('telescope.pickers.entry_display')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')

local utils = require('telescope.utils')

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local bookmark_actions = require('telescope._extensions.vim_bookmarks.actions')

local function get_bookmarks(files, opts)
    opts = opts or {}
    local bookmarks = {}

    for _,file in ipairs(files) do
        for _,line in ipairs(vim.fn['bm#all_lines'](file)) do
            local bookmark = vim.fn['bm#get_bookmark_by_line'](file, line)

            local text = bookmark.annotation ~= "" and "Annotation: " .. bookmark.annotation or bookmark.content
            if text == "" then
                text = "(empty line)"
            end

            local only_annotated = opts.only_annotated or false

            if not (only_annotated and bookmark.annotation == "") then
                table.insert(bookmarks, {
                    filename = file,
                    lnum = tonumber(line),
                    col=bookmark.col_nr,
                    text = text,
                    sign_idx = bookmark.sign_idx,
                })
            end
        end
    end

    table.sort(bookmarks, function(a, b)
      if (not a or not b) or (a.filename == b.filename and a.lnum == b.lnum) then
        return false
      end
      if a.filename ~= b.filename then
        local f = { a.filename, b.filename }
        table.sort(f)
        return (f[1] == a.filename)
      end
      return (a.lnum < b.lnum)
    end)

    return bookmarks
end

local function make_entry_from_bookmarks(opts)
    opts = opts or {}
    opts.tail_path = vim.F.if_nil(opts.tail_path, true)

    local displayer = entry_display.create {
        separator = "▏",
        items = {
            { width = opts.width_line or 5 },
            { width = opts.width_text or 60 },
            { remaining = true }
        }
    }

    local make_display = function(entry)
        local filename
        if not opts.path_display then
            filename = entry.filename
            if opts.tail_path then
                filename = utils.path_tail(filename)
            elseif opts.shorten_path then
                filename = utils.path_shorten(filename)
            end
        end

        local line_info = {entry.lnum, "TelescopeResultsLineNr"}

        return displayer {
            line_info,
            entry.text:gsub(".* | ", ""),
            filename,
        }
    end

    return function(entry)
        return {
            valid = true,

            value = entry,
            ordinal = (
            not opts.ignore_filename and filename
            or ''
            ) .. ' ' .. entry.text,
            display = make_display,

            filename = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
            text = entry.text,
        }
    end
end

local function make_bookmark_picker(filenames, opts)
    opts = opts or {}
    opts = vim.tbl_deep_extend('force', opts, { preview = { hide_on_startup = false } })

    local make_finder = function()
        local bookmarks = get_bookmarks(filenames, opts)

        if vim.tbl_isempty(bookmarks) then
            print("No bookmarks!")
            return
        end

        return finders.new_table {
            results = bookmarks,
            entry_maker = make_entry_from_bookmarks(opts),
        }
    end

    local initial_finder = make_finder()
    if not initial_finder then return end

    pickers.new(opts, {
        prompt_title = opts.prompt_title or "vim-bookmarks",
        finder = initial_finder,
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(opts),

        attach_mappings = function(prompt_bufnr, map)
            local refresh_picker = function()
                local new_finder = make_finder()
                if new_finder then
                    action_state.get_current_picker(prompt_bufnr):refresh(make_finder())
                else
                    actions.close(prompt_bufnr)
                end
            end

            bookmark_actions.delete_all:enhance { post = refresh_picker }

            map('i', '<C-x>', bookmark_actions.delete)
            map('i', '<A-x>', bookmark_actions.delete_all)

            return true
        end
    }):find()
end

local all = function(opts)
    make_bookmark_picker(vim.fn['bm#all_files'](), opts)
end

local current_file = function(opts)
    opts = opts or {}
    opts = vim.tbl_extend('keep', opts, {path_display = true})

    make_bookmark_picker({vim.fn.expand('%:p')}, opts)
end

return require('telescope').register_extension {
    exports = {
        -- Default when to argument is given, i.e. :Telescope vim_bookmarks
        vim_bookmarks = all,

        all = all,
        current_file = current_file,
        actions = bookmark_actions
    }
}
