-- Minimal test filter to verify execution
function Meta(meta)
  -- Always write to log to prove filter runs
  local logfile = io.open('/home/jovyan/work/filter-test.log', 'w')
  if logfile then
    logfile:write("Filter executed!\n")
    if meta.image then
      local img = pandoc.utils.stringify(meta.image)
      logfile:write("Original image: " .. img .. "\n")
      -- Try to resolve
      local resolved = '/home/jovyan/work/_quarto-utils/MyMedia/images/optimized/ian-taylor-joqjbvo1p9g-unsplash-docker-400.webp'
      local f = io.open(resolved, 'r')
      if f then
        f:close()
        logfile:write("File exists: " .. resolved .. "\n")
        meta.image = pandoc.MetaString('_quarto-utils/MyMedia/images/optimized/ian-taylor-joqjbvo1p9g-unsplash-docker-400.webp')
        logfile:write("Set meta.image to relative path\n")
      else
        logfile:write("File NOT found: " .. resolved .. "\n")
      end
    else
      logfile:write("No image in meta\n")
    end
    logfile:close()
  end
  return meta
end
