Welcome to Calculator

Expressions
-----------

You can type any Lua expression. You're not limited to numbers only.
Examples:

    1 + 2
    ui.Editbox.syntax_list
    fs.read('/etc/issue')
    s = fs.read('/etc/issue')
    {11, 12, 13}
    sin(0.5)

(If the result is complex, use M-x ("Expand result") to examine it in
the viewer.)

An expression can return multiple results:

    1, 2, 3
    ("one two"):match "(%w+) (%w+)"
    fs.read('/404')

and raise an exception:

    sin()

Mathematical functions
----------------------

The functions from Lua's math library are available to you directly.
E.g., you can type "sin(0.5)" instead of "math.sin(0.5)".

Defining your own functions
---------------------------

In a script in your Lua folder do:

    local calc = require('samples.apps.calc')

    -- Create your own function: a sinus that accepts degrees.
    calc.funcs.dsin = function(x) return math.sin(math.rad(x)) end

(Again: you're not limited to numbers only. Your functions may
accept/return any object(s).)

Inputting numbers in various bases
----------------------------------

You can use Lua's `tonumber(s, base)` and hex notation (e.g., 0x3ef),
but, as a convenience, there are a few conversion functions defined for
you:

    b'01000101'   Binary
    h'0e78800a'   Hex
    o'666'        Octal
    d'8145192'    Decimal

You can embed spaces or underscores in the string for better
readability -- these characters will be ignored:

    b'0100 0101'
    d'8_145_192'

(This is the only reason d'' exists: to make it easier for humans to
enter long numbers.)

Bit operations
--------------

If you're using Lua 5.3+ you can use the bitwise operators known from C:

    0xff00 & 0xffccff

Otherwise you can use the functions from the bit32 module, which are
available to you directly (no need to prefix them with the module's name):

    band(0xff00, 0xffccff)

When using these function forms the results are 32 bits. When using
operators (Lua 5.3+) the results are 64 bits.
