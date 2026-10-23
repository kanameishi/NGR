-- page-footer.lua
-- Appends the page footer to book/html output, built from metadata.
-- Same data-driven pattern as footer.lua (revealjs).
-- footer-title (default: the book or document title) and footer-meta, the
-- identity NGR derives from params.yml or a declared footer-meta; without
-- either, the footer carries only the title and the render stamp.

local function stringify(v)
  return v and pandoc.utils.stringify(v) or ""
end

local function escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local title_text = ""
local meta_text = ""

function Meta(meta)
  title_text = stringify(meta["footer-title"])
  -- Book renders: keep the report title constant across chapter pages.
  if title_text == "" and type(meta.book) == "table" and meta.book.title then
    title_text = stringify(meta.book.title)
  end
  if title_text == "" then title_text = stringify(meta.title) end
  meta_text = stringify(meta["footer-meta"])
  local stamp = pandoc.system.environment()["NGR_RENDER_STAMP"] or ""
  if stamp ~= "" and meta_text ~= "" then meta_text = meta_text .. " · " .. stamp end
  if stamp ~= "" and meta_text == "" then meta_text = stamp end
end

function Pandoc(doc)
  if title_text == "" and meta_text == "" then
    return nil
  end
  local html = '<div class="page-footer column-body"><div class="page-footer__inner"><div class="page-footer__content">'
  if title_text ~= "" then
    html = html .. '<div class="page-footer__title">' .. escape(title_text) .. '</div>'
  end
  html = html .. '<div class="page-footer__meta">' .. escape(meta_text) .. '</div></div></div></div>'
  table.insert(doc.blocks, pandoc.RawBlock('html', html))
  return doc
end
