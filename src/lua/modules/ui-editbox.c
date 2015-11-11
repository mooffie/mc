/**
 * An editbox is a multi-line input widget. It is the widget you interact
 * with when you use MC's editor, but you may also @{~mod:ui*Editbox|embed}
 * it in your own dialogs.
 *
 * @classmod ui.Editbox
 */

#include <config.h>

#include "lib/global.h"
#include "lib/widget.h"

#include "src/setup.h"          /* option_tab_spacing */
#include "src/editor/edit.h"
#include "src/editor/editwidget.h"
#include "lib/lua/capi.h"
#include "lib/lua/ui-impl.h"    /* luaUI_*() */
#include "lib/lua/utilx.h"

#include "../modules.h"
#include "fs.h"                 /* luaFS_check_vpath() */


#define UNKNOWN_FORMAT "unknown"        /* copied from "src/editor/syntax.c" (where it's not actually used) */

/* See comment for LUA_TO_BUTTON, in ui.c */
#define LUA_TO_EDITBOX(L, i) ((WEdit *) luaUI_check_widget (L, i))

static void
edit_update_view (WEdit * e)
{
    if (WIDGET (e)->owner)      /* perchance we haven't been added to a dialog yet. */
        edit_update_screen (e);
}

static Widget *
edit_constructor (void)
{
    Widget *w;

    w = WIDGET (edit_init (NULL, 1, 1, 5, 20, NULL, 1));
    /* FIXME: edit_init() itself should do the following. See comment
     * in editwidget.h. And since we don't bother setting w->mouse here as
     * well, we don't have mouse support. */
    w->callback = edit_callback;

    return w;
}

static int
l_edit_new (lua_State * L)
{
    luaUI_push_widget (L, edit_constructor (), FALSE);
    return 1;
}

/**
 * This overrides widget:focus().
 *
 * Editbox sub-windows are focused with dlg_set_top_widget(), not dlg_select_widget().
 */
static int
l_edit_focus (lua_State * L)
{
    Widget *w = luaUI_check_widget (L, 1);

    if (w->owner)
        dlg_set_top_widget (w);

    return 0;
}

/**
 * Modifying
 *
 * @section
 */

/**
 * Inserts a string into the buffer.
 *
 * Inserts text at the cursor location (the cursor then moves forward).
 *
 *    -- Insert the current date and time.
 *    ui.Editbox.bind("C-y", function(edt)
 *      edt:insert(os.date("%Y-%m-%d %H:%M:%S"))
 *    end)
 *
 * @function insert
 * @param s text to insert (may contain null bytes).
 */
static int
l_edit_insert (lua_State * L)
{
    WEdit *edit;
    const char *text;

    size_t len, i;

    edit = LUA_TO_EDITBOX (L, 1);
    text = luaL_checklstring (L, 2, &len);      /* allow for null bytes */

    for (i = 0; i < len; i++)
        edit_insert (edit, (unsigned char) text[i]);

    edit_update_view (edit);

    return 0;
}

/**
 * Deletes text at the cursor location.
 *
 * As an example, here's how to delete the current word (with the help of @{current_word}):
 *
 *    -- Various ways to delete a word.
 *
 *    ui.Editbox.bind('f16', function(edt)
 *      local whole, part = edt:get_current_word()
 *      whole = whole or abort "stand on a word, will ya?"
 *      edt:delete(part:len(), true)
 *      edt:delete(whole:len() - part:len())
 *    end)
 *
 *    ui.Editbox.bind('f16', function(edt)
 *      local whole, part = edt:get_current_word()
 *      whole = whole or abort "stand on a word, will ya?"
 *      edt.cursor_offs = edt.cursor_offs - part:len()
 *      edt:delete(whole:len())
 *    end)
 *
 *    -- For completeness sake, here's how to do it using commands. But this
 *    -- doesn't behave exactly as the above solutions when standing on
 *    -- the beginning/end of the word.
 *
 *    ui.Editbox.bind('f16', function(edt)
 *      edt:command "DeleteToWordBegin"
 *      edt:command "DeleteToWordEnd"
 *    end)
 *
 * @function delete
 * @param count How many **bytes** to delete.
 * @param[opt] backwards Boolean. Whether to "backspace" instead of delete.
 */
static int
l_edit_delete (lua_State * L)
{
    WEdit *edit;
    size_t count;
    gboolean backwards;

    edit = LUA_TO_EDITBOX (L, 1);
    count = luaL_checki (L, 2);
    backwards = lua_toboolean (L, 3);

    while (count > 0)
    {
        if (backwards)
            edit_backspace (edit, TRUE);
        else
            edit_delete (edit, TRUE);
        --count;
    }

    edit_update_view (edit);

    return 0;
}

