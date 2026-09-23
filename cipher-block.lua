-- For Word output, set code blocks with class .cipher in a smaller font
-- so the long ciphertext lines don't wrap. Other formats are untouched.

local size_pt = 9

local function xml_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function CodeBlock(el)
  if not FORMAT:match("docx") or not el.classes:includes("cipher") then
    return nil
  end
  local rpr = string.format(
    '<w:rPr><w:rStyle w:val="VerbatimChar"/><w:sz w:val="%d"/><w:szCs w:val="%d"/></w:rPr>',
    size_pt * 2, size_pt * 2)
  local runs = {}
  for line in (el.text .. "\n"):gmatch("(.-)\n") do
    table.insert(runs, '<w:r>' .. rpr ..
      '<w:t xml:space="preserve">' .. xml_escape(line) .. '</w:t></w:r>')
  end
  local xml = '<w:p><w:pPr><w:pStyle w:val="SourceCode"/></w:pPr>' ..
    table.concat(runs, '<w:r><w:br/></w:r>') .. '</w:p>'
  return pandoc.RawBlock("openxml", xml)
end
