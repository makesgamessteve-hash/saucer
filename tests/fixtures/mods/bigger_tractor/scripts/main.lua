-- runs after base; counts size changes into its own state branch
function on_init(ctx) ctx.state.bigger_tractor = { changes = 0 } end
function on_event(ev, state)
  if ev.type == "size_change" then state.bigger_tractor.changes = state.bigger_tractor.changes + 1 end
end
