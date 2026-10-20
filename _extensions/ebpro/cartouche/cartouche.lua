-- cartouche.lua: Quarto metadata colophon filter
-- Emits: HTML colophon div + JSON-LD | revealjs footer + end-slide | typst colophon

local AI_TEXT = "Ce document a bénéficié de l'assistance d'outils d'intelligence artificielle générative pour certaines phases de conception, rédaction, structuration ou amélioration. Les contenus ont été relus, vérifiés et validés par l'auteur responsable du support, qui demeure seul responsable de leur exactitude scientifique et pédagogique."

local function str(meta, key)
  if meta and meta[key] then
    return pandoc.utils.stringify(meta[key])
  end
  return ""
end

local function urls(meta)
  local gh = str(meta, "cartouche-github-url")
  local br = str(meta, "cartouche-branch")
  local sha = str(meta, "cartouche-sha-full")
  local base = str(meta, "cartouche-base-url")
  local tag = str(meta, "cartouche-stable-tag")
  return {
    repo = gh,
    branch = gh .. "/tree/" .. br,
    commit = gh .. "/commit/" .. sha,
    tags = gh .. "/tags",
    develop = base .. "/" .. br .. "/",
    deed = str(meta, "cartouche-license-url"),
    spdx = str(meta, "cartouche-spdx-url"),
    tag = tag,
    stable_gh = tag ~= "" and (gh .. "/releases/tag/" .. tag) or "",
    stable_web = tag ~= "" and (base .. "/releases/" .. tag .. "/") or "",
  }
end

local function jsonld(meta, u)
  local ver = str(meta, "cartouche-stable-tag")
  if ver == "" then
    ver = str(meta, "cartouche-branch") .. "@" .. str(meta, "cartouche-sha")
  end
  local ld = {
    ["@context"] = "https://schema.org",
    ["@type"] = "LearningResource",
    name = str(meta, "title") or "Support de cours",
    inLanguage = "fr",
    learningResourceType = "support de cours",
    author = { ["@type"] = "Person", name = str(meta, "cartouche-author") },
    creator = { ["@type"] = "Person", name = str(meta, "cartouche-author") },
    license = u.deed,
    version = ver,
    dateCreated = str(meta, "cartouche-commit-date"),
    dateModified = str(meta, "cartouche-build-date"),
    url = u.develop,
    isBasedOn = u.repo,
    description = "Transparence IA : " .. AI_TEXT,
  }
  return '<script type="application/ld+json">' .. quarto.json.encode(ld) .. '</script>'
end

local function colophon_html(meta, u)
  local tag = str(meta, "cartouche-stable-tag")
  local stable_li
  if tag == "" then
    stable_li = '<li><span class="k">Derni\xe8re version stable :</span> aucune version stable publi\xe9e</li>'
  else
    stable_li = '<li><span class="k">Derni\xe8re version stable :</span> <a href="' .. u.stable_gh .. '" target="_blank" rel="noopener">source GitHub (' .. tag .. ')</a> \xc2\xb7 <a href="' .. u.stable_web .. '" target="_blank" rel="noopener">rendu web (' .. tag .. ')</a></li>'
  end
  local spdx = str(meta, "cartouche-license-spdx")
  local spdx_pretty = spdx:gsub("%-", " ")
  return '<div class="cartouche-colophon" role="contentinfo">'
    .. '<p><strong>\xc0 propos de ce support</strong></p>'
    .. '<p><a class="badge" href="' .. u.deed .. '" rel="license">' .. spdx_pretty .. '</a>'
    .. ' SPDX: <a href="' .. u.spdx .. '">' .. spdx .. '</a></p>'
    .. '<ul class="cartouche-fields">'
    .. '<li>D\xc3\xa9p\xc3\xb4t: <a href="' .. u.repo .. '"><code>' .. str(meta, "cartouche-repo") .. '</code></a></li>'
    .. '<li>Branche <a href="' .. u.branch .. '"><code>' .. str(meta, "cartouche-branch") .. '</code></a> \xc2\xb7 commit <a href="' .. u.commit .. '"><code>' .. str(meta, "cartouche-sha") .. '</code></a> (' .. str(meta, "cartouche-commit-date") .. ') \xc2\xb7 compil\xc3\xa9 ' .. str(meta, "cartouche-build-date") .. '</li>'
    .. '<li>Cette version: <a href="' .. u.develop .. '">rendu web</a></li>'
    .. stable_li
    .. '</ul>'
    .. '<p class="cartouche-ai"><strong>Transparence IA :</strong> ' .. AI_TEXT .. '</p>'
    .. '<p><a href="' .. u.tags .. '">Historique des versions</a></p>'
    .. '</div>'
