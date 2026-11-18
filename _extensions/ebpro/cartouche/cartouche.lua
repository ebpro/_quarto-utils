-- cartouche.lua -- cartouche de meta-donnees PARTAGE (extension ebpro/cartouche).
--
-- Revision finale, surface signee par l'humain le 18 novembre 2026. Mecanismes
-- transplantes tels quels depuis la revision de campagne preservee sous
-- /Users/bruno/tmp/cartouche-l1-20261118/preserved/cartouche-campagne.lua (817 lignes
-- lues ici) ; seule la SURFACE emise est reecrite, et les branches de provenance
-- sont conservees telles qu'elles ont ete mesurees.
--
-- Mecanismes du donneur qui sont load-bearing, et pourquoi (faits de flotte mesures
-- les 12, 16, 17 et 18 novembre 2026) :
--   * Emission par le hook `Pandoc` en BLOCS NATIFS (Div > Header(3) + Para +
--     BulletList). `doc.content` vaut nil dans ce pipeline : muter par `content`
--     fait rougir le rendu. Un hook de type liste de blocs emet SIX fois par page
--     (proscrit). Le hook rend donc un document reconstruit.
--   * Jamais de RawBlock("html") pour ce qui doit survivre : le redacteur typst
--     abandonne le brut HTML, le cartouche ne vivrait que sur une jambe.
--   * Provenance de la page rendue : `QUARTO_DOCUMENT_PATH` (qui porte le DOSSIER du
--     document rendu), puis son `.git` propre — repertoire OU gitfile —, lecture de
--     HEAD puis de la ref lache puis de packed-refs, avec repli `git -C <dir>
--     rev-parse HEAD`. PAS de remontee au `.git` le plus proche : mesuree le
--     17 novembre, elle publiait le sha du projet englobant sous l'etiquette de la
--     page rendue. Sous un montage declare de l'assemblage, la seule autorite
--     disponible est le sha que le SUPERPROJET declare pour ce chemin (voie gitlink).
--   * Provenance du FOURNISSEUR : ancrage sur `QUARTO_PROJECT_DIR` suivi de
--     `_quarto-utils`, avec GARDE D'IDENTITE. Un chemin nu est un faussaire mesure :
--     `./_quarto-utils` est relatif au dossier du DOCUMENT et publie le sha d'un
--     fournisseur voisin sans que la garde par existence le voie.
--   * Le refus de git `detected dubious ownership` a ete rencontre dans le conteneur
--     de rendu : la lecture sans binaire passe outre, et chaque appel binaire est
--     reessaye en forme `safe.directory`.
--   * `FORMAT` arrive en chaine brute : aucune methode n'est appelee dessus ici.
--   * Aucune valeur inventee : une resolution qui echoue n'emet NI sha NI lien, et le
--     texte publie le dit. Toute emission est sous `pcall` : un filtre ne doit
--     JAMAIS rompre un rendu.
--
-- Surface emise (signee) : titre « A propos de ce support », une ligne plane de
-- transparence, puis QUATRE puces — depot et engagement rendu, configuration
-- partagee, licence, politique. Sont retirees de cette surface, et d'ici : toute
-- ligne de generation, toute date, tout complement de sha long entre parentheses,
-- toute reference de requete, tout nom de branche du fournisseur, et la ligne
-- d'auteur (l'auteur est au bloc de titre).
--
-- Identite de la revision. Le donneur ne portait AUCUNE trace de chargement (verifie
-- par comptage sur ses 817 lignes) : la ligne `LOADED` demandee par le contrat
-- d'execution est donc ICI AJOUTEE, pas conservee. Elle nomme un jeton de revision
-- ASCII, non un resume de hachage : cette session ne dispose d'aucun outil de
-- hachage (shell refuse, aucun outil `sha256` dans le catalogue), et ecrire ici huit
-- caracteres hexadecimaux non calcules serait exactement la classe de faute que ce
-- corpus a deja payee. La porte de validation relit donc le jeton dans le fichier et
-- dans la console ; le resume de hachage, lui, se lit par une session qui sait hacher.
-- Cet en-tete ne porte pas lui-meme le mot marque de la ligne de trace : un fichier
-- ne peut pas se compter lui-meme.

local CLASS = "cartouche-colophon"
local UTILS = "_quarto-utils"
local POLICY_DOC = "docs/politique-de-production.md"
local POLICY_ID = "politique-de-production"
local VERSION_FILE = "_cartouche-version.json"
local REVID = "cartouche-20261118-final-2"
local CC_BYNC_DEED = "https://creativecommons.org/licenses/by-nc/4.0/"
local GH_HOSTS = { ["github.com"] = true, ["www.github.com"] = true }

local function trim(s)
  if s == nil then
    return ""
  end
  s = tostring(s)
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function env(name)
  local ok, v = pcall(os.getenv, name)
  if not ok or type(v) ~= "string" then
    return ""
  end
  return trim(v)
end

-- Lecture entiere d'un fichier, ou nil. Sert d'autorite d'EXISTENCE : une clef
-- de garde ne se prend jamais sur une liste de repertoire.
local function slurp(path)
  local ok, f = pcall(io.open, path, "rb")
  if not ok or not f then
    return nil
  end
  local ok2, s = pcall(f.read, f, "*a")
  pcall(f.close, f)
  if not ok2 or type(s) ~= "string" then
    return nil
  end
  return s
end

-- Chaine vide quand la clef est absente : le reste du filtre ne voit jamais nil.
local function meta_str(meta, key)
  if meta == nil then
    return ""
  end
  local v = meta[key]
  if v == nil then
    return ""
  end
  local ok, s = pcall(pandoc.utils.stringify, v)
  if not ok or s == nil then
    return ""
  end
  return trim(tostring(s))
end

local function is_sha(s)
  if type(s) ~= "string" then
    return false
  end
  if not s:match("^[0-9a-f]+$") then
    return false
  end
  return #s >= 7 and #s <= 40
end

local function norm_dir(p)
  if p == nil then
    return ""
  end
  return trim(p):gsub("/+$", "")
end

local function parent_of(p)
  if p == nil or p == "" then
    return nil
  end
  return p:match("^(.*)/[^/]+$")
end

-- Nom de fichier sans chemin, puis sans extension. Le canal est la valeur BRUTE de
-- `QUARTO_DOCUMENT_PATH` : c'est elle qui porte le document rendu, mesuree
-- `[/workdir/<montage>]` sous assemblage pendant que `QUARTO_PROJECT_DIR` vaut
-- `[/workdir]`.
local function file_of(p)
  p = trim(p or "")
  if p == "" then
    return ""
  end
  return p:match("([^/]+)$") or p
