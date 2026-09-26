-- Submission version: figures out of the text, as the editor asked.
--
-- Active only when rendered with `-M submission:true`; otherwise does nothing.
--   * each figure is replaced by a marker paragraph, "[FIG n about here]"
--   * cross-references (@fig-xxx) become "Figure n"
--   * a "Figure captions" page is added at the end
--   * a manifest (number, label, source file, caption) is written for
--     submission/make-figures.R, so the figure files use the same numbers
--
-- quarto render vanLangren-Secret.qmd --to docx -M submission:true \
--   -o vanLangren-Secret-submission.docx --output-dir submission

local enabled = false
local manifest_path = "submission/figures.csv"
local order = {}       -- label -> number
local figs = {}        -- list of {n, id, src, caption (Inlines)}

local function first_image_src(blocks)
  local src = ""
  pandoc.walk_block(pandoc.Div(blocks), {
    Image = function(img) if src == "" then src = img.src end end
  })
  return src
end

local function caption_inlines(el)
  local cap = el.caption_long
  if cap == nil then return pandoc.Inlines({}) end
  local ty = pandoc.utils.type(cap)
  if ty == "Inlines" then return cap end
  if ty == "Block" then cap = pandoc.Blocks({ cap }) end
  if ty == "Blocks" or ty == "Block" then return pandoc.utils.blocks_to_inlines(cap) end
  io.stderr:write("submission.lua: unexpected caption type " .. tostring(ty) .. "\n")
  return pandoc.Inlines({ pandoc.Str(pandoc.utils.stringify(cap)) })
end

local function csv(s)
  return '"' .. s:gsub('"', '""') .. '"'
end

-- pass 1: read the flag and number the figures in document order
local pass1 = {
  Meta = function(m)
    enabled = m.submission == true
    if m["submission-manifest"] then
      manifest_path = pandoc.utils.stringify(m["submission-manifest"])
    end
  end,
}

local pass2 = {
  FloatRefTarget = function(el)
    if not enabled or el.type ~= "Figure" then return nil end
    local n = #figs + 1
    order[el.identifier] = n
    figs[n] = { n = n, id = el.identifier, src = first_image_src(el.content),
                caption = caption_inlines(el) }
    return nil
  end,
}

-- pass 3: replace figures and cross-references; add captions page and manifest
local pass3 = {
  FloatRefTarget = function(el)
    if not enabled or el.type ~= "Figure" then return nil end
    local n = order[el.identifier]
    return pandoc.Para({ pandoc.Strong(pandoc.Str("[FIG " .. n .. " about here]")) })
  end,

  Cite = function(el)
    if not enabled then return nil end
    local c = el.citations[1]
    if #el.citations == 1 and order[c.id] then
      return pandoc.Str("Figure\u{00A0}" .. order[c.id])
    end
  end,

  Pandoc = function(doc)
    if not enabled then return nil end
    -- captions page
    local blocks = doc.blocks
    blocks:insert(pandoc.RawBlock("openxml",
      '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'))
    blocks:insert(pandoc.Header(2, "Figure captions", pandoc.Attr("figure-captions", { "unnumbered" })))
    for _, f in ipairs(figs) do
      local para = pandoc.Inlines({ pandoc.Strong("Figure " .. f.n .. ".") , pandoc.Space() })
      para:extend(f.caption)
      blocks:insert(pandoc.Para(para))
    end
    -- manifest for make-figures.R
    local fh = io.open(manifest_path, "w")
    if fh then
      fh:write("number,label,source,caption\n")
      for _, f in ipairs(figs) do
        fh:write(table.concat({ f.n, csv(f.id), csv(f.src),
          csv(pandoc.utils.stringify(f.caption)) }, ",") .. "\n")
      end
      fh:close()
    else
      io.stderr:write("submission.lua: could not write " .. manifest_path .. "\n")
    end
    doc.blocks = blocks
    return doc
  end,
}

return { pass1, pass2, pass3 }