end

local function typst_block(meta, u)
  local spdx = str(meta, "cartouche-license-spdx")
  local tag = str(meta, "cartouche-stable-tag")
  local stable
  if tag == "" then
    stable = "Aucune version stable publi\xc3\xa9e"
  else
    stable = "Version stable: " .. tag .. " (" .. u.stable_web .. ")"
  end
  return "#v(1em)\n#line(length: 100%)\n#v(0.5em)\n"
    .. "#set text(size: 8pt)\n"
    .. "#heading(level: 3, numbering: none)[\xc0 propos de ce support]\n"
    .. "Licence " .. spdx:gsub("%-", " ") .. " \\ (`link(\"" .. u.deed .. "\")[deed]`)\n"
    .. "D\xc3\xa9p\xc3\xb4t: " .. str(meta, "cartouche-repo") .. " \\xB7 Branche: " .. str(meta, "cartouche-branch")
    .. " \\xB7 Commit: " .. str(meta, "cartouche-sha") .. " (" .. str(meta, "cartouche-commit-date") .. ")\n"
    .. stable .. "\n"
    .. "#strong[Transparence IA :] " .. AI_TEXT .. "\n"
end

-- Filter table
return {
  {
    Meta = function(m)
      -- Guard: skip if not configured
      if str(m, "cartouche-repo") == "" then return nil end

      if FORMAT:isHTML() then
        local u = urls(m)
        local script = jsonld(m, u)
        -- inject JSON-LD via include-in-header
        local iih = m["include-in-header"]
        if iih and iih.t == "Inlines" then
          m["include-in-header"] = pandoc.Inlines{ pandoc.RawInline("html", script) }:extend(iih)
        else
          m["include-in-header"] = pandoc.Inlines{ pandoc.RawInline("html", script) }
        end
      end

      if FORMAT:matches('revealjs') then
        local u = urls(m)
        local footer = str(m, "cartouche-license-spdx"):gsub("%-", " ") .. " · " .. str(m, "cartouche-branch") .. " · " .. str(m, "cartouche-build-date"):sub(1,10)
        m.footer = pandoc.Inlines{ pandoc.RawInline("html", footer) }
      end

      return m
    end
  },
  {
    Document = function(doc)
      local m = PANDOC.document[1].meta or {}
      if str(m, "cartouche-repo") == "" then return nil end
      local u = urls(m)

      if FORMAT:isHTML() then
        doc.content:insert(pandoc.RawBlock("html", colophon_html(m, u)))
        return doc
      end

      if FORMAT:matches('revealjs') then
        local endSlide = '<section id="cartouche-fin"><div style="display:flex;flex-direction:column;justify-content:center;height:100%;font-size:0.65em;opacity:0.85;">'
          .. '<p><strong>Transparence IA :</strong> ' .. AI_TEXT .. '</p>'
          .. '<p>' .. str(m, "cartouche-license-spdx"):gsub("%-", " ") .. ' · <a href="' .. u.repo .. '">' .. str(m, "cartouche-repo") .. '</a></p>'
          .. '</div></section>'
        doc.content:insert(pandoc.RawBlock("html", endSlide))
        return doc
      end

      if FORMAT:matches('typst') then
        doc.content:insert(pandoc.RawBlock("typst", typst_block(m, u)))
        return doc
      end
    end
  }
}