end

local function stem_of(name)
  return trim(name or ""):match("^(.*)%.[^.%/]+$") or trim(name or "")
end

-- --------------------------------------------------------------------------
-- Lecture d'un depot git SANS binaire : HEAD, puis ref lache, puis packed-refs.
-- C'est le chemin qui marche aussi quand le couloir de rendu tourne sous un uid
-- different du proprietaire du depot (le refus `dubious ownership` n'atteint
-- alors pas la mesure).
-- --------------------------------------------------------------------------

local function sha_from_gitdir(gd)
  local head = slurp(gd .. "/HEAD")
  if head == nil then
    return nil
  end
  head = trim(head)
  if head == "" then
    return nil
  end
  local ref = head:match("^ref:%s*(%S+)$")
  if ref == nil then
    if is_sha(head) then
      return head
    end
    return nil
  end
  local loose = slurp(gd .. "/" .. ref)
  if loose ~= nil then
    local v = trim(loose)
    if is_sha(v) then
      return v
    end
  end
  local packed = slurp(gd .. "/packed-refs")
  if packed ~= nil then
    for line in packed:gmatch("[^\n]+") do
      local sha, name = line:match("^(%x+)%s+(%S+)$")
      if sha ~= nil and name == ref and is_sha(sha) then
        return sha
      end
    end
  end
  return nil
end

-- gitdir d'un repertoire candidate : `.git` repertoire ou `.git` fichier.
-- Conserve du donneur pour l'appel du fournisseur ; la resolution de la page rendue
-- passe par `resolved_gitdir`, qui est la version qui signe l'inaccessibilite.
local function gitdir_of(root)
  if root == nil or root == "" then
    return nil
  end
  local as_head = slurp(root .. "/.git/HEAD")
  if as_head ~= nil then
    return root .. "/.git", "dir"
  end
  local gf = slurp(root .. "/.git")
  if gf ~= nil then
    local gd = trim(gf):match("^gitdir:%s*(.+)$")
    if gd ~= nil then
      if gd:sub(1, 1) ~= "/" then
        gd = root .. "/" .. gd
      end
      return gd, "gitfile"
    end
  end
  return nil
end

local function pipe_git(args)
  local ok, out = pcall(pandoc.pipe, "git", args, "")
  if not ok or type(out) ~= "string" then
    return nil
  end
  out = trim(out)
  if out == "" then
    return nil
  end
  return out
end