/**
 * Loads a file into the buffer.
 *
 * (The file does not have to exist.)
 *
 * @function load
 * @args (filepath, [line_number])
 * @return *true* if the file was loaded successfully.
 */
static int
l_edit_load (lua_State * L)
{
    WEdit *edit;
    const vfs_path_t *vpath;
    long line;

    gboolean success;

    edit = LUA_TO_EDITBOX (L, 1);
    vpath = luaFS_check_vpath (L, 2);
    line = luaL_optlong (L, 3, 7);

    /*
     * @todo:
     *
     * To be really useful, the current file should be recorded in the
     * history. This way the user can go back. This is a must for
     * implementing tags utilities.
     *
     * See editcmd_dialogs.c:editcmd_dialog_select_definition_show()
     * and factor its history stuff out.
     */

    success = edit_reload_line (edit, vpath, line);

    edit->force |= REDRAW_COMPLETELY;
    edit_update_view (edit);

    lua_pushboolean (L, success);

    return 1;
}

/**
 * @section end
 */

/**
 * Reading
 *
 * @section
 */

/**
 * Utility: Pushes text from the editbox onto the Lua stack.
 */
static void
luaUI_editbox_pushstring (lua_State * L, WEdit * edit, off_t start, off_t finish)
{
    if (finish > start)
    {
        off_t len, i;
        unsigned char *s;

        len = finish - start;

        s = g_new (unsigned char, len);

        for (i = 0; i < len; i++)
            s[i] = edit_buffer_get_byte (&edit->buffer, start + i);

        lua_pushlstring (L, (char *) s, len);
        g_free (s);
    }
    else
    {
        lua_pushliteral (L, "");
    }
}

/**
 * Fetches a line.
 *
 * [tip]
 *
 * There are three ways to fetch the line on which the cursor stands:
 *
 *    edt:get_line(edt.cursor_line)
 *    edt:get_line()
 *    edt.line
 *
 * (The third way is @{~interface#prop|syntactic sugar} for the
 * second way.)
 *
 * [/tip]
 *
 * @function get_line
 * @param[opt] num The line number. Defaults to the cursor's line.
 * @param[opt] keep_eol Boolean. Whether to keep the EOL at the end.
 */
static int
l_edit_get_line (lua_State * L)
{
    WEdit *edit;
    long line_no;
    gboolean keep_eol;

    off_t start, finish;

    edit = LUA_TO_EDITBOX (L, 1);
    line_no = luaL_optlong (L, 2, edit->buffer.curs_line + 1) - 1;      /* on the Lua side we're 1-based. */
    keep_eol = lua_toboolean (L, 3);

    start = edit_find_line (edit, line_no);
    /* We can't do "finish = edit_find_line (edit, line_no + 1)" as it won't work for the last line. */
    finish = edit_buffer_get_eol (&edit->buffer, start) + (keep_eol ? 1 : 0);
    if (finish > edit->buffer.size)     /* Prevent reporting spurious "\n" on the last line. */
        finish = edit->buffer.size;

    if (!keep_eol)
    {
        /* Remove the CR of DOS lines. */
        if (finish > start && edit_buffer_get_byte (&edit->buffer, finish - 1) == '\r')
            --finish;
    }

    luaUI_editbox_pushstring (L, edit, start, finish);
    return 1;
}

/**
 * Extracts a substring.
 *
 * Extracts a substring from the buffer. The arguments are the same as
 * @{string.sub}'s (negative indices have the same semantics). The indexing
 * is byte-oriented (*not* character-oriented).
 *
 * see @{len}.
 *
 * @function sub
 * @args (i [, j])
 */
static int
l_edit_sub (lua_State * L)
{
    WEdit *edit;
    off_t start;
    off_t finish;

    edit = LUA_TO_EDITBOX (L, 1);
    start = luaL_checki (L, 2);
    finish = luaL_opti (L, 3, -1);

    /* Convert Lua indices to C indices. */
    start = mc_lua_fixup_idx (start, edit->buffer.size, FALSE);
    finish = mc_lua_fixup_idx (finish, edit->buffer.size, TRUE);

    luaUI_editbox_pushstring (L, edit, start, finish);

    return 1;
}

/**
 * The character on which the cursor stands.
 *
 * When called as a method, returns two values.
 *
 * @return The character, as a string.
 * @return The character's numeric code (Unicode, in case of a UTF-8 encoded
 *   buffer).
 *
 * @attr current_char
 * @property r
 */
