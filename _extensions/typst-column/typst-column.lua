-- generic test element class is present
function has_class(el, target_class)
  if (el.classes and #el.classes > 0) then
    for _, class in pairs(el.classes) do
      if class == target_class then
        return true
      end
    end
  end
  return false
end

function is_column_container(el)
  if (el and el.t == "Div") then
    return has_class(el, "columns")
  end
  return false
end

function is_column(el)
  if (el and el.t == "Div") then
    return has_class(el, "column")
  end
  return false
end

function has_any_attr(el)
  if (el and el.attributes and #el.attributes > 0) then
    return true
  end
  return false
end

function has_attr(el, attr)
  if has_any_attr(el) then
    for t, v in pairs(el.attributes) do
      if t == attr then
        return true
      end
    end
  end
  return false
end

function typst_block(string)
  return pandoc.RawBlock('typst', string)
end

function quarto_columns(el)
  local content = el.content
  local gutter = nil
  local typst = "#grid("
  if has_attr(el, "widths") then
    local widths = el.attributes["widths"]
    typst = typst .. "columns: (" .. widths .. "), "
  end
  if has_attr(el, "gutter") then
    gutter = el.attributes["gutter"]
  else
    gutter = "10pt" -- default value for some spacing
  end
  typst = typst .. "gutter: " .. gutter .. ", "
  table.insert(content, 1, typst_block(typst))
  table.insert(content, typst_block(")"))
  return content
end

function is_typst_block(el)
  if (el and el.t == "RawBlock" and el.format == "typst") then
    return true
  end
  return false
end

check_columns = {
  Div = function(el)
    if is_column_container(el) then
      local widths = {}
      local is_col = false
      local val = nil
      for i, thing in pairs(el.content) do
        is_col = is_column(thing)
        -- send an error if we detect content (that isnt typst content)
        -- outside of the quarto div markers
        if not (is_col or is_typst_block(thing)) then
          print(thing)
          error("invalid column content. all content should be within :::{.column} :::")
          os.exit(1)
        end
        -- if it is a column, grab width attr
        if is_col then
          if has_attr(thing, "width") then
            val = thing.attributes["width"]
          else
            val = "auto"
          end
          table.insert(widths, val)
        end
      end
      el.attributes["widths"] = table.concat(widths, ", ")
    end
    return el
  end
}

set_typst_cols = {
  Div = function(el)
    if is_column_container(el) then
      local n = #el.content
      local shift = 0
      local indx = nil
      local col = nil
      table.insert(el.content, 1, typst_block("[ "))
      shift = shift + 1
      for i = 1, n do
        -- current shift
        indx = i + shift
        --print("current i: " .. i .. "  current size: " .. #el.content .. "  expected index: " .. indx)
        -- if div is column class, insert more typst contents
        col = el.content[indx]
        if is_column(col) then
          if i == n then
            table.insert(el.content, typst_block("] "))
          else
            table.insert(el.content, indx + 1, typst_block("], [ "))
          end
          shift = shift + 1
        end
      end
      el.content = quarto_columns(el)
    end
    return el
  end
}


function Pandoc(el)
  el.blocks = el.blocks:walk(check_columns)
  el.blocks = el.blocks:walk(set_typst_cols)
  return el
end
