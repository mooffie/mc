--[[

A UI context that doesn't let the user intervene.

Behaves like 'batch'; looks like 'interactive'.

]]

local function create_context()
  local ctx = require('fileops.contexts.interactive').create_context()
  ctx.passive = true
  ctx.for_all["overwrite"] = "overwrite"
  ctx.for_all["io_error"] = "skip"
  ctx.for_all["non_empty_dir_deletion"] = "delete"
  ctx.decide_on_partial = function () return "delete" end
  return ctx
end

return {
  create_context = create_context,
}
