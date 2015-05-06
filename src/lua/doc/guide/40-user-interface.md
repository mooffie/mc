
# The User Interface

GUI, or UI, programming is notorious for being hard to learn.

Don't worry: UI programming in MC breaks free with this impression. It
also tries to be fun. There are very few principle to grasp before you
can master it.

## Dialog boxes

Everything you see on the screen is a *widget*. Widgets are organized in
dialog boxes (which technically are widgets too).

Often you'll want to do just that -- show a dialog to the user. The
steps for doing this are straightforward:

First, we create a dialog:

    local dlg = ui.Dialog()

Next, we populate it with widgets:

    dlg:add(ui.Label("A label telling you that life is beautiful."))
    dlg:add(ui.Checkbox("Do you like pizza?"))
    dlg:add(ui.Button("Click me!"))
    ...

Finally, we show the dialog:

    dlg:run()

Let's have a complete example that we can run. In your Lua user folder
place a script whose content is:

    local function quiz()

      local dlg = ui.Dialog(T"Quiz")

      dlg:add(ui.Label(T"What's your name?"))

      local user_name = ui.Input()
      dlg:add(user_name)

      local likes_pizza = ui.Checkbox(T"Do you like pizza?")
      dlg:add(likes_pizza)

      local singer = ui.Radios()
      singer.items = {
        T"Sinatra",
        T"Diddo",
        T"Didi",
      }
      dlg:add(ui.Groupbox(T"Favorite singer:"):add(singer))

      dlg:add(ui.Button(T"A button that does nothing!"))

      dlg:add(ui.DefaultButtons())

      if dlg:run() then
        alert(T"Hello, %s! Your favorite singer is %s!":format(
          user_name.text, singer.value))
        if likes_pizza.checked then
          alert(T"You like pizza!")
        end
      end

    end

    keymap.bind("C-y", quiz)

Running the dialog (by pressing `C-y`) gives us the following:

<pre class="screenshot">
┌───────────── Quiz ──────────────┐
│ What's your name?               │
│ __________                      │
│ [ ] Do you like pizza?          │
│ ┌ Favorite singer: ───────────┐ │
│ │ (*) Sinatra                 │ │
│ │ ( ) Diddo                   │ │
│ │ ( ) Didi                    │ │
│ └─────────────────────────────┘ │
│ [ A button that does nothing! ] │
├─────────────────────────────────┤
│       [< OK >] [ Cancel ]       │
└─────────────────────────────────┘
</pre>

## Properties

Widgets have <a
href="http://en.wikipedia.org/wiki/Property_(programming)">properties</a>.
E.g., a checkbox has a `checked` property, an input box has a `text`
property. A listbox has a `value` property, etc.

Properties, to you the programmer, look exactly like normal fields in a
table. The only difference is that setting (or getting) them triggers
some action. This action usually updates the screen to reflect the new
state of the widget.

In other words, properties make the code look a bit like Visual Basic,
and save on the amount of code you need to write.

For example, if you want to toggle a checkbox, you'd do:

    likes_pizza.checked = not likes_pizza.checked

This statement is equivalent the following statement in more
conservative APIs:

    likes_pizza:set_checked(not likes_pizza:get_checked())

In fact, this is *exactly* how properties are implemented in our Lua
integration: they're but syntactic sugar over get/set methods.

## Creating widgets

You create widgets by calling their "constructor" function. In our Lua
integration we set a convention: such functions start with an upper case
letter.

The constructor function gets an *optional* table of properties.

The following:

    local btn = ui.Button {text=T"Say hi", type="narrow", on_click=function() alert(T"hi!") end}

is equivalent to:

    local btn = ui.Button()

    btn.text = T"Say hi"
    btn.type = "narrow"
    btn.on_click = function() alert(T"hi!") end

### The "text" property

Many widgets have a `text` property. Buttons and checkboxes use it for
their label, dialogs for title, input boxes for their value. While other
GUI toolkits name this property differently depending on the widget
type, in our toolkit we name it uniformly, "text", across all the
widgets. The advantage is that the programmer doesn't need to look up
the reference for the correct property name.

If you provide the widget constructor with a single string, or if the
first element of the table you provide it is a string, it will be taken
to be the value of the `text` property.

