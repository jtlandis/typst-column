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

-- takes a Div element and returns its contents
-- with the appropriate typst block wrappers
function new_quarto_column(el)
  local width = nil
  if has_attr(el, "width") then
    width = el.attributes["width"]
  end
  quarto_column(width, el.content)
  return el.content
end

function quarto_column(width, content)
  local typst = nil
  if width then
    typst = typst_block("quarto_column(width: " .. width .. ")[")
  else
    typst = typst_block("quarto_column[")
  end
  table.insert(content, 1, typst)
  table.insert(content, typst_block("],"))
end

function quarto_columns(el)
  local content = el.content
  local gutter = nil
  if has_attr(el, "gutter") then
    gutter = el.attributes["gutter"]
    table.insert(content, 1, typst_block("#quarto_columns(gutter: " .. gutter .. ", "))
  else
    table.insert(content, 1, typst_block("#quarto_columns("))
  end
  table.insert(content, typst_block(")"))
  return content
end

function is_typst_block(el)
  if (el and el.t == "RawBlock" and el.format == "typst") then
    return true
  end
  return false
end

function Div(el)
  if is_column(el) then
    return new_quarto_column(el)
  end
  if is_column_container(el) then
    local within_typst = false
    local block_is_typst = false
    for i, thing in pairs(el.content) do
      block_is_typst = is_typst_block(thing)
      if block_is_typst then
        within_typst = not within_typst
      end
      if not within_typst and not block_is_typst then
        print(thing)
        error("Imporper column format")
        os.exit(1)
      end
    end
    return quarto_columns(el)
  end
  return el
end

function Pandoc(el)
  local meta = el.meta
  local incl_before = el.meta["include-before"]
  table.insert(incl_before,
    typst_block(
      [[
      #let quarto_column(width: auto, body) = {
        (
          width: width,
          body: body
        )
      }

      #let quarto_columns(gutter: 12pt, ..columns) = {
        let check_values = (values) => {
          let auto_count = values.filter(x => x == auto).len();

          // If there are any auto values
          if auto_count > 0 {
              // Calculate the new equal percentage for all values
              let equal_percentage = 100% / values.len();
              let equal_percentage = equal_percentage - 1%
              // Return an array where all values are set to equal_percentage
              values.map(x => equal_percentage)
          } else {
              // If no auto values, return the original array
              values
          }
        }
        let columns = columns.pos()
        let widths = columns
          .map(it => {
            it.width
          })
        let widths = check_values(widths)

        let contents = columns
          .map(it => {
            it.body
          })
        grid(columns: widths,
             gutter: gutter, ..contents)
      }]])
  )
  return el
end