static int
l_edit_get_current_char (lua_State * L)
{
    WEdit *edit;

    off_t start;

    edit = LUA_TO_EDITBOX (L, 1);

    start = edit->buffer.curs1;

#ifdef HAVE_CHARSET
    if (edit->utf8)
    {
        int char_length;
        int unicode;

        unicode = edit_buffer_get_utf (&edit->buffer, start, &char_length);
        if (char_length > 1)    /* "char_length > 0" would be fine. The "> 1" is optimization. */
        {
            luaUI_editbox_pushstring (L, edit, start, start + char_length);
            lua_pushinteger (L, unicode);
            return 2;
        }
    }
#endif

    {
        unsigned char c;

        c = edit_buffer_get_byte (&edit->buffer, start);
        lua_pushlstring (L, (char *) &c, 1);
        lua_pushinteger (L, c);
        return 2;
    }
}

/**
 * @section end
 */

/**
 * Meta
 *
 * @section
 */

/**
 * Returns the size of the buffer.
 *
 * That is, returns the number of _bytes_ that compose the text.
 *
 * Note: To make the API similar to that of Lua's strings, this is a method,
 * not a property. That is, you do `edt:len()`, not `edt.len`.
 *
 * @function len
 */
static int
l_edit_len (lua_State * L)
{
    lua_pushi (L, LUA_TO_EDITBOX (L, 1)->buffer.size);
    return 1;
}

/**
 * The filename associated with the buffer.
 *
 * Returns **nil** if no filename is associated with the buffer (this could
 * happen for example, when you call up the editor with `shift-F4`).
 *
 * @function filename
 * @property r
 */
static int
l_edit_get_filename (lua_State * L)
{
    WEdit *edit;

    edit = LUA_TO_EDITBOX (L, 1);
    /* @todo: What about edit->dir_vpath? And should we return a real VPath? */
    lua_pushstring (L, vfs_path_as_str (edit->filename_vpath)); /* pushes nil if NULL */
    return 1;
}

/**
 * Whether the buffer has been modified.
 *
 * @function modified
 * @property r
 */
static int
l_edit_get_modified (lua_State * L)
{
    lua_pushboolean (L, LUA_TO_EDITBOX (L, 1)->modified);
    return 1;
}

/**
 * The number of lines in the buffer.
 *
 * Tip-short: This is also the number of the last line, because line numbers
 * are 1-based. Hence the name.
 *
 * @function max_line
 * @property r
 */
static int
l_edit_get_max_line (lua_State * L)
{
    lua_pushi (L, LUA_TO_EDITBOX (L, 1)->buffer.lines + 1);
    return 1;
}

/**
 * Number of the first line displayed.
 *
 * @function top_line
 * @property r
 */
static int
l_edit_get_top_line (lua_State * L)
{
    lua_pushi (L, LUA_TO_EDITBOX (L, 1)->start_line + 1);
    return 1;
}

/**
 * Returns the extents of the selected text.
 *
 * When text is selected (aka "marked") within the buffer, it is identified
 * by its starting marker and ending marker. "Marker" being an offset, in
 * bytes, within the buffer.
 *
 * This function returns the two markers. If no text is selected, nothing is
 * returned.
 *
 * It so happens that you can pass the two returned values directly to @{sub},
 * which is why an `Editbox:get_selection()` method isn't necessary:
 *
 *     -- Show the marked text
 *     if edt:get_markers() then
 *       alert(edt:sub(edt:get_markers()))
 *       -- To be proper, we should use :to_tty before sending the text to alert().
 *     end
 *
 * @function get_markers
 */
static int
l_edit_get_markers (lua_State * L)
{
    WEdit *edit;

    off_t start_mark, end_mark;

    edit = LUA_TO_EDITBOX (L, 1);

    if (eval_marks (edit, &start_mark, &end_mark) && (start_mark != end_mark))
    {
        lua_pushi (L, start_mark + 1);
        lua_pushi (L, end_mark);
        return 2;
    }
    else
    {
        return 0;
    }
}

/**
 * @section end
 */

/* ----------------------------- Bookmarks -------------------------------- */

/**
 * Bookmarks.
 *
 * Bookmarks are markers that are set on lines.
 *
 * A bookmark has a UI style (color, underline, etc.) that tells MC how to
 * display it.
 *
 * A single line may hold several bookmarks.
 *
 * @section
 */