The following are all ways to set the `text` property:

    local btn = ui.Button(T"click me")

    local btn = ui.Button()
    btn.text = T"click me"

    local btn = ui.Button {T"click me"}

    local btn = ui.Button {text=T"click me"}

    local btn = ui.Button {T"click me", type="narrow"}

    local btn = ui.Button {type="narrow", T"click me"}

    local btn = ui.Button {text=T"click me", type="narrow"}


## Containers and layout

Often we want to arrange the widgets in a certain layout. We may want to
display some widgets side by side, or inside a frame.

For this we use containers. Containers are just like widget, but they
can contain other widgets (and other containers).

Layouting in our toolkit is based on the hbox/vbox model.

When you want to arrange widgets side by side, you put them in an
@{ui.HBox|HBox} container.

When you want to arrange widgets one on top of the other, you put them
in a @{ui.VBox|VBox} container. A @{ui.Dialog|Dialog} and
@{ui.Groupbox|Groupbox} behave exactly like a VBox (except that they
display a frame).

You can **nest** containers to create complex layouts.

Containers are created just like other widgets --using a constructor
function-- and they all have an @{ui.add|:add()} method.

In the following example we mimic MC's configuration dialog:


    local function test()

      local dlg = ui.Dialog(T"Configure options")

      dlg:add(
        ui.HBox():add(
          ui.VBox():add(
            ui.Groupbox(T"File operations"):add(
              ui.Checkbox(T"&Verbose operation"),
              ui.Checkbox(T"Compute tota&ls"),
              ui.Checkbox(T"Classic pro&gressbar")
            ),
            ui.Groupbox(T"Esc key mode"):add(
              ui.Checkbox(T"&Single press"),
              ui.HBox():add(
                ui.Label(T"Timeout:"),
                ui.Input()
              )
            )
          ),
          -- The 'expandy' below (described later) makes this shorter groupbox
          -- stretch over the whole dialog height. You can omit it.
          ui.Groupbox{T"Other options", expandy=true}:add(
            ui.Checkbox(T"Use internal edi&t"),
            ui.Checkbox(T"Use internal vie&w"),
            ui.Checkbox(T"Sa&fe delete")
          )
        ),
        ui.DefaultButtons()
      )

      dlg:run()

    end

    keymap.bind("C-y", test)

In the example above we used the fact that `:add()` returns the object
in order to get away with having temporary variables to store the many
containers. In other words, instead of:

    local grp = ui.Groupbox(T"Favorite singer")
    grp:add(singers)
    dlg:add(grp)

we can do:

    dlg:add(
      ui.Groupbox(T"Favorite singer"):add(singers)
    )


## Sizing a widget

Usually you don't need to bother about a widget's size: its default size
is often fine. Sometimes, however, you have your own preferences for it.

There are two mechanism by with you can set a widget's size.

### (1) The `cols` and `rows` properties

The first mechanism is the `cols` and `rows` properties. They let you
set the size explicitly (or, as we will see next, the *minimum* size).

For example, you may want to set a gauge's `cols` or a listbox's `rows`
because their desired dimensions are determined by their importance to
you, something only you can judge.

    local gauge = ui.Gauge {cols=20}

or:

    local lst = ui.Listbox()
    lst.items = {
      "one", "two", "three"
    }
    lst.rows = 5


### (2) The `expandx` and `expandy` properties

