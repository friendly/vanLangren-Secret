-- For Word output, honour CSS colour on spans, e.g. [**55**]{style="color:red"}.
-- Pandoc's docx writer ignores `style`, so emit the span as a coloured raw run.
-- Handles plain or bold text content; other formats are untouched.

local named = { red = "C00000", blue = "0070C0", green = "00B050" }

local function xml_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Span(el)
  if not FORMAT:match("docx") then return nil end
  local color = (el.attributes.style or ""):match("color:%s*#?(%w+)")
  if not color then return nil end
  color = named[color:lower()] or color:upper()
  local bold = false
  el.content:walk({ Strong = function() bold = true end })
  local rpr = '<w:rPr>' .. (bold and '<w:b/>' or '') ..
    '<w:color w:val="' .. color .. '"/></w:rPr>'
  return pandoc.RawInline("openxml",
    '<w:r>' .. rpr .. '<w:t xml:space="preserve">' ..
    xml_escape(pandoc.utils.stringify(el.content)) .. '</w:t></w:r>')
end