/**
 * Sets a bookmark.
 *
 *     -- Highlight lines 2 and 5 to show that we've found some
 *     -- string there.
 *     local found = tty.style("yellow, green")
 *     edt:bookmark_set(2, found)
 *     edt:bookmark_set(5, found)
 *
 *     -- Highlight line 3 to show that it has a typo.
 *     local typo = tty.style("yellow, green")
 *     edt:bookmark_set(3, typo)
 *
 * (See another example at @{lines}.)
 *
 * The above code reveals a subtle issue: bookmarks have only a UI style,
 * not an ID. We can't later tell the editor to clear all the "typo"
 * bookmarks but leave the others, because they're indistinguishable from
 * the "found" bookmarks: the **found** and **typo** variables happen to
 * hold exactly the same value in our case (they are one and the same UI
 * style). Hopefully bookmarks will have an ID in future versions of MC.
 *
 * Tip: MC's skin defines two styles for bookmarks, which you can use if
 * you wish. `tty.style("editor.bookmark")` is for bookmarks set explicitly
 * by the user. `tty.style("editor.bookmarkfound")` is used for lines
 * matching a search.
 *
 * @function bookmark_set
 * @param line Line number.
 * @param style The style to use for this bookmark.
 */
static int
l_edit_bookmark_set (lua_State * L)
{
    WEdit *edit;
    long line;
    int color;

    edit = LUA_TO_EDITBOX (L, 1);
    line = luaL_checklong (L, 2) - 1;
    color = luaL_checkint (L, 3);

    /*
     * If a bookmark is already set (for this style), book_mark_insert() will
     * simply add another one. Whether this duplicity is a good or a bad thing
     * is probably a subjective question, considering that bookmarks don't
     * have IDs.
     */
    book_mark_insert (edit, line, color);

    edit->force |= REDRAW_PAGE; /* book_mark_insert() does REDRAW_LINE, but cursor may not be on marked line. */
    edit_update_view (edit);

    return 0;
}

/**
 * Clears a bookmark.
 *
 * @function bookmark_clear
 * @param line Line number.
 * @param style The style whose bookmark is to be cleared, or `-1` to clear
 *   all bookmarks on this line.
 */
static int
l_edit_bookmark_clear (lua_State * L)
{
    WEdit *edit;
    long line;
    int color;

    edit = LUA_TO_EDITBOX (L, 1);
    line = luaL_checklong (L, 2) - 1;
    color = luaL_checkint (L, 3);

    /*
     * book_mark_clear() is a misnomer: it unsets only the top-most bookmark
     * (of a certain color). We have to call it repeatedly to clear all of them.
     *
     * Perhaps we should also have a bookmark_unset() Lua function to clear
     * only the top-most bookmark. As explained earlier, bookmarks don't have
     * IDs. If they had, we wouldn't have this discussion because there'd be
     * only one bookmark of a certain ID per line.
     */
    while (book_mark_clear (edit, line, color))
        ;

    edit->force |= REDRAW_PAGE; /* book_mark_clear() does REDRAW_LINE, but cursor may not be on marked line. */
    edit_update_view (edit);

    return 0;
}

/**
 * Queries for a bookmark.
 *
 * @function bookmark_exists
 * @param line Line number.
 * @param style The style whose bookmark is to be looked for, or `-1` to
 *   look for any bookmark.
 */
static int
l_edit_bookmark_exists (lua_State * L)
{
    WEdit *edit;
    long line;
    int color;

    edit = LUA_TO_EDITBOX (L, 1);
    line = luaL_checklong (L, 2) - 1;
    color = luaL_checkint (L, 3);

    lua_pushboolean (L,
                     color == -1
                     ? book_mark_get_topmost_color (edit, line) != 0
                     : book_mark_query_color (edit, line, color));
    return 1;
}

/**
 * Clears all bookmarks.
 *
 * @function bookmark_flush
 * @param[opt] style The style whose bookmarks are to be flushed. If omitted,
 *   or if `-1`, all styles are flushed.
 */
static int
l_edit_bookmark_flush (lua_State * L)
{
    WEdit *edit;
    int color;

    edit = LUA_TO_EDITBOX (L, 1);
    color = luaL_optint (L, 2, -1);

    book_mark_flush (edit, color);

    edit->force |= REDRAW_PAGE;
    edit_update_view (edit);

    return 0;
}

/**
 * Bookmarks
 * @section end
 */

/* ------------------------------------------------------------------------ */

/**
 * Cursor
 *
 * @section
 */

/**
 * The cursor's line number.
 *
 * @function cursor_line
 * @property rw
 */
