-- Keep only the "Figure captions" section of a document (heading and captions).
-- Used by build.R: pandoc submission.docx -L extract-captions.lua -o figure-captions.docx
function Pandoc(doc)
  local keep, out = false, pandoc.Blocks({})
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" then
      keep = pandoc.utils.stringify(b.content) == "Figure captions"
    end
    if keep then out:insert(b) end
  end
  doc.blocks = out
  return doc
end
