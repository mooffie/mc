---
-- Globals functions.
--
-- Info: There isn't really a module named "globals". This page just serves to
-- document any global functions or variables.
--
-- @pseudo
-- @module globals

----------------------------- defined elsewhere ------------------------------

---
-- Defined @{locale.T|at the locale module}.
-- @function T
-- @args

---
-- Defined @{locale.N|at the locale module}.
-- @function N
-- @args

---
-- Defined @{locale.Q|at the locale module}.
-- @function Q
-- @args

---
-- Defined @{locale.E|at the locale module}.
-- @function E
-- @args

------------------------------------------------------------------------------
-- Command line arguments.
--
-- A table holding command line arguments, starting at index 1. Index 0
-- holds the pathname of the script being run.
--
-- It is only available in @{mc.is_standalone|standalone} mode. Otherwise
-- it is **nil**. See the @{~standalone|user guide} for details.
--
-- See usage example in @{git:misc/bin/htmlize}
--
-- @field argv

--- Alias for `argv`.
--
-- [info]
--
-- This alias exists for compatibility with source code written for
-- `/usr/bin/lua`, the "official" Lua interpreter, which names that table "arg".
--
-- You should prefer using "argv" in your code because grepping your code
-- for this name is easier ("arg", on the other hand, is a more generic term).
--
-- [/info]
--
-- @field arg

arg = argv

------------------------------------------------------------------------------