static int
l_edit_get_cursor_line (lua_State * L)
{
    lua_pushi (L, LUA_TO_EDITBOX (L, 1)->buffer.curs_line + 1);
    return 1;
}

/**
 * In the future we may want to turn this function into a full
 * blown goto_line() and add more arguments to control its operation
 * (e.g., scroll line to top/center/bottom of window).
 */
static int
l_edit_set_cursor_line (lua_State * L)
{
    WEdit *edit;
    long line;

    edit = LUA_TO_EDITBOX (L, 1);
    line = luaL_checklong (L, 2);

    /* Copied from edit_goto_cmd() */
    edit_move_display (edit, line - WIDGET (edit)->lines / 2 - 1);
    edit_move_to_line (edit, line - 1);
    edit->force |= REDRAW_COMPLETELY;
    edit_update_view (edit);

    return 0;
}

/**
 * Cursor's offset within the buffer.
 *
 * (Byte-based, __not__ character-based.)
 *
 * Example:
 *
 *    -- Jump to the next place where "Linux" appears in the text.
 *    ui.Editbox.bind("C-c", function(edt)
 *      local pos = edt:sub(1):find("Linux", edt.cursor_offs + 1)
 *      if pos then
 *        edt.cursor_offs = pos
 *      else
 *        tty.beep()
 *      end
 *    end)
 *
 * (For a useful variation of this code snippet, see
 * @{git:search_by_regex.lua}.)
 *
 * @attr cursor_offs
 * @property rw
 */
static int
l_edit_get_cursor_offs (lua_State * L)
{
    lua_pushi (L, LUA_TO_EDITBOX (L, 1)->buffer.curs1 + 1);
    return 1;
}

/*
 * Utility function: set the cursor position, and refresh the screen.
 */
static void
edit_set_cursor_offs (WEdit * edit, off_t offs)
{
    edit_cursor_move (edit, offs - edit->buffer.curs1);
    edit_scroll_screen_over_cursor (edit);

    /* Copied from edit_execute_cmd() */
    edit->found_len = 0;
    edit->prev_col = edit_get_col (edit);
    edit->search_start = edit->buffer.curs1;

    edit_update_view (edit);
}

static int
l_edit_set_cursor_offs (lua_State * L)
{
    edit_set_cursor_offs (LUA_TO_EDITBOX (L, 1), luaL_checki (L, 2) - 1);
    return 0;
}

/**
 * Cursor's offset within the line.
 *
 * (Byte-based, __not__ character-based.)
 *
 * See also @{cursor_col}.
 *
 * @attr cursor_xoffs
 * @property rw
 */
static int
l_edit_get_cursor_xoffs (lua_State * L)
{
    WEdit *edit;

    edit = LUA_TO_EDITBOX (L, 1);

    lua_pushi (L, edit->buffer.curs1 - edit_buffer_get_current_bol (&edit->buffer) + 1);

    return 1;
}

static int
l_edit_set_cursor_xoffs (lua_State * L)
{
    WEdit *edit;
    off_t new_xoffs;

    edit = LUA_TO_EDITBOX (L, 1);
    new_xoffs = luaL_checki (L, 2) - 1;

    edit_set_cursor_offs (edit, edit_buffer_get_current_bol (&edit->buffer) + new_xoffs);

    return 0;
}

/**
 * Cursor's column.
 *
 * This is where on the screen the cursor ends up. That is, the widths of
 * TAB characters, wide Asian characters and non-spacing characters are
 * taken in account.
 *
 * [note]
 *
 * It might be tempting to use this property, but often
 * it's the @{cursor_xoffs} property that you should be using instead.
 *
 * For example, the correct way to jump to the string "Linux" on the current line is:
 *
 *    ui.Editbox.bind("C-z", function(edt)
 *      local pos = edt.line:find "Linux"
 *      if pos then
 *        edt.cursor_xoffs = pos
 *      end
 *    end)
 *
 * the following, however, is a __mistake__:
 *
 *    ui.Editbox.bind("C-z", function(edt)
 *      local pos = edt.line:find "Linux"
 *      if pos then
 *        -- MISTAKE! Use cursor_xoffs instead.
 *        edt.cursor_col = pos
 *        -- To understand why it's a mistake, insert some TABs
 *        -- or UTF-8 characters before the string "Linux".
 *      end
 *    end)
 *
 * [/note]
 *
 * See also @{cursor_xoffs}.
 *
 * @attr cursor_col
 * @property rw
 */
static int
l_edit_get_cursor_col (lua_State * L)
{
    lua_pushi (L, edit_get_col (LUA_TO_EDITBOX (L, 1)) + 1);
    return 1;
}