The other sizing mechanism works in tandem with the
@{~#containers|containers model} described earlier. If the widget's
`expandx` property is set to true, the widget will stretch horizontally
to fill the available space in its container. `expandy` works similarly
in the vertical axis.

Let's see how `expandx` can help us. We'll start with the following code,

    local function test()
      local dlg = ui.Dialog()

      dlg:add(
        ui.Groupbox(T"Settings"):add(
          ui.Checkbox(T"Always use a &proxy server"),
          ui.HBox():add(
            ui.Label(T"Server:"),
            ui.Input()
          )
        )
      )

      dlg:run()
    end

which produces the following dialog:

<pre class="screenshot">
┌ Settings ─────────────────────┐
│ [ ] Always use a proxy server │
│ Server: __________            │
└───────────────────────────────┘
</pre>

The input box for the server name is quite small (being its default size,
10 columns). We can easily make it stretch the whole available space by
adding `expandx=true` to it. We **also** have to add `expandx=true` to
its parent (the HBox) or else this parent won't have any excessive space
to allocate to the input widget:

    local function test()
      local dlg = ui.Dialog()

      dlg:add(
        ui.Groupbox(T"Settings"):add(
          ui.Checkbox(T"Always use a &proxy server"),
          ui.HBox{expandx=true}:add(
            ui.Label(T"Server:"),
            ui.Input{expandx=true}
          )
        )
      )

      dlg:run()
    end

which produces the desired layout:

<pre class="screenshot">
┌ Settings ─────────────────────┐
│ [ ] Always use a proxy server │
│ Server: _____________________ │
└───────────────────────────────┘
</pre>

Info: By default only the @{ui.Groupbox} widget (and @{ui.Listbox}) has
its `expandx` property set to **true**. This is why frames of groupboxes
stretch over all the dialog's width in screenshots here. For all other
widgets you'll have to set this property explicitly.

#### Aligning and centering widgets

We can use `expandx` and `expandy` to flush widgets to the
right/buttom/center using a simple trick: we add a @{ui.Space} widget
before or around the desired widget and set `expandx=true` or `expandy=true`
on this spacer:

    local function test()
      local dlg = ui.Dialog()

      dlg:add(
        ui.Label(T"Some very very log string just to widen the dialog"), -- or we can use dlg:set_dimensions().
        ui.HBox{expandx=true}:add(
          ui.Button(T"on the left"),
          ui.Space{expandx=true},
          ui.Button(T"on the right")
        ),
        ui.HBox{expandx=true}:add(
          ui.Space{expandx=true},
          ui.Button(T"at the center"),
          ui.Space{expandx=true}
        ),
        ui.DefaultButtons()
      )

      dlg:run()
    end

gives:

<pre class="screenshot">
┌────────────────────────────────────────────────────┐
│ Some very very log string just to widen the dialog │
│ [ on the left ]                   [ on the right ] │
│                 [ at the center ]                  │
├────────────────────────────────────────────────────┤
│                [< OK >] [ Cancel ]                 │
└────────────────────────────────────────────────────┘
</pre>

`expandy` works the same way but for the 'y' axis.

## Events

Many widgets, and the dialog itself, can respond to various events. We
set an *event handler* like we set any other property. By convention event
handler names start with "on_" (a practice borrowed from JavaScript).

For example:

    local function test()

      local dlg = ui.Dialog()

      local use_proxy = ui.Checkbox(T"Use a proxy server:")
      local proxy_address = ui.Input{"localhost:8080", cols=20, enabled=false} -- Start as disabled.
      local btn = ui.Button(T"A silly button")

      -- Note the similarity to JavaScript.
      btn.on_click = function()
        alert(T"Hello!")
      end

      -- We enable the proxy input box if, and only if, the
      -- checkbox is checked.
      use_proxy.on_change = function()
        proxy_address.enabled = use_proxy.checked
      end

      dlg:add(use_proxy, proxy_address, btn, ui.DefaultButtons())
      dlg:run()

    end

    keymap.bind("C-y", test)

All event handlers get a 'self' argument, pointing to widget itself, as
the first argument. So use_proxy's handler could also be written as:

    use_proxy.on_change = function(self)
      proxy_address.enabled = self.checked
    end

    -- or, using Lua style:

    function use_proxy:on_change()
      proxy_address.enabled = self.checked
    end

Some handlers get additional arguments. Look up the @{ui|reference} for details.

Incidentally, we didn't *have* to create the `btn` variable to reference
the button in the example above. We could do without:

    dlg:add(
      ui.Button{T"A silly button", on_click=function()
        alert(T"Hello!")
      end}
    )

In fact, we didn't have to create the `dlg` variable either. We could do:

    ui.Dialog()
      :add(use_proxy, proxy_address, btn, ui.DefaultButtons())
      :run()

## Static functions

We've mentioned constructor functions, like ui.Button(), ui.Label(),
etc.

These functions also serve as @{~mod:ui#static widget|namespaces in which functions are stored},
functions that don't operate on a specific widget object (otherwise
they're be normal methods) but serve some other utility.

For example, each namespace has a @{ui.bind|bind()} function:

- ui.Editbox.bind()
- ui.Listbox.bind()
- ui.Panel.bind()
- ...

This `bind()` function binds a function to a key typed when the focus is
in a widget of a certain kind only.
