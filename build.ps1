# Erzeugt für GitHub Pages:
#   index.html          Kopie von rezepte.html (die App)
#   r\<name>.html       eine Mini-Seite pro Rezept mit Schema.org-Markup (JSON-LD), damit Bring! die Zutaten übernehmen kann
# Aufruf im Projektordner:  powershell -ExecutionPolicy Bypass -File build.ps1
param([string]$Ordner = (Get-Location).Path, [string]$Basis = "https://magitnu.github.io/rezepte/")

$utf8 = New-Object Text.UTF8Encoding $false
$ci = [Globalization.CultureInfo]::InvariantCulture
$html = [IO.File]::ReadAllText((Join-Path $Ordner "rezepte.html"), $utf8)
$m = [regex]::Match($html, '(?s)const DATA = `(.*?)`;')
if (-not $m.Success) { throw "DATA-Block in rezepte.html nicht gefunden" }

# Dateiname aus dem Titel: gleiche Regel wie slug() in rezepte.html
function Get-Slug([string]$t) {
  $s = $t.ToLower().Replace("ä","ae").Replace("ö","oe").Replace("ü","ue").Replace("ß","ss")
  ([regex]::Replace($s, '[^a-z0-9]+', '-')).Trim('-')
}
function Esc-Json([string]$s) { $s.Replace('\','\\').Replace('"','\"') }
function Esc-Html([string]$s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') }

# Menge pro Person, gleiche Regeln wie amount() in rezepte.html (Reis & Co. als Rohgewicht)
$raw = @(@('reis',0.35), @('spaghetti|nudeln',0.4), @('couscous|quinoa|bulgur',0.4), @('polenta',0.25))
function Get-Menge($n, [double]$a) {
  if ($n -eq 'Ei') { return ([Math]::Ceiling($a / 55)).ToString($ci) + " Stück" }
  foreach ($r in $raw) { if ($n -match $r[0]) { $a = $a * $r[1]; break } }
  $g = [Math]::Max(5, [Math]::Round($a / 5, [MidpointRounding]::AwayFromZero) * 5)
  return $g.ToString($ci) + " g"
}

$rDir = Join-Path $Ordner "r"
New-Item -ItemType Directory -Force $rDir | Out-Null
$n = 0
foreach ($line in ($m.Groups[1].Value -split "`n")) {
  $line = $line.Trim()
  if (-not $line -or $line.StartsWith("##")) { continue }
  $p = $line.Split('|')
  $titel = $p[0]; $min = $p[1]; $how = if ($p.Length -gt 3) { $p[3] } else { "" }
  $zutaten = @()
  foreach ($z in $p[2].Split(',')) {
    $q = $z.Split(':'); if ($q[1] -eq 'N') { continue }
    $zutaten += (Get-Menge $q[0] ([double]::Parse($q[2], $ci))) + " " + $q[0]
  }
  $slug = Get-Slug $titel
  $url = $Basis + "r/" + $slug + ".html"
  $ld = '{"@context":"https://schema.org","@type":"Recipe","name":"' + (Esc-Json $titel) + '","author":{"@type":"Person","name":"Rezeptideen"},' +
        '"recipeYield":"1 Portion","totalTime":"PT' + $min + 'M","recipeCategory":"Hauptgericht",' +
        '"recipeIngredient":[' + (($zutaten | % { '"' + (Esc-Json $_) + '"' }) -join ',') + '],' +
        '"recipeInstructions":"' + (Esc-Json $how) + '"}'
  $li = ($zutaten | % { "<li>" + (Esc-Html $_) + "</li>" }) -join "`n"
  $seite = @"
<!doctype html>
<html lang="de-CH"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Esc-Html $titel)</title>
<link rel="canonical" href="$url">
<script type="application/ld+json">$ld</script>
<style>body{font:16px/1.5 system-ui,sans-serif;max-width:560px;margin:0 auto;padding:16px}li{margin:2px 0}</style>
</head><body>
<h1>$(Esc-Html $titel)</h1>
<p>$min Min. · Mengen pro Person</p>
<h2>Zutaten</h2><ul>
$li
</ul>
<h2>So geht's</h2><p>$(Esc-Html $how)</p>
<p><a href="../">Zur Rezeptsammlung</a></p>
</body></html>
"@
  [IO.File]::WriteAllText((Join-Path $rDir ($slug + ".html")), $seite, $utf8)
  $n++
}
[IO.File]::WriteAllText((Join-Path $Ordner "index.html"), $html, $utf8)
"$n Rezeptseiten in $rDir erzeugt, index.html aktualisiert."
