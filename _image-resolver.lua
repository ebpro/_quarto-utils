-- Resolve short image slugs in frontmatter to actual optimized image files.
-- Usage: add this filter early in filters list in _quarto.yml

local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close(); return true end
  return false
end

local WORKSPACE_ROOT = '/home/jovyan/work'
-- try to detect runtime working dir if workspace constant not valid
local function detect_root()
  if file_exists(WORKSPACE_ROOT .. '/_quarto-utils') then return WORKSPACE_ROOT end
  local env = os.getenv('PWD')
  if env and file_exists(env .. '/_quarto-utils') then return env end
  -- try current dir
  local ok, p = pcall(io.popen, 'pwd')
  if ok and p then
    local cwd = p:read('*a')
    p:close()
    cwd = cwd and cwd:gsub('%s+$','')
    if cwd and file_exists(cwd .. '/_quarto-utils') then return cwd end
  end
  return WORKSPACE_ROOT
end
WORKSPACE_ROOT = detect_root()

local function read_manifest(manifest_path)
  local f = io.open(manifest_path, 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  -- try simple JSON parse using pandoc if available
  local ok, manifest = pcall(pandoc.utils.json_decode or function(x) return nil end, s)
  if ok and manifest then return manifest end
  return nil
end

function Meta(meta)
  local image = nil
  if meta.image then
    if type(meta.image) == 'string' then image = meta.image end
    if type(meta.image) == 'table' and meta.image.t == 'MetaInlines' then
      image = pandoc.utils.stringify(meta.image)
    end
  end

  if not image then return meta end

  -- If image looks like a path (contains / or .ext), leave it alone
  if image:match('/') or image:match('%.%w+$') then
    return doc
  end

  -- image is a slug; try manifest first
  local manifest = nil
  local manifest_paths = {
    WORKSPACE_ROOT .. '/_quarto-utils/image-manifest.json',
    '_quarto-utils/image-manifest.json'
  }
  for _, p in ipairs(manifest_paths) do
    if file_exists(p) then
      manifest = read_manifest(p)
      if manifest then break end
    end
  end

  local resolved = nil
  if manifest and manifest[image] then
    local entry = manifest[image]
    if entry['400'] then
      local rel = '_quarto-utils/MyMedia/images/optimized/' .. entry['400']
      local abs = WORKSPACE_ROOT .. '/' .. rel
      if file_exists(abs) then resolved = rel end
    end
  end

  -- fallback: try standard filenames
  if not resolved then
    local rel_candidates = {
      '_quarto-utils/MyMedia/images/optimized/' .. image .. '-400.webp',
      '_quarto-utils/MyMedia/images/optimized/' .. image .. '.webp',
      '_quarto-utils/MyMedia/images/optimized/' .. image .. '-800.webp'
    }
    for _, rel in ipairs(rel_candidates) do
      local abs = WORKSPACE_ROOT .. '/' .. rel
      if file_exists(abs) then resolved = rel; break end
      -- try relative (pandoc working dir)
      if file_exists(rel) then resolved = rel; break end
    end
  end

  -- final fallback: leave as-is
  if resolved then
    meta.image = pandoc.MetaString(resolved)
    if not meta['image-alt'] then
      meta['image-alt'] = pandoc.MetaString(image:gsub('%-',' '))
    end
    -- diagnostic log
    local logpath = WORKSPACE_ROOT .. '/.image-resolver.log'
    local lf = io.open(logpath,'a')
    if lf then lf:write('RESOLVED: '..image..' -> '..resolved.."\n") lf:close() end
  end
  if not resolved then
    local logpath = WORKSPACE_ROOT .. '/.image-resolver.log'
    local lf = io.open(logpath,'a')
    if lf then lf:write('UNRESOLVED: '..image.."\n") lf:close() end
  end

  return meta
end
