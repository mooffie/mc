
local M = {}

require('utils.magic').setup_autoload(M)

M.autoload('glob', 'utils.glob')
 .autoload('magic', 'utils.magic')
 .autoload('bit32', 'utils.bit32')

return M
