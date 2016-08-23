Tabs
====

This module adds support for tabs. Tabs record the complete state of the
panels: directories, marked files, sort order, panelized listing, etc.

**Installation:**

    require('samples.accessories.tabs.default-key-bindings')
    require('samples.accessories.tabs.colon-commands')

**Or, with customizations:**

    require('samples.accessories.tabs.default-key-bindings')
    require('samples.accessories.tabs.colon-commands')

    local tabs = require('samples.accessories.tabs.core')

    tabs.region = 'south'  -- show the tabs at bottom of screen, not top.

    tabs.style.normal = 'white, green'
    tabs.style.selected = 'yellow, magenta'

    ui.Panel.bind('C-n', function() tabs.create_tab() end)
    ui.Panel.bind('C-c', function() tabs.close_tab() end)


Default keyboard bindings
-------------------------

* Use `M-<` and `M->` to switch to the previous/next tab.

Mouse bindings
--------------

(Below, "tab" means "tab button".)

* Click a tab to switch to it.
* Click the `[x]` and `[+]` buttons to close/create tabs.
* Double-click a tab to rename it.
* Drag tabs around to rearrange them.

Colon commands
--------------

* `:tc` Close the current tab.
* `:tn [name]` New tab.
* `:tr [name]` Rename the current tab.

(You don't need to memorize these commands; Do `:help` to see them.)
