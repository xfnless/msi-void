  function tab_split_code(key, env)
    local context = env.engine.context

    if not context:is_composing() then
      return 2 -- kNoop
    end

    if key:repr() ~= "Tab" then
      return 2 -- kNoop
    end

    local input = context.input
    local len = #input

    if (len == 3 or len == 4) and context.caret_pos == len then
      context.caret_pos = 2
      return 1 -- kAccepted
    end

    return 2 -- kNoop
  end