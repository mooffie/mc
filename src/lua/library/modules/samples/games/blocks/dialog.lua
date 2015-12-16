--[[

The UI of the game.

]]

local board = require('samples.games.blocks.board')

local setup_menu = {
  {T"&Classic", value="classic"},
  {T"Classic (&wide)", value="classicwide"},
  {T"&Advanced", value="advanced"},
}
local current_setup = "classic"

local function run_dialog()

  board.reset_board()
  board.new_piece()

  local ui_score = {
    shapes = ui.Label(),
    lines = ui.Label(),
    points = ui.Label(),
  }

  local dlg = ui.Dialog(T"Game of Blocks")
  local view = ui.Custom()
  view.cols = board.get_wd()*2
  view.rows = board.get_ht()

  local itrvl

  view.on_draw = function()
    board.draw_board(view:get_canvas())
  end

  local function rjust(n)
    n = require('utils.text').format_size(n, 6, true)
    return ("%6s"):format(n)
  end

  local function update_score_display()
    local score = board.get_score()
    ui_score.shapes.text = rjust(score.shapes)
    ui_score.lines.text = rjust(score.lines)
    ui_score.points.text = rjust(score.points)
  end

  update_score_display()

  local function go_down()
    if not board.go_down() then
      if not board.next_piece() then
        itrvl:stop()
        alert(T"Game over!")
      end
      update_score_display()
    end
  end

  local K = utils.magic.memoize(tty.keyname_to_keycode)

  view.on_hotkey = function(self, kcode)
    if kcode == K'left' then
      board.go_left()
    elseif kcode == K'right' then
      board.go_right()
    elseif kcode == K'up' then
      board.rotate_current_piece()
    elseif kcode == K'down' then
      go_down()
    else
      return false
    end
    view:redraw()
    return true
  end

  local function tick()
    go_down()
    view:redraw()
    dlg:refresh()
  end

  itrvl = timer.set_interval(tick, 1000)

  local scores = ui.Groupbox(T"Stats"):add(
    ui.HBox():add(
      ui.VBox():add(ui.Label(T"Shapes:"), ui.Label(T"Rows:"), ui.Label(T"Points:")),
      ui.VBox():add(ui_score.shapes, ui_score.lines, ui_score.points)
    )
  )

  local btn_pause  = ui.Button(T"&Pause")
  local btn_resume = ui.Button{T"&Resume", enabled=false}

  btn_pause.on_click = function()
    itrvl:stop()
    btn_pause.enabled = false
    btn_resume.enabled = true
  end
  btn_resume.on_click = function()
    itrvl:resume()
    btn_pause.enabled = true
    btn_resume.enabled = false
  end

  local function change_setup()
    itrvl:stop()

    local pref = ui.Dialog(T"Setup")
    local lst = ui.Radios{ items = setup_menu }
    lst.value = current_setup
    pref:add(lst)
    pref:add(ui.DefaultButtons())
    if pref:run() then
      current_setup = lst.value
      board.setup(lst.value)
      dlg.result = "restart"
      dlg:close()
    end

    itrvl:resume()
  end

  dlg:add(ui.HBox():add(
    view,
    ui.VBox():add(
      scores,
      ui.Space(),
      ui.HBox():add(ui.Space(), ui.VBox{gap=1}:add(
        ui.Button{T"&New", result="restart"},
        ui.Button{T"&Setup...", on_click=change_setup},
        btn_pause,
        btn_resume,
        ui.Button({T"E&xit", result=false})
      ))
    )
  ))

  local result = dlg:run()

  itrvl:stop()

  if result == "restart" then
    run_dialog()
  end
end

return {
  run_dialog = run_dialog,
}