static int
l_edit_set_cursor_col (lua_State * L)
{
    WEdit *edit;
    off_t new_col;

    off_t new_offs;

    edit = LUA_TO_EDITBOX (L, 1);
    new_col = luaL_checki (L, 2) - 1;

    if (new_col < 0)
        new_col = 0;
    /* We don't need to worry about new_col being greater than the line width:
     * edit_move_forward3() doesn't go past \n. */

    new_offs = edit_move_forward3 (edit, edit_buffer_get_current_bol (&edit->buffer), new_col, 0);

    edit_set_cursor_offs (edit, new_offs);

    return 0;
}

/**
 * @section end
 */

/**
 * Syntax.
 *
 * @section
 */

/**
 * The buffer's syntax type.
 *
 * E.g., "C Program", "HTML File", "Shell Script". If no syntax is associated
 * with the buffer, this property is **nil**.
 *
 * Examples:
 *
 *    -- Treat "README" files as HTML files.
 *    ui.Editbox.bind('<<load>>', function(edt)
 *      if edt.filename and edt.filename:find 'README' then
 *        edt.syntax = "HTML File"
 *      end
 *    end)
 *
 *    -- Auto-detect HTML files.
 *    -- It looks for a closing HTML tag in the first 1024 bytes.
 *    ui.Editbox.bind('<<load>>', function(edt)
 *      if not edt.syntax then
 *        if edt:sub(1,1024):find '</' then
 *          edt.syntax = "HTML File"
 *        end
 *      end
 *    end)
 *
 * Note: Unfortunately, this property is the descriptive name of the syntax (e.g.,
 * "Shell Script"), which may change among MC releases, rather than some fixed
 * identifier (e.g., "shell"). This makes it problematic to hard-code such
 * strings in your code. Hopefully this will be remedied in MC sometime.
 *
 * @function syntax
 * @property rw
 */
static int
l_edit_get_syntax (lua_State * L)
{
    WEdit *edit;

    edit = LUA_TO_EDITBOX (L, 1);

    if (edit->syntax_type && !STREQ (edit->syntax_type, UNKNOWN_FORMAT))
    {
        lua_pushstring (L, edit->syntax_type);
        return 1;
    }
    else
        return 0;
}

static int
l_edit_set_syntax (lua_State * L)
{
    WEdit *edit;
    const char *syntax_type;

    edit = LUA_TO_EDITBOX (L, 1);
    syntax_type = luaL_optstring (L, 2, UNKNOWN_FORMAT);

    if (!edit->filename_vpath)
    {
        /* @FIXME: edit_load_syntax() exits if there's no filename_vpath. */
        return luaL_error (L,
                           E_
                           ("Midnight Commander bug: you cannot set a syntax for an edit buffer which doesn't have an associated filename."));
    }

    {
        /* The following was copied from edit_syntax_dialog(). @FIXME: factor out. */
        option_auto_syntax = 0;
        g_free (edit->syntax_type);
        edit->syntax_type = g_strdup (syntax_type);
        edit_load_syntax (edit, NULL, edit->syntax_type);
    }

    edit->force |= REDRAW_COMPLETELY;
    edit_update_view (edit);

    return 0;
}

/**
 * Returns the @{~mod:tty#styles|style} at a certain position.
 *
 * See usage example at @{tty.destruct_style}.
 *
 * @function get_style_at
 * @param pos Position in buffer (1-based; byte-oriented).
 */
static int
l_edit_get_style_at (lua_State * L)
{
    WEdit *edit;
    off_t pos;

    edit = LUA_TO_EDITBOX (L, 1);
    pos = luaL_checki (L, 2);

    lua_pushinteger (L, edit_get_syntax_color (edit, pos - 1));
    return 1;
}

/**
 * The following is exported to Lua as _add_keyword and is wrapped
 * by a higher-level Lua function (see editbox.lua for ldoc).
 */
static int
l_edit_add_keyword (lua_State * L)
{
    static const char *const range_names[] =
        { "default", "all", "spellcheck", "!spellcheck", NULL };
    static int range_values[] =
        { RANGE_TYPE_DEFAULT, RANGE_TYPE_ANY, RANGE_TYPE_SPELLCHECK, RANGE_TYPE_NOT_SPELLCHECK };

    WEdit *edit;
    const char *s;
    const char *left;
    const char *right;
    int range;
    int style;

    edit = LUA_TO_EDITBOX (L, 1);
    s = luaL_checkstring (L, 2);
    left = luaL_optstring (L, 3, NULL);
    right = luaL_optstring (L, 4, NULL);
    range = luaMC_checkoption (L, 5, NULL, range_names, range_values);
    style = luaL_checkint (L, 6);

    lua_pushboolean (L, edit_add_syntax_keyword (edit, s, left, right, range, style));

    return 1;
}

