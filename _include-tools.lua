-- Lua filter to inject a tools snippet based on `jupyter` frontmatter
-- It looks for a snippet file in `_quarto-utils/snippets/<kernel>.qmd`
-- and prepends its parsed blocks to the document.
-- If `tools` is specified in frontmatter, it creates a custom tools display.

function Pandoc(doc)
  local meta = doc.meta or {}
  local kernel = nil
  local tools_list = nil

  -- Get kernel from jupyter frontmatter
  if meta.jupyter then
    kernel = pandoc.utils.stringify(meta.jupyter)
  end
  if not kernel then
    return doc
  end

  -- Check if custom tools list is provided
  if meta.tools then
    -- Convert tools list to space-separated string
    local tools_table = {}
    if type(meta.tools) == "table" then
      for i, v in ipairs(meta.tools) do
        table.insert(tools_table, pandoc.utils.stringify(v))
      end
      tools_list = table.concat(tools_table, " ")
    else
      tools_list = pandoc.utils.stringify(meta.tools)
    end
  end

  -- If custom tools specified, create custom snippet. If not, do nothing.
  if not tools_list then
    return doc
  end

  -- If we reach here, tools_list is present: create custom snippet
  if tools_list then
    -- Resolve tools-common.sh path relative to this filter file when possible
    local tools_sh = '_quarto-utils/tools-common.sh'
    -- Try to get the filter script directory via debug info
    local ok, info = pcall(debug.getinfo, 1, 'S')
    if ok and info and info.source and info.source:sub(1,1) == '@' then
      local script_path = info.source:sub(2)
      local script_dir = script_path:match('(.*/)') or ''
      if script_dir ~= '' then
        tools_sh = script_dir .. 'tools-common.sh'
      end
    end

    -- Fallback: if tools_sh doesn't exist, try project-relative path
    local ftest = io.open(tools_sh, 'r')
    if ftest then
      ftest:close()
    else
      -- prefer project-root relative location
      local proj_tools = '_quarto-utils/tools-common.sh'
      local f2 = io.open(proj_tools, 'r')
      if f2 then
        f2:close()
        tools_sh = proj_tools
      else
        -- final fallback: absolute path inside workspace
        tools_sh = '/home/jovyan/work/_quarto-utils/tools-common.sh'
      end
    end

    -- Ensure we also include environment info (env) by default
    if not tools_list:match('env') then
      tools_list = tools_list .. ' env'
    end

    -- Run the tools-common.sh script to produce a markdown table of tools
    local cmd = string.format('bash %s %s "%s"', tools_sh, kernel, tools_list)
    local fh = io.popen(cmd)
    local result = nil
    if fh then
      result = fh:read('*a')
      fh:close()
    end

    if not result or result == '' then
      -- no output: do nothing
      return doc
    end

    -- trim whitespace
    result = result:gsub('^%s+', ''):gsub('%s+$', '')

    -- Parse the markdown table produced by the script
    local table_parsed = pandoc.read(result, 'markdown')

    -- Parse table rows into a map keyed by normalized tool name
    local tool_map = {}
    for line in result:gmatch("[^\r\n]+") do
      if line:match('^|') and not line:match('^|%s*-') and not line:match('Tool%s*|%s*Info') then
        local a,b = line:match('^|%s*([^|]-)%s*|%s*([^|]-)%s*|')
        if a and b then
          local display = a:gsub('%s+$','') .. ' ' .. b:gsub('%s+$',''):gsub('%*',''):gsub('`','')
          -- normalize key (lowercase letters only)
          local key = a:lower():gsub('[^%a]','')
          tool_map[key] = display
        end
      end
    end

    -- Preferred order: runtimes, build tools, containers, VCS, env, extras
    local order = {'java','maven','gradle','docker','git','env','node','python','sdk'}

    local compact_entries = {}
    local tool_list_items = {}
    for _, k in ipairs(order) do
      if tool_map[k] then
        table.insert(compact_entries, tool_map[k])
        table.insert(tool_list_items, '- ' .. tool_map[k])
      end
    end

    local compact_md = table.concat(compact_entries, ' • ')
    local tools_list_md = table.concat(tool_list_items, '\n')

    -- Build final compact string in the requested order
    local order = {'env','java','maven','gradle','docker','git','node','python','sdk'}
    local ordered_entries = {}
    for _, k in ipairs(order) do
      if tool_map[k] then table.insert(ordered_entries, tool_map[k]) end
    end
    local ordered_compact = table.concat(ordered_entries, ' • ')

    -- Final compact content: kernel then ordered entries
    local compact_all = string.format('**Jupyter Kernel:** `%s`\n\n%s', kernel, ordered_compact)

    -- Sentences to add
    local gen_sentence = 'Ce support a été généré par Quarto : les cellules sont exécutées par le noyau indiqué lors du rendu.'
    local ai_sentence = 'Certaines parties ont été rédigées avec l’assistance d’un modèle de langage ; le contenu a été relu et validé par l’auteur.'

    -- Single compact block used for both notes and slides to avoid duplicate insertion
    local block_md = string.format('## Environnement et reproductibilite\n\n%s\n\n%s\n\n%s', compact_all, gen_sentence, ai_sentence)
    local block_parsed = pandoc.read(block_md, 'markdown')
    -- make it visible in both profiles (notes and slides)
    local combined_attr = {['when-profile']='notes slides'}
    local tools_div = pandoc.Div(block_parsed.blocks, pandoc.Attr('', {'tools-block','content-visible'}, combined_attr))

    -- find insertion index: after first level-1 Header if any
    -- Remove any existing injected tools blocks or headers to avoid duplicates
    for i = #doc.blocks, 1, -1 do
      local blk = doc.blocks[i]
      if blk.t == 'Div' and blk.attr and blk.attr.classes then
        for _, cls in ipairs(blk.attr.classes) do
          if cls == 'tools-block' or cls == 'tools-slide' or cls == 'tools-compact' then
            table.remove(doc.blocks, i)
            break
          end
        end
      end
      -- Also remove any existing header titled 'Environnement et reproductibilite' and a few following blocks
      if blk.t == 'Header' and blk.level == 2 then
        local title = pandoc.utils.stringify(blk)
        if title and title:lower():match('environnement') then
          -- remove header and up to next 6 blocks (likely the injected content)
          for j = 0,6 do
            if doc.blocks[i+1] then
              table.remove(doc.blocks, i+1)
            end
          end
          table.remove(doc.blocks, i)
        end
      end
    end

    local insert_at = 1
    for idx, blk in ipairs(doc.blocks) do
      if blk.t == 'Header' and blk.level == 1 then
        insert_at = idx + 1
        break
      end
    end

    -- insert single tools_div at insert_at
    table.insert(doc.blocks, insert_at, tools_div)
    return doc
  end
  -- If code reaches here, nothing else to do
  return doc
end
