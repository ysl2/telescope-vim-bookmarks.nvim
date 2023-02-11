local transform_mod = require('telescope.actions.mt').transform_mod

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

return transform_mod {
    delete = function(prompt_bufnr)
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        current_picker:delete_selection(function(selection)
            vim.fn['bm_sign#del'](selection.filename, tonumber(selection.value.sign_idx))
            vim.fn['bm#del_bookmark_at_line'](selection.filename, tonumber(selection.lnum))
            -- TODO temp fix to be able to delete bookmark from Telescope
            vim.cmd("call BookmarkSave(g:bookmark_auto_save_file, 1)")
        end)
    end,

    delete_all = function(prompt_bufnr)
        vim.cmd('silent! BookmarkClearAll')
    end
}