/**
 * @section end
 */

/**
 * i18n
 *
 * @section
 */

/**
 * Converts a string, extracted from the buffer, to the terminal's encoding.
 *
 * See example and discussion at @{~mod:tty#Encodings}.
 *
 * @method to_tty
 * @args (s)
 */
static int
l_edit_to_tty (lua_State * L)
{
    WEdit *edit;
    const char *s;
    size_t len;

    edit = LUA_TO_EDITBOX (L, 1);
    s = luaL_checklstring (L, 2, &len);

#ifdef HAVE_CHARSET
    luaMC_pushlstring_conv (L, s, len, edit->converter);
#else
    (void) edit;
    (void) s;
    /* @todo: use str_nconvert_to_display() ? No, it seems it isn't a
     * 'dumb' replacement for iconv. */
    lua_pushvalue (L, 2);
#endif

    /* @todo: have from_tty() as well? see str_convert_to_input() */

    return 1;
}

/**
 * Whether the buffer is UTF-8 encoded.
 *
 * @method is_utf8
 */
static int
l_edit_is_utf8 (lua_State * L)
{
#ifdef HAVE_CHARSET
    lua_pushboolean (L, LUA_TO_EDITBOX (L, 1)->utf8);
#else
    lua_pushboolean (L, FALSE);
#endif
    return 1;
}

/**
 * @section end
 */

/**
 * Static functions
 *
 * @section
 */

static void
redraw_editors (void)
{
    if (top_dlg)
    {
        /* @FIXME: An extremely dumb way to redraw the editor(s).
         * src/editor.c should export this functionality. */
        show_right_margin = !show_right_margin;
        edit_show_margin_cmd (DIALOG (top_dlg->data));
    }
}

/**
 * Set/get editor options.
 *
 * We don't ldoc-document these two functions: a higher level API hides these
 * behind 'ui.Editbox.options'.
 */
static int
l_edit_set_option (lua_State * L)
{
    const char *option = luaL_checkstring (L, 1);

    if (STREQ (option, "tab_size"))     /* UI name: "Tab spacing" */
    {
        option_tab_spacing = luaL_checkint (L, 2);
        redraw_editors ();
    }
    else if (STREQ (option, "fake_half_tab"))   /* UI name: "Fake half tabs" */
    {
        option_fake_half_tabs = lua_toboolean (L, 2);
    }
    else if (STREQ (option, "expand_tabs"))     /* UI name: "Fill tabs with spaces" */
    {
        option_fill_tabs_with_spaces = lua_toboolean (L, 2);
    }
    else if (STREQ (option, "show_numbers"))
    {
        option_line_state = lua_toboolean (L, 2);
        option_line_state_width = option_line_state ? LINE_STATE_WIDTH : 0;
        redraw_editors ();
    }
    else if (STREQ (option, "show_right_margin"))
    {
        show_right_margin = lua_toboolean (L, 2);
        redraw_editors ();
    }
    else if (STREQ (option, "wrap_column"))     /* UI name: "Word wrap line length" */
    {
        option_word_wrap_line_length = luaL_checkint (L, 2);
        redraw_editors ();
    }
    else
    {
        luaL_error (L, E_ ("Unknown option name '%s'"), option);
    }

    return 0;
}

static int
l_edit_get_option (lua_State * L)
{
    const char *option = luaL_checkstring (L, 1);

    if (STREQ (option, "tab_size"))
        lua_pushinteger (L, option_tab_spacing);
    else if (STREQ (option, "fake_half_tab"))
        lua_pushboolean (L, option_fake_half_tabs);
    else if (STREQ (option, "expand_tabs"))
        lua_pushboolean (L, option_fill_tabs_with_spaces);
    else if (STREQ (option, "show_numbers"))
        lua_pushboolean (L, option_line_state);
    else if (STREQ (option, "show_right_margin"))
        lua_pushboolean (L, show_right_margin);
    else if (STREQ (option, "wrap_column"))
        lua_pushinteger (L, option_word_wrap_line_length);
    else
        luaL_error (L, E_ ("Unknown option name '%s'"), option);

    return 1;
}

/**
 * @section end
 */

/**
 * Static functions (syntax)
 *
 * @section
 */