-- Repli binaire, avec la forme `safe.directory` qui a ete observee necessaire
-- sous couloir (le conteneur de rendu rencontre le refus de git et s'en releve).
local function pipe_git_root(root)
  local v = pipe_git({ "-C", root, "rev-parse", "HEAD" })
  if v ~= nil and is_sha(v) then
    return v, "binaire"
  end
  v = pipe_git({ "-c", "safe.directory=*", "-C", root, "rev-parse", "HEAD" })
  if v ~= nil and is_sha(v) then
    return v, "binaire-safe-directory"
  end
  return nil, nil
end

-- --------------------------------------------------------------------------
-- Identite et outils de resolution. Une identite non etablie n'est jamais une
-- identite verifiee ; un projet englobant ne peut pas tenir lieu de depot de la
-- page rendue.
-- --------------------------------------------------------------------------

-- `remote.origin.url` lu dans le config du gitdir, sans binaire.
local function origin_from_config(gd)
  if gd == nil then
    return nil
  end
  local cfg = slurp(gd .. "/config")
  if cfg == nil then
    return nil
  end
  local sect = false
  for line in cfg:gmatch("[^\n]+") do
    local s = trim(line)
    if s:match("^%[") then
      sect = (s:find('[remote "origin"]', 1, true) ~= nil)
    elseif sect then
      local v = s:match("^url%s*=%s*(.+)$")
      if v ~= nil then
        return trim(v)
      end
    end
  end
  return nil
end

local function origin_of(root, gd)
  local v = origin_from_config(gd)
  if v == nil or v == "" then
    v = pipe_git({ "-C", root, "config", "--get", "remote.origin.url" })
  end
  if v == nil or v == "" then
    return nil
  end
  return v
end

-- Entrees de `.gitmodules` d'un superprojet (au niveau de rendu).
local function submodule_entries(root)
  local body = slurp(norm_dir(root) .. "/.gitmodules")
  if body == nil then
    return {}
  end
  local list, cur = {}, nil
  for line in body:gmatch("[^\n]+") do
    local s = trim(line)
    local name = s:match('^%[submodule "(.-)"%]$')
    if name ~= nil then
      cur = { name = name }
      list[#list + 1] = cur
    elseif cur ~= nil then
      local k, v = s:match("^(%a[%w%-]*)%s*=%s*(.+)$")
      if k ~= nil then
        cur[k] = trim(v)
      end
    end
  end
  return list
end

-- Le document siege-t-il dans un montage declare du projet rendu ? `rel` est la
-- valeur brute de `QUARTO_DOCUMENT_PATH` rapportee a `QUARTO_PROJECT_DIR`.
-- Retourne ("monte", entree) | ("non-monte", nil).
-- Fait consigne, NON branche : la revision de campagne deja portait cette fonction
-- sans aucun appel (mesure du 18 novembre : definie ici comme ailleurs, 0 appel).
-- Sa semantique — le montage courant ne couvre pas le engagement declare — est
-- exactement ce qui manque a la branche de l'assemblage. Elle est conservee telle
-- quelle, et sa mise en service est un acte distinct du proprietaire : la surface
-- signee ne publie aucune reserve, donc rien ici ne depend de son branchement.
local function mount_covering(root, rel)
  if rel == nil or rel == "" then
    return "non-monte", nil
  end
  for _, e in ipairs(submodule_entries(root)) do
    local p = norm_dir(e.path or "")
    if p ~= "" and (p == rel or rel:sub(1, #p + 1) == p .. "/" or p:sub(1, #rel + 1) == rel .. "/") then
      return "monte", e
    end
  end
  return "non-monte", nil
end

-- gitdir REELLEMENT LISIBLE pour un repertoire : `.git` repertoire, ou `.git`
-- fichier dont le `gitdir:` est joint au repertoire QUI LE PORTE (regle git)
-- quand il est relatif. Un `gitdir:` absolu hors du conteneur est signale
-- inaccessible et ne doit JAMAIS etre remplace par un depot voisin ou parent.
-- Retourne (gitdir, forme) | (nil, "gitdir-inaccessible") | (nil, nil).
local function resolved_gitdir(root)
  root = norm_dir(root)
  if root == "" then
    return nil, nil
  end
  if slurp(root .. "/.git/HEAD") ~= nil then
    return root .. "/.git", "dir"
  end
  local gf = slurp(root .. "/.git")
  if gf == nil then
    return nil, nil
  end
  local gd = trim(gf):match("^gitdir:%s*(.+)$")
  if gd == nil then
    return nil, nil
  end
  if gd:sub(1, 1) ~= "/" then
    gd = root .. "/" .. gd
  end
  gd = norm_dir(gd)
  if slurp(gd .. "/HEAD") ~= nil then
    return gd, "gitfile"
  end
  return nil, "gitdir-inaccessible"
end

-- Engagement d'un repertoire : lecture sans binaire en premier (le refus de git
-- `dubious ownership` a ete rencontre dans le conteneur de rendu), binaire
-- seulement si un `.git` existe mais ne se lit pas. Jamais de repli qui remonte
-- hors du repertoire demande. Retourne (sha, gitdir, forme).
local function head_of(root)
  local gd, kind = resolved_gitdir(root)
  if gd ~= nil then
    local s = sha_from_gitdir(gd)
    if s ~= nil then
      return s, gd, "direct-" .. tostring(kind)
    end
    if kind == "gitfile" then
      local s2 = pipe_git({ "-C", norm_dir(root), "rev-parse", "HEAD" })
      if s2 ~= nil and is_sha(s2) then
        return s2, gd, "direct-" .. tostring(kind) .. "-binaire"
      end
      return nil, gd, "gitdir-sans-tete"
    end
    return nil, gd, "tete-illisible"
  end
  if kind == "gitdir-inaccessible" then
    return nil, nil, kind
  end
  return nil, nil, nil
end

-- --------------------------------------------------------------------------
-- Identite d'un depot, en formes canoniques des deux cotes.
-- Une origine de chemin local (`/…`, `file://…` : les harnais de pre-validation et
-- les clones de travail) NE PEUT PAS exprimer l'organisation. L'exiger rendrait le
-- garde incapable de passer localement ; s'en contenter rendrait un depot homonyme
-- d'une autre organisation acceptable. La force reellement verifiee est donc publiee
-- dans `data-git-source` (`-organisation` ou `-nom-seul`), jamais masque ni surfaite.
-- --------------------------------------------------------------------------

-- Forme canonique d'une reference de depot : `hote/owner/nom`, `owner/nom` ou
-- `nom`, avec scheme, credentials et `.git` retires. Sert a comparer, jamais a
-- fabriquer un chemin.
local function canon_repo(u)
  u = trim(u or "")
  if u == "" then
    return nil
  end
  u = norm_dir(u)
  u = u:gsub("%.git$", "")
  u = u:gsub("^%a[%w+.-]*://", "")
  u = u:gsub("^[^/@]+@", "")
  u = u:gsub("^([^:/]+):", "%1/")
  u = norm_dir(u)
  if u == "" then
    return nil
  end
  return u
end

local function repo_name(c)
  if c == nil then
    return nil
  end
  return c:match("([^/]+)$")
end

-- Retourne la force verifiee (`organisation`, `nom-seul`, `nom`) ou nil.
-- Garde NON tautologique par construction : la valeur declaree ne vient jamais du
-- cote compare. `external_declared` est vrai quand la reference vient d'une source
-- EXTERNE a la page rendue (fichier de version de l'execution, ou cle native du
-- projet). Quand rien n'est declare, la valeur est publiee avec la force `declaree-
-- par-le-depot` : l'accord est alors auto-referente et ne vaut pas verification.
-- Publier une force inventee serait le defaut exactement inverse du silence.
local function repo_identity(origin_raw, declared, external_declared)
  local co, cd = canon_repo(origin_raw), canon_repo(declared)
  if co == nil or cd == nil then
    return nil
  end
  local no, nd = repo_name(co), repo_name(cd)
  if no == nil or nd == nil or no ~= nd then
    return nil
  end
  if cd:find("/", 1, true) == nil then
    return "nom"
  end
  if co:sub(-#cd) == cd then
    return "organisation"
  end
  local raw = trim(origin_raw or "")
  if raw:match("^/") ~= nil or raw:lower():match("^file:") ~= nil then
    return "nom-seul"
  end
  if not external_declared then
    return "declaree-par-le-depot"
  end
  return nil
end

-- --------------------------------------------------------------------------
-- Engagement DECLARE par le superprojet pour un chemin de montage. Commande
-- choisie : `git -C <racine rendue> rev-parse HEAD:<chemin-de-montage>` (elle rend
-- directement les quarante caracteres ; `ls-tree` imposerait un decoupage de sa
-- sortie, donc une seconde chance de se tromper). La forme `safe.directory` est
-- reessayee : le refus d'appartenance a ete rencontre dans le conteneur de rendu.
-- Un echec n'est JAMAIS remplace par une valeur devinee.
-- --------------------------------------------------------------------------
local function gitlink_declared(proj, mpath)
  local spec = "HEAD:" .. mpath
  local v = pipe_git({ "-C", proj, "rev-parse", spec })
  if v ~= nil and is_sha(v) then
    return v, "gitlink"
  end
  v = pipe_git({ "-c", "safe.directory=*", "-C", proj, "rev-parse", spec })
  if v ~= nil and is_sha(v) then
    return v, "gitlink-safe-directory"
  end
  return nil, nil
end

-- --------------------------------------------------------------------------
-- Provenance de la PAGE RENDUE : trois branches, chacune nommee dans l'artefact
-- `data-git-source`. Conservee du donneur, labels compris.
--   1 `racine-…`   : le document siege a la racine du projet rendu.
--   2 `gitlink-…`  : le document siege sous un montage declare de l'assemblage.
--   3 `repli-…`    : rien de verifie. Aucun sha, aucun lien.
-- --------------------------------------------------------------------------

local function lesson_provenance(repo, external_declared)
  local proj = norm_dir(env("QUARTO_PROJECT_DIR"))
  local docv = trim(env("QUARTO_DOCUMENT_PATH") or "")
  if docv == "" then
    return nil, nil, "repli-document-absent", nil
  end

  -- valeur donnee, absolutisee SANS reconstruction par basename ; un chemin de
  -- fichier est ramene a son dossier par le seul test de l'extension.
  local docdir = docv
  if docdir:sub(1, 1) ~= "/" and proj ~= "" then
    docdir = norm_dir(proj .. "/" .. docdir)
  end
  if docdir:match("%.qmd$") ~= nil or docdir:match("%.ipynb$") ~= nil then
    docdir = parent_of(docdir) or docdir
  end
  docdir = norm_dir(docdir)

  local rel = nil
  if proj ~= "" and docdir ~= proj and docdir:sub(1, #proj + 1) == proj .. "/" then
    rel = docdir:sub(#proj + 2)
  end

  -- ------------------------------ Branche 1 : racine du depot rendu.
  if rel == nil then
    local sha, gd, kind = head_of(docdir)
    if sha == nil then
      return nil, docdir, "repli-" .. tostring(kind or "aucun-depot"), nil
    end
    local origin = origin_of(docdir, gd) or ""
    local declared = repo
    local ext = external_declared
    if declared == "" then
      declared = origin
      ext = false
    end
    local force = repo_identity(origin, declared, ext)
    if force == nil then
      return nil, docdir, "repli-garde-identite", nil
    end
    return sha, docdir, "racine-" .. tostring(kind) .. "-" .. force, nil
  end

  -- ------------------------------ Branche 2 : sous un montage declare.
  -- Un chemin qui apparait dans l'arbre ne suffit PAS : le montage doit etre
  -- declare par `.gitmodules` de l'assemblage, ou reel (un `.git` au point de
  -- montage). Sinon c'est la branche 3.
  local mpath, entry = nil, nil
  for _, e in ipairs(submodule_entries(proj)) do
    local p = norm_dir(e.path or "")
    if p ~= "" and (p == rel or rel:sub(1, #p + 1) == p .. "/") then
      mpath, entry = p, e
      break
    end
  end
  if mpath == nil then
    local top = rel:match("^([^/]+)")
    if top ~= nil and (slurp(proj .. "/" .. top .. "/.git") ~= nil
      or slurp(proj .. "/" .. top .. "/.git/HEAD") ~= nil) then
      mpath = top
    end
  end
  if mpath == nil then
    return nil, docdir, "repli-montage-non-declare", nil
  end

  local sha, gsrc = gitlink_declared(proj, mpath)
  if sha == nil then
    return nil, docdir, "repli-gitlink-ilisible", nil
  end

  local cr = canon_repo(repo)
  if cr == nil then
    cr = canon_repo(mpath)
  end
  if cr == nil then
    return nil, docdir, "repli-declare-ilisible", nil
  end
  local force = nil
  if entry ~= nil then
    force = repo_identity(entry.url or "", repo, external_declared)
    if force == nil then
      return nil, docdir, "repli-garde-identite-montage", nil
    end
  else
    -- aucune declaration `.gitmodules` : seule la concordance du nom du point de
    -- montage avec le depot declare parle, et elle ne vaut jamais `organisation`.
    if repo_name(canon_repo(mpath)) ~= repo_name(cr) then
      return nil, docdir, "repli-garde-identite-montage", nil
    end
    force = "nom-seul"
  end
  -- Quatrieme valeur du donneur (la reserve de la branche 2) : la surface signee
  -- n'imprime aucune reserve. La provenance de la valeur reste publiee, par
  -- l'etiquette seule, qui dit `gitlink-…` quand c'est bien la declaration de
  -- l'assemblage qui a parle.
  return sha, proj .. "/" .. mpath, gsrc .. "-" .. force, nil
end

-- --------------------------------------------------------------------------
-- Provenance du FOURNISSEUR, avec garde d'IDENTITE de depot.
-- Retourne (sha, dir, source, garde). `garde` faux signifie que le repertoire resolu
-- n'est PAS `_quarto-utils` sous la racine rendue : dans ce cas AUCUN repertoire
-- n'est renvoye, pour qu'aucune clef de garde ne puisse etre prise hors du depot
-- attendu. C'est l'adaptation qu'exige la cle de garde de la surface signee, qui est
-- l'EXISTENCE du document de politique au racine gardee d'identite ; le donneur,
-- lui, renvoyait le repertoire meme quand la garde echouait.
-- --------------------------------------------------------------------------

-- L'origine lue au montage suffit-elle a NOMMER le fournisseur ? Compare en formes
-- canoniques des deux cotes. Un hote absent de la liste est refuse ; une origine de
-- chemin local (harnais, clone de travail) ne peut pas exprimer l'organisation et
-- n'est donc pas traitee comme un hote etranger : c'est la force reellement verifiee,
-- publiee dans `data-utils-source` et jamais masquee.
local function origin_is_provider(u)
  if u == nil or u == "" then
    return false
  end
  local c = canon_repo(u)
  if c == nil or c == "" then
    return false
  end
  local host = nil
  if c:find("/", 1, true) ~= nil then
    host = c:match("^(.-)/")
  end
  if host ~= nil and host:find(".", 1, true) ~= nil and GH_HOSTS[host] ~= true then
    return false
  end
  local name = c:match("([^/]+)$")
  return name ~= nil and name:lower() == UTILS
end

local function first_header(bs)
  for _, b in ipairs(bs or {}) do
    if b.t == "Header" then
      return b
    elseif b.t == "Div" or b.t == "BlockQuote" then
      local h = first_header(b.content)
      if h ~= nil then
        return h
      end
    end
  end
  return nil
end

local function provider_provenance()
  local proj = env("QUARTO_PROJECT_DIR")
  if proj == "" then
    return nil, nil, "projet-absent", false
  end
  proj = proj:gsub("/+$", "")
  if proj == "" then
    return nil, nil, "projet-absent", false
  end
  local dir = proj .. "/" .. UTILS
  -- La garde n'est pas une existence : le chemin resolu doit NOMMER le depot
  -- attendu. Un fournisseur voisin installe ailleurs ne peut pas passer ici.
  if dir:match("([^/]+)$") ~= UTILS then
    return nil, nil, "garde-identite", false
  end
  -- V2 : AUCUN engagement n'est publie sous l'etiquette du fournisseur sans que
  -- CE depot soit identifie. Deux defauts mesures :
  --  (a) `gitdir_of` acceptait un `.git` absent du montage et le repli binaire
  --      `pipe_git_root` publiait alors la tete d'un depot plus haut (mesure
  --      NOGIT-html : `data-utils-source="binaire"` avec le sha de LA LECON sous
  --      l'etiquette du fournisseur). La resolution est desormais
  --      `resolved_gitdir`, qui ne remonte jamais hors du repertoire demande.
  --  (b) aucune origine n'etait lue : une `origin` posee sur un hote etranger
  --      publiait un engagement au nom du fournisseur (mesure FOREIGN-html).
  -- Defaut de l'une des deux gardes : aucun sha, et la puce le dit nommement.
  local gd = resolved_gitdir(dir)
  if gd == nil then
    return nil, dir, "aucun-depot-au-montage", true
  end
  if not origin_is_provider(origin_of(dir, gd)) then
    return nil, dir, "origine-non-identifiee", true
  end
  local sha = sha_from_gitdir(gd)
  if sha ~= nil then
    return sha, dir, "direct", true
  end
  local v, src = pipe_git_root(dir)
  if v ~= nil then
    return v, dir, tostring(src), true
  end
  return nil, dir, "non-resolvable", true
end

-- Autorite d'emission : le document de politique doit EXISTER (lecture reussie) au
-- racine gardee d'identite du fournisseur. Existence seule : aucune marque, aucun
-- jeton, aucun engagement n'est exige dans son contenu. Absent, illisible ou
-- racine non garde : RIEN n'est emis, et ce n'est pas une erreur.
local function policy_body(dir)
  if dir == nil or dir == "" then
    return nil
  end
  return slurp(dir .. "/" .. POLICY_DOC)
end

-- --------------------------------------------------------------------------
-- Fichier de version de l'execution : `<QUARTO_PROJECT_DIR>/_cartouche-version.json`,
-- ecrit par une etape amont qui lit le contexte du couloir. Champs utilises ici :
-- `repository`, `ref_type`, `ref_name`. Les autres champs presents (evenement,
-- identifiant d'execution, etats de tete) sont LUS et JAMAIS emis : la surface signee
-- ne publie ni date, ni generation, ni reference de requete.
-- Lecture tolerante : absent, illisible ou vide => bras caches, aucun texte invente.
-- Le projet n'embarque aucun analyseur JSON et le pipeline ne fournit pas de
-- bibliothèque d'objets : ce scanneur est donc un sous-ensemble volotaire, limite aux
-- FLAT `{"cle":"valeur",…}` que produit l'etape amont. Une valeur imbrique n'est pas
-- comprise ; le fichier de version n'en porte pas.
-- --------------------------------------------------------------------------

local function json_unescape(s)
  s = s:gsub("\\\\", "\\")
  s = s:gsub('\\"', '"')
  s = s:gsub("\\/", "/")
  s = s:gsub("\\n", "\n")
  s = s:gsub("\\t", "\t")
  s = s:gsub("\\r", "\r")
  return s
end

local function json_flat(text)
  if text == nil then
    return nil
  end
  local start = text:find("{", 1, true)
  if start == nil then
    return nil
  end
  local out, i, n = {}, start + 1, #text
  while i <= n do
    local q = text:find('"', i, true)
    if q == nil then
      break
    end
    local key, k2 = nil, q + 1
    while k2 <= n do
      local c = text:sub(k2, k2)
      if c == "\\" then
        k2 = k2 + 2
      elseif c == '"' then
        key = text:sub(q + 1, k2 - 1)
        break
      else
        k2 = k2 + 1
      end
    end
    if key == nil then
      break
    end
    local colon = text:find(":", k2 + 1, true)
    if colon == nil then
      break
    end
    local j = colon + 1
    while j <= n and text:sub(j, j):match("^%s$") ~= nil do
      j = j + 1
    end
    local val, adv = nil, nil
    if text:sub(j, j) == '"' then
      local k = j + 1
      while k <= n do
        local c = text:sub(k, k)
        if c == "\\" then
          k = k + 2
        elseif c == '"' then
          val = json_unescape(text:sub(j + 1, k - 1))
          adv = k + 1
          break
        else
          k = k + 1
        end
      end
    else
      local k = j
      while k <= n and text:sub(k, k):match("[,}]") == nil do
        k = k + 1
      end
      val = trim(text:sub(j, k - 1))
      adv = k
    end
    if val == nil then
      break
    end
    out[json_unescape(key)] = val
    i = adv or (colon + 1)
  end
  return out
end

local function version_data()
  local proj = norm_dir(env("QUARTO_PROJECT_DIR"))
  if proj == "" then
    return nil
  end
  local body = slurp(proj .. "/" .. VERSION_FILE)
  if body == nil then
    return nil
  end
  local ok, t = pcall(json_flat, body)
  if not ok or type(t) ~= "table" then
    return nil
  end
  return t
end

local function ver_str(ver, key)
  if ver == nil then
    return ""
  end
  local v = ver[key]
  if v == nil then
    return ""
  end
  v = trim(tostring(v))
  if v == "null" or v == "nil" then
    return ""
  end
  return v
end

-- --------------------------------------------------------------------------
-- URLs d'engagement. Seule voie de construction admise : la base est DERIVEE de la
-- reference de depot lue (fichier de version, cle native, ou `remote.origin.url`),
-- jamais ecrite a la main, et le sha public est la MEME chaine mesuree que le sha
-- court. Forme non resoluble, autre hebergeur, ou valeur sans rapport : AUCUN lien.
-- Un lien faux serait une affirmation ; l'absence de lien ne l'est pas.
-- --------------------------------------------------------------------------

local function github_base(raw)
  local c = canon_repo(raw)
  if c == nil then
    return nil
  end
  local h, o, r = c:match("^([^/]+)/([^/]+)/([^/]+)$")
  if h ~= nil then
    if GH_HOSTS[h] then
      return "https://github.com/" .. o .. "/" .. r
    end
    return nil
  end
  local o2, r2 = c:match("^([^/]+)/([^/]+)$")
  if o2 ~= nil then
    -- deux segments : la forme `owner/nom` que publie le contexte d'execution. Un
    -- premier segment qui ressemble a un hebergeur n'est pas un proprietaire : la
    -- forme serait ambigu, donc elle ne lie pas.
    if o2:find(".", 1, true) ~= nil or GH_HOSTS[o2] then
      return nil
    end
    return "https://github.com/" .. o2 .. "/" .. r2
  end
  return nil
end

local function commit_url(base, sha)
  if base == nil or base == "" or sha == nil or not is_sha(sha) then
    return ""
  end
  return base .. "/commit/" .. sha
end

-- Base du fournisseur : la moitie organisateur de l'URL du depot de la page, plus le
-- nom du depot partage. Conserve du donneur.
local function utils_base(lesson_base)
  if lesson_base == nil or lesson_base == "" then
    return nil
  end
  local g = lesson_base:match("^(https://github.com/[^/]+)$")
  if g == nil then
    return nil
  end
  return g .. "/" .. UTILS
end

-- --------------------------------------------------------------------------
-- Licence native : `meta.license`, en chaine ou en table { text, url }.
-- --------------------------------------------------------------------------

local function stringify_of(v)
  if v == nil then
    return ""
  end
  local ok, s = pcall(pandoc.utils.stringify, v)
  if not ok or s == nil then
    return ""
  end
  return trim(tostring(s))
end

local function is_bync(label)
  local n = label:lower():gsub("[%s_%.]", "-")
  return n:find("by%-nc") ~= nil
end

-- Retourne (libelle, url). Libelle vide => la puce n'est pas emise du tout.
local function license_from_meta(meta)
  if meta == nil or meta.license == nil then
    return "", ""
  end
  local v = meta.license
  local label, url = "", ""
  if type(v) == "table" then
    -- V4 : la licence est lue CHAMP PAR CHAMP, et le test ne depend plus de `v.t`.
    -- Mesure : Quarto normalise `license: "CC BY-NC"` et `license: "CC BY-NC 4.0"`
    -- en une table de champs `text` / `type` / `url` sans `t` == "MetaMap" ; elle
    -- tombait donc dans le repli `stringify_of(v)`, qui CONCATENE tous les champs :
    -- le libelle publie portait l'URL en son sein et le libelle n'etait plus
    -- discrimable du lien. Les champs inconnus sont ignores, et une valeur non
    -- publiee n'est pas emise.
    label = stringify_of(v.text)
    if label == "" then
      label = stringify_of(v.name)
    end
    if label == "" then
      label = stringify_of(v.id)
    end
    url = stringify_of(v.url)
    if label ~= "" and label:find("http", 1, true) ~= nil then
      -- Un libelle qui porte une adresse n'est pas un libelle : l'adresse est
      -- conservee comme lien, le libelle n'est pas emis.
      if url == "" then
        url = label
      end
      label = ""
    end
  else
    label = stringify_of(v)
  end
  if label == "" then
    return "", ""
  end
  if url == "" and is_bync(label) then
    -- L'URL explicite declaree par le projet coiffe toujours cette derivation, et
    -- la surface signee nomme ce deed : la famille BY-NC est la seule construction
    -- admise quand le projet ne declare qu'un libelle.
    url = CC_BYNC_DEED
  end
  return label, url
end

-- --------------------------------------------------------------------------
-- Emission : blocs natifs. Le bloc de colophon est place EN TETE de liste (mesure du
-- 17 novembre : premier element apres `</header>` sur la jambe html, feuille autonome
-- en index 1 colle a la feuille de titre sur le deck, premiere section numerotee sur
-- le PDF). La section de politique est placee EN FIN de document. Aucun separateur de
-- slide n'est insere : le HorizontalRule ajoute une feuille vide et le
-- RawBlock("revealjs","---") publie un separateur parasite sans decouper ; la
-- frontiere est declenchee par le Header(3) lui-meme (`slide-level: 3`).
-- --------------------------------------------------------------------------

local function T(s)
  return pandoc.Str(tostring(s))
end

local function C(s)
  return pandoc.Code(tostring(s))
end

-- Un lien seulement quand une URL resolue existe ; sinon une spanne de code, qui
-- n'affirme rien.
local function link_or_code(text, url)
  if url == nil or url == "" then
    return { C(text) }
  end
  return { pandoc.Link({ C(text) }, url, "") }
end

local function bullet(inlines)
  return { pandoc.Para(inlines) }
end

-- Les puces de la surface signee sont jointes par « · », et une partie absente
-- n'allonge pas la ligne d'un separateur orphelin.
local function join_sep(parts)
  local out = {}
  for i, a in ipairs(parts) do
    if i > 1 then
      out[#out + 1] = T(" · ")
    end
    for _, v in ipairs(a) do
      out[#out + 1] = v
    end
  end
  return out
end

-- Le sha complet n'est jamais coupe ni recompose : court et complet sortent de la
-- MEME chaine mesuree.
local function short7(sha)
  if sha == nil or not is_sha(sha) then
    return nil
  end
  return sha:sub(1, 7)
end

-- Nom de depot affiche, dans l'ordre de precedence de la surface signee : le champ
-- `repository` du fichier de version, puis la cle native (repli, regle 7), puis
-- `remote.origin.url` du depot de la page rendue. Rien n'est invente quand les trois
-- se taisent.
local function repo_display(ver, meta, origin)
  local v = ver_str(ver, "repository")
  if v ~= "" then
    return v, true
  end
  v = meta_str(meta, "cartouche-repo")
  if v ~= "" then
    return v, true
  end
  local c = canon_repo(origin)
  if c == nil then
    return "", false
  end
  local o, r = c:match("^[^/]+/([^/]+)/([^/]+)$")
  if o ~= nil then
    return o .. "/" .. r, false
  end
  o, r = c:match("^([^/]+)/([^/]+)$")
  if o ~= nil then
    return o .. "/" .. r, false
  end
  return c, false
end

-- Base de l'URL de depot de la page : la reference qui a servi a nommer le depot,
-- dans le meme ordre. Une origine lue sur le depot lui-meme ne peut pas lier vers
-- un hote inconnu, donc elle ne lie que si sa forme est resoluble.
local function repo_base_for(ver, meta, origin)
  local v = ver_str(ver, "repository")
  if v == "" then
    v = meta_str(meta, "cartouche-repo")
  end
  if v == "" then
    v = origin or ""
  end
  return github_base(v)
end

local function colophon_blocks(ctx)
  local ver, meta, lesson, utils = ctx.ver, ctx.meta, ctx.lesson, ctx.utils
  local items = {}

  -- 1. Depot, bras de version de l'execution, engagement de la page rendue.
  local parts = {}
  if ctx.repo ~= "" then
    parts[#parts + 1] = { T("Dépôt "), T(ctx.repo) }
  end
  local rt = ver_str(ver, "ref_type"):lower()
  local rn = ver_str(ver, "ref_name")
  if rn ~= "" and (rt == "branch" or rt == "tag") then
    if rt == "branch" then
      parts[#parts + 1] = { T("branche "), C(rn) }
    else
      parts[#parts + 1] = { T("version "), C(rn) }
    end
  end
  local lshort = short7(lesson.sha)
  if lshort ~= nil then
    local u = commit_url(ctx.repo_base, lesson.sha)
    local seg = { T("commit ") }
    for _, v in ipairs(link_or_code(lshort, u)) do
      seg[#seg + 1] = v
    end
    parts[#parts + 1] = seg
  else
    -- Une resolution qui echoue est dite, et AUCUN engagement n'est affirmé.
    parts[#parts + 1] = {
      T("commit non résolu au rendu (" .. tostring(lesson.src) .. ") : aucun engagement n'est affirmé ici")
    }
  end
  if #parts > 0 then
    items[#items + 1] = bullet(join_sep(parts))
  end

  -- 2. Fournisseur de la configuration partagée : V2f. Quand son engagement n'est
  --    pas resolu ET verifie, la puce entiere est OMITISE : pas de phrase de refus,
  --    pas de nom de garde, pas de mention `_quarto-utils` dans cette puce. La regle
  --    du corpus, posee par l'humain, est qu'une information inconnue au rendu est
  --    masquee, jamais inventee ; une non-valeur etiquetee est exactement le tiret
  --    que cette consigne interdit. Les puces restantes (Depot, Licence) sont émises
  --    sur donnees verifiees, inchangees.
  local ushort = short7(utils.sha)
  if ushort ~= nil then
    local pl = { T("Configuration partagée "), C(UTILS) }
    pl[#pl + 1] = T(" à l'engagement ")
    for _, v in ipairs(link_or_code(ushort, commit_url(ctx.utils_base, utils.sha))) do
      pl[#pl + 1] = v
    end
    items[#items + 1] = bullet(pl)
  end

  -- 3. Licence native, puis version stable publiee quand l'execution en porte une.
  if ctx.lic_label ~= "" then
    local ll = { T("Licence ") }
    for _, v in ipairs(link_or_code(ctx.lic_label, ctx.lic_url)) do
      ll[#ll + 1] = v
    end
    if rt == "tag" and rn ~= "" then
      ll[#ll + 1] = T(" · version stable ")
      ll[#ll + 1] = C(rn)
    else
      -- Une version stable qui n'existe pas est dite par une formulation complete,
      -- jamais par une etiquette suivie d'un tiret.
      ll[#ll + 1] = T(" · aucune version stable publiée à ce jour")
    end
    items[#items + 1] = bullet(ll)
  end

  -- 4. Politique : lien d'ancre interne vers la section emise en fin de document.
  if ctx.policy then
    items[#items + 1] = bullet({
      pandoc.Link({ T("Politique de production") }, "#" .. POLICY_ID, "")
    })
  end

  local kv = {
    { "data-git-source", tostring(lesson.src) },
    { "data-cartouche-rev", REVID },
  }
  if lesson.sha ~= nil then
    kv[#kv + 1] = { "data-cartouche-commit", lesson.sha }
  end
  if utils.sha ~= nil then
    kv[#kv + 1] = { "data-utils-commit", utils.sha }
    kv[#kv + 1] = { "data-utils-source", tostring(utils.src) }
  end

  return pandoc.Div(
    {
      pandoc.Header(3, { T("À propos de ce support") }),
      pandoc.Para({
        T("Transparence IA : support rédigé avec l'assistance d'un modèle de langage, relu et validé par l'auteur.")
      }),
      pandoc.BulletList(items)
    },
    pandoc.Attr("", { CLASS }, kv)
  )
end

-- --------------------------------------------------------------------------
-- Section de politique : le document du fournisseur est converti en blocs NATIFS et
-- place en FIN de document, apres le colophon. Le natif est la seule voie qui rende
-- sur les trois jambes ; le brut HTML est abandonne par le redacteur typst.
-- Transpositions : `#` devient un titre de niveau 3, `##` un niveau 4 (decalage de
-- deux, plafonne a 6), le reste des titres suit le meme decalage. Listes a puces,
-- listes numerotees et paragraphes restent natifs. Sont RETIRES : tout brut HTML
-- (`RawBlock`, `RawInline`) et tout code encadre (`CodeBlock`). Le texte d'un
-- document de politique ne doit rien publier qui ne soit pas du contenu natif.
-- L'ancre `#politique-de-production` est portee par l'IDENTIFIANT DU DIV natif qui
-- englobe la section : un seul porteur, jamais le div ET le premier titre, ce qui
-- dupliquerait l'identifiant et rendrait l'ancre ambigu.
-- --------------------------------------------------------------------------

local function strip_raw_inlines(ils)
  local out = {}
  for _, il in ipairs(ils or {}) do
    if il.t ~= "RawInline" then
      out[#out + 1] = il
    end
  end
  return out
end

local function shift_level(n)
  local v = tonumber(n) or 1
  v = v + 2
  if v < 3 then
    v = 3
  elseif v > 6 then
    v = 6
  end
  return v
end

local function clean_blocks(blocks)
  local out = {}
  for _, b in ipairs(blocks or {}) do
    local t = b.t
    if t == "CodeBlock" or t == "RawBlock" then
      -- retire, par spec
    elseif t == "Header" then
      out[#out + 1] = pandoc.Header(shift_level(b.level), strip_raw_inlines(b.content), b.attr)
    elseif t == "Para" or t == "Plain" then
      local ils = strip_raw_inlines(b.content)
      if #ils > 0 then
        out[#out + 1] = (t == "Para") and pandoc.Para(ils) or pandoc.Plain(ils)
      end
    elseif t == "Div" then
      local kids = clean_blocks(b.content)
      if #kids > 0 then
        out[#out + 1] = pandoc.Div(kids, b.attr)
      end
    elseif t == "BlockQuote" then
      local kids = clean_blocks(b.content)
      if #kids > 0 then
        out[#kids and 1 or 1] = nil
        out[#out + 1] = pandoc.BlockQuote(kids)
      end
    elseif t == "BulletList" then
      local its = {}
      for _, it in ipairs(b.content or {}) do
        local kid = clean_blocks(it)
        if #kid > 0 then
          its[#its + 1] = kid
        end
      end
      if #its > 0 then
        out[#out + 1] = pandoc.BulletList(its)
      end
    elseif t == "OrderedList" then
      local its = {}
      for _, it in ipairs(b.content or {}) do
        local kid = clean_blocks(it)
        if #kid > 0 then
          its[#its + 1] = kid
        end
      end
      if #its > 0 then
        out[#out + 1] = pandoc.OrderedList(its, b.attr)
      end
    else
      out[#out + 1] = b
    end
  end
  return out
end

local function policy_sections(body)
  if body == nil or trim(body) == "" then
    return {}
  end
  local ok, doc = pcall(pandoc.read, body, "markdown")
  if not ok or doc == nil or doc.blocks == nil then
    return {}
  end
  local blocks = clean_blocks(doc.blocks)
  if #blocks == 0 then
    return {}
  end
  return { blocks = blocks }
end

-- Le document est-il une page de liste ? Le cartouche atteste la provenance d'UNE
-- LECON rendue ; une page de liste (index de projet, d'assemblage, de brique ou de
-- section) n'a pas de provenance propre : son contenu vient d'autres fichiers, dont
-- le commit n'est pas le sien, et y publier un engagement est exactement le defaut
-- que cette garde existe pour fermer.
-- V3 : le test NOMINATIF est insuffisant, mesure. `QUARTO_DOCUMENT_PATH` porte un
-- REPERTOIRE quand le document est rendu depuis la racine du projet (valeur
-- `/work/proj2` sur les quatre lecons ET sur `index.qmd`), donc aucun nom de fichier
-- n'est jamais visible et `index` ne pouvait matcher. La discrimination est
-- STRUCTURELLE : la page porte un `listing:` dans ses metadonnees. Le test sur le
-- nom est conserve pour les cas ou le chemin porte bien un fichier. Un
-- `QUARTO_DOCUMENT_PATH` absent reste traite comme une page de liste : faillir ferme.
local function perimeter_allows(doc)
  local d = doc
  if d ~= nil and d.source ~= nil then
    d = d.source
  end
  local meta = (d ~= nil and d.meta) or {}
  if meta.listing ~= nil then
    return false
  end
  local docv = trim(env("QUARTO_DOCUMENT_PATH") or "")
  if docv == "" then
    return false
  end
  local st = stem_of(file_of(docv)):lower()
  return st ~= "index"
end

-- Garde de duplication, conservee du donneur et etendue : une page qui porterait
-- encore un bloc incruste ne recoit pas un second cartouche, et une section deja
-- presente n'est pas appendue deux fois.
local function has_class(blocks, klass)
  if blocks == nil then
    return false
  end
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.attr ~= nil then
      for _, c in ipairs(b.attr.classes or {}) do
        if c == klass then
          return true
        end
      end
      if b.attr.identifier == klass then
        return true
      end
    elseif b.t == "RawBlock" and type(b.text) == "string"
      and b.text:find(klass, 1, true) ~= nil then
      return true
    end
  end
  return false
end

-- Trace de chargement : prouve, dans la console du rendu, quelle revision du filtre
-- a tourne. Le jeton est une etiquette ASCII verifiable par relle du fichier, pas un
-- resume de hachage (voir l'en-tete). Toute ecriture est sous `pcall` : une trace qui
-- echoue ne doit jamais rompre un rendu, et son absence n'invalide pas l'emission.
local function trace_loaded(src)
  local ok, err = pcall(function()
    local w = io.stderr
    if w == nil then
      return
    end
    w:write("LOADED: ebpro/cartouche cartouche.lua rev=" .. REVID
      .. " source=" .. tostring(src) .. "\n")
  end)
  if not ok then
    return
  end
end

-- --------------------------------------------------------------------------
-- Hook d'emission. Rien n'est exerce sur un nom de format (FORMAT arrive en chaine
-- brute) : la section de politique est en fin de document, donc elle n'interfere pas
-- avec une sortie qui ne rend qu'un fragment.
-- --------------------------------------------------------------------------

local function emit(doc)
  if not perimeter_allows(doc) then
    return nil
  end
  local meta = doc.meta
  local blocks = doc.blocks
  if blocks == nil then
    return nil
  end
  if has_class(blocks, CLASS) then
    return nil
  end

  local usha, udir, usrc, guarded = provider_provenance()
  if not guarded then
    return nil
  end
  local body = policy_body(udir)
  -- V6 : le document de politique est l'AUTORITE d'emission, et « lecture reussie »
  -- ne veut pas dire « texte de politique ». Le conteneur de rendu tourne en root et
  -- lit sans erreur un fichier en mode 000 : seule l'existence ne gardait rien. Un
  -- corps vide vaut document absent, sans rien inventer comme etiquette.
  if body == nil or trim(body) == "" then
    return nil
  end
  local okp, pol = pcall(policy_sections, body)
  if not okp or pol == nil then
    pol = { blocks = {} }
  end
  local has_policy = pol.blocks ~= nil and #pol.blocks > 0
  if has_policy and has_class(blocks, POLICY_ID) then
    has_policy = false
    pol = { blocks = {} }
  end

  local ver = version_data()
  local repo, external = repo_display(ver, meta, nil)
  local lsha, lroot, lsrc = lesson_provenance(repo, external)

  -- Origine lue sur le depot de la page, au besoin seule source du nom affiche.
  local origin = ""
  if lroot ~= nil and lroot ~= "" then
    local _, lgd = resolved_gitdir(lroot)
    origin = origin_of(lroot, lgd) or ""
    if repo == "" then
      repo, external = repo_display(ver, meta, origin)
    end
  end

  local lesson_base = repo_base_for(ver, meta, origin)
  local lic_label, lic_url = license_from_meta(meta)

  trace_loaded(tostring(lsrc))

  local head = colophon_blocks({
    ver = ver,
    meta = meta,
    repo = repo,
    repo_base = lesson_base,
    utils_base = utils_base(lesson_base),
    lesson = { sha = lsha, src = lsrc },
    utils = { sha = usha, src = usrc },
    lic_label = lic_label,
    lic_url = lic_url,
    policy = has_policy,
  })

  local out = { head }
  for _, b in ipairs(blocks) do
    out[#out + 1] = b
  end
  if has_policy then
    -- V1 : UN SEUL porteur d'identifiant. Quarto numerote les titres et fait de leur
    -- identifiant une etiquette typst ; le div englobant portait deja
    -- `politique-de-production` ET le premier titre du document de politique
    -- (`# Politique de production`, transpose) recevait le meme : mesure
    -- TYP-typst, rc 1, « label `<politique-de-production>` occurs multiple times »,
    -- AUCUN document emis. L'identifiant est donc force sur la premiere entete
    -- injectee, SANS renommer ni dupliquer quoi que ce soit (niveau, contenu et
    -- classes conserves) ; le div englobant n'en porte plus. Faute d'entete dans le
    -- corps de politique, le div reste le porteur unique.
    local carrier = first_header(pol.blocks)
    if carrier ~= nil then
      local a = carrier.attr or pandoc.Attr()
      carrier.attr = pandoc.Attr(POLICY_ID, a.classes or {}, a.attributes or {})
      out[#out + 1] = pandoc.Div(pol.blocks)
    else
      out[#out + 1] = pandoc.Div(pol.blocks, pandoc.Attr(POLICY_ID))
    end
  end
  return pandoc.Pandoc(out, meta)
end

function Pandoc(doc)
  -- Le filtre ne doit JAMAIS rompre un rendu : toute erreur interne est tue et le
  -- document passe intact, sans colophon et sans section.
  local ok, res = pcall(emit, doc)
  if not ok or res == nil then
    return nil
  end
  return res
end