/**
 * Returns a list of all the recognized syntaxes.
 *
 *    keymap.bind('C-y', function()
 *      devel.view {
 *        "Supported syntaxes:", ui.Editbox.syntax_list
 *      }
 *    end)
 *
 * @function ui.Editbox.get_syntax_list
 */
static int
l_edit_get_syntax_list (lua_State * L)
{
    GPtrArray *names;
    size_t i;

    names = g_ptr_array_new ();
    edit_load_syntax (NULL, names, NULL);       /* @FIXME: make that function itself call g_ptr_array_sort(), instead of all its callers doing it? */

    lua_newtable (L);

    for (i = 0; i < names->len; i++)
    {
        const char *name = g_ptr_array_index (names, i);

        if (!STREQ (name, UNKNOWN_FORMAT))
        {
            lua_pushstring (L, name);
            lua_rawseti (L, -2, i + 1);
        }
    }

    g_ptr_array_foreach (names, (GFunc) g_free, NULL);
    g_ptr_array_free (names, TRUE);

    return 1;
}

/**
 * @section end
 */

/**
 * Events
 *
 * @section
 */

/**
 * Triggered when an editbox is opened.
 *
 * Example:
 *
 *    ui.Editbox.bind("<<load>>", function(edt)
 *      alert(edt.syntax)
 *    end)
 *
 * Another example:
 *
 *    -- When a user opens a *.log file, automatically jump to its
 *    -- end and insert a date header.
 *    ui.Editbox.bind('<<load>>', function(edt)
 *      if edt.filename and edt.filename:find '%.log$' then
 *        edt.cursor_offs = edt:len() + 1
 *        edt:insert("\n--------" .. os.date() .. "--------\n")
 *      end
 *    end)
 *
 * See more examples at @{ui.Editbox:add_keyword}, @{ui.Editbox.syntax},
 * @{ui.Editbox.options}, @{git:modeline.lua}.
 *
 * Info-short: The name of this event is borrowed from the JavaScript world (`body.onload`).
 *
 * @moniker load__event
 * @event
 */

/**
 * Triggered when an editbox is closed.
 *
 * @moniker unload__event
 * @event
 */

/**
 * @section end
 */

/* ------------------------------------------------------------------------ */

/* *INDENT-OFF* */
static const struct luaL_Reg ui_edit_static_lib[] = {
    { "_new", l_edit_new },
    { "get_syntax_list", l_edit_get_syntax_list },
    { "set_option", l_edit_set_option },
    { "get_option", l_edit_get_option },
    { NULL, NULL }
};

static const struct luaL_Reg ui_edit_lib[] = {
    { "insert", l_edit_insert },
    { "delete", l_edit_delete },
    { "get_line", l_edit_get_line },
    { "get_cursor_line", l_edit_get_cursor_line },
    { "set_cursor_line", l_edit_set_cursor_line },
    { "get_cursor_offs", l_edit_get_cursor_offs },
    { "set_cursor_offs", l_edit_set_cursor_offs },
    { "get_cursor_xoffs", l_edit_get_cursor_xoffs },
    { "set_cursor_xoffs", l_edit_set_cursor_xoffs },
    { "get_cursor_col", l_edit_get_cursor_col },
    { "set_cursor_col", l_edit_set_cursor_col },
    { "get_current_char", l_edit_get_current_char },
    { "sub", l_edit_sub },
    { "len", l_edit_len },
    { "get_syntax", l_edit_get_syntax },
    { "set_syntax", l_edit_set_syntax },
    { "_add_keyword", l_edit_add_keyword },
    { "bookmark_set", l_edit_bookmark_set },
    { "bookmark_clear", l_edit_bookmark_clear },
    { "bookmark_exists", l_edit_bookmark_exists },
    { "bookmark_flush", l_edit_bookmark_flush },
    { "get_filename", l_edit_get_filename },
    { "get_modified", l_edit_get_modified },
    { "get_max_line", l_edit_get_max_line },
    { "get_top_line", l_edit_get_top_line },
    { "get_markers", l_edit_get_markers },
    { "focus", l_edit_focus },
    { "load", l_edit_load },
    { "get_style_at", l_edit_get_style_at },
    { "to_tty", l_edit_to_tty },
    { "is_utf8", l_edit_is_utf8 },
    { NULL, NULL }
};
/* *INDENT-ON* */

int
luaopen_ui_editbox (lua_State * L)
{
    create_widget_metatable (L, "Editbox", ui_edit_lib, ui_edit_static_lib, "Widget");
    return 0;                   /* Nothing to return! */
}
