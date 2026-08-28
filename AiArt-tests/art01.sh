#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/baidu/ERNIE-Image-Turbo [54f8a75695]"' >&2
  exit 1
fi

# ---- HELPERS ---------------------------------------------------------------
urlencode() {
  local string="$1" encoded="" i char
  for (( i=0; i<${#string}; i++ )); do
    char="${string:i:1}"
    case "$char" in
      [a-zA-Z0-9._~-]) encoded+="$char" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'$char" ;;
    esac
  done
  printf '%s' "$encoded"
}

queue_job() {
  local index="$1"
  local prompt="$2"
  local task_name
  task_name="$(printf '%02d' "$index") ${prompt:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${prompt:0:120}"

  local json
  json=$(jq -n \
    --arg  prompt   "$prompt"   \
    --arg  sampler  "$SAMPLER"  \
    --arg  model    "$MODEL"    \
    --argjson steps  $STEPS     \
    --argjson cfg    $CFG       \
    --argjson ag     $AG        \
    --argjson w      $WIDTH     \
    --argjson h      $HEIGHT    \
    --argjson seed   $SEED      \
    '{
      sd_model_checkpoint: $model,
      checkpoint:           $model,
      prompt:       $prompt,
      steps:        $steps,
      cfg_scale:    $cfg,
      pag_scale:    $ag,
      width:        $w,
      height:       $h,
      sampler_name: $sampler,
      seed:         $seed,
      batch_size:   1,
      n_iter:       1,
      save_images:  true
    }')

  curl -s -X POST "$SCHED?name=$(urlencode "$task_name")" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null
}

# ---- PROMPTS ---------------------------------------------------------------
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+1+-+highly+artistic+and+aesthetic
# 7 models × 5 prompts = 35 total
# Redundant inline resolution tags (e.g. "1024x1024") stripped — handled globally above.
# GLM5 Chinese originals omitted; English translations used.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · 霓虹水墨 / Neon Ink
prompts+=( "A lone figure standing beneath a colossal red torii gate submerged halfway in a glassy flooded city street at dusk, reflections of neon kanji signs shimmering on still water, ink-wash sky bleeding indigo into amber, hyper-detailed architectural decay, cinematic fog, award-winning photography." )

# 02 · Crystalline Solitude
prompts+=( "An abandoned Victorian greenhouse overgrown from within, giant translucent blue crystal formations erupting through the broken glass roof, golden hour shafts of light refracting into prismatic dust, moss-covered wrought iron, photorealistic textures, National Geographic quality, moody and ethereal atmosphere." )

# 03 · Desert Oracle
prompts+=( "Ancient stone colossus hand emerging from a vast rose-gold sand dune at magic hour, carved with intricate cuneiform reliefs, a single hooded traveler resting in its shadow, volumetric dust haze, ultra-wide cinematic composition, muted earth tones with deep violet shadows, epic scale, hyperrealistic render." )

# 04 · Bioluminescent Reverie
prompts+=( "A barefoot woman in a flowing silk dress walking through a pitch-black ancient forest floor covered in glowing cyan and violet bioluminescent mushrooms, long exposure light trails, mist at ankle level, Rembrandt-style rim lighting, surreal botanical illustration meets fine art photography." )

# 05 · Arctic Deco
prompts+=( "Art Deco palace of ice and black marble rising from a frozen Arctic shore under a vivid aurora borealis, geometric gold inlay patterns on glacial walls, a solitary lantern glowing warm amber in a single arched window, dramatic upward perspective, chromatic contrast of emerald aurora against deep navy sky, architectural concept art, ultra-detailed." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Neon Calligrapher
prompts+=( "A masterpiece digital painting of a silhouette in traditional flowing robes, standing in a void. The figure is writing in the air with a brush of liquid neon gold. Large, glowing ink splashes float in 3D space around them, transforming into koi fish made of light. High contrast, dark teal and charcoal background, vibrant bioluminescent accents, hyper-detailed fluid dynamics, 8k resolution, cinematic atmosphere." )

# 07 · Porcelain Rebirth
prompts+=( "A close-up surrealist portrait of a face made of cracked white Kintsugi porcelain. Gold lacquer fills the cracks. From within the largest crack on the cheek, a lush variety of miniature desert flowers and succulents are blooming. Soft, diffused morning sunlight, macro photography style, extremely shallow depth of field, clean white studio background, elegant and serene." )

# 08 · The Clockwork Forest
prompts+=( "An ultra-realistic wide shot of an ancient forest where the trees are made of brass pipes, copper gears, and glowing vacuum tubes. Moss and vines are intertwined with the machinery. A soft emerald mist floor, sunlight filtering through bronze leaves, intricate mechanical details, Victorian industrial aesthetic, rich metallic textures, volumetric lighting." )

# 09 · Ink-Wash Noir
prompts+=( "A striking, artistic fusion of traditional Chinese ink-wash painting and modern film noir. A lonely detective with a wide-brimmed hat stands under a streetlamp in the rain. High-contrast black and white with a single splash of deep crimson on an umbrella. Broad, expressive brushstrokes for the background, fine sharp lines for the subject, moody, evocative, heavy grain texture." )

# 10 · Galactic Architectural
prompts+=( "Interior view of a futuristic cathedral built entirely from translucent iridescent glass and white marble. The ceiling is a massive, accurate star nebula glowing in violet and amber. The architecture uses complex parametric curves and organic structures. Ethereal light rays, crystalline reflections, grand scale, majestic and peaceful, 8k, highly detailed architectural photography." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Fragmented Identity Portrait
prompts+=( "A surreal portrait of a 30-year-old European man, face fragmented into floating geometric shards, each shard reflecting a slightly different emotional expression, soft studio lighting mixed with neon rim light, muted pastel palette with accents of cyan and magenta, shallow depth of field, cinematic composition, ultra-detailed skin texture, fine art photography meets abstract cubism, slight motion blur on fragments." )

# 12 · Liquid Architecture Dreamscape
prompts+=( "A futuristic city where buildings are made of flowing liquid chrome and glass, melting and reforming like waves, reflective surfaces mirroring a golden sunset sky, lone human silhouette standing on a reflective plane, ethereal fog, high contrast lighting, inspired by Zaha Hadid and surrealist architecture, hyper-detailed, glossy, dreamlike atmosphere." )

# 13 · Baroque Cyberpunk Muse
prompts+=( "A high-fashion portrait of a woman styled as a cyberpunk aristocrat, wearing an elaborate baroque-inspired gown made of holographic fabric and fiber optics, glowing circuitry embedded in skin, dramatic chiaroscuro lighting, deep shadows and gold highlights, rich textures, ornate futuristic jewelry, editorial photography style, Helmut Newton and sci-fi fusion, ultra sharp focus." )

# 14 · Nature Reclaiming Technology
prompts+=( "A poetic scene of an abandoned computer workstation overtaken by nature, moss growing over keyboard and monitors, vines wrapping cables, screens displaying faint glowing code through cracks, soft morning light rays through forest canopy, particles in the air, cinematic depth, melancholic yet peaceful mood, ultra-realistic textures, environmental storytelling." )

# 15 · Gravity-Defying Fabric Study
prompts+=( "A minimalistic studio scene featuring flowing silk fabric suspended mid-air as if frozen in zero gravity, fabric twisting into elegant sculptural forms, monochrome palette (ivory and soft gray), soft diffused lighting, extreme attention to texture and folds, high-speed photography aesthetic, clean background, fine art meets fashion editorial." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Ethereal Dreamscape
prompts+=( "A breathtaking ethereal dreamscape at twilight, floating ancient marble ruins covered in glowing bioluminescent vines and cherry blossoms, a lone woman in a flowing translucent silk dress standing on the edge of a broken staircase leading into the clouds, soft volumetric god rays piercing through mist, delicate particles floating in the air, cinematic lighting, delicate pastel and gold color palette, hyper-detailed, masterpiece, surrealism blended with romanticism, 8k aesthetic." )

# 17 · Golden Baroque Fantasy Portrait
prompts+=( "Stunning baroque-style portrait of a mysterious androgynous figure with porcelain skin and golden glowing eyes, wearing an intricate black and gold embroidered cloak with floating golden leaves and mechanical butterflies, dramatic chiaroscuro lighting, rich velvet textures, opulent palace interior with floating candles in the background, masterpiece, ultra-detailed, cinematic, elegant and majestic atmosphere, inspired by Caravaggio and Alphonse Mucha." )

# 18 · Cosmic Sakura Realm
prompts+=( "Surreal cosmic cherry blossom forest floating in deep space, ancient Japanese torii gates leading through glowing pink nebulae, petals transforming into stars as they fall, a lone samurai in ornate armor standing beneath the largest tree, dramatic rim lighting, vibrant magenta, cyan and deep purple color palette, intricate details, otherworldly beauty, cinematic masterpiece, breathtaking composition." )

# 19 · Mystical Arctic Aurora Palace
prompts+=( "Hyper-aesthetic mystical ice palace emerging from frozen northern lights, translucent crystalline architecture with intricate fractal patterns, glowing runes floating in the air, majestic arctic wolves with glowing blue eyes, dramatic emerald and violet aurora borealis swirling above, falling snow sparkling like diamonds, epic fantasy atmosphere, ultra-realistic details mixed with magical realism, masterpiece." )

# 20 · Surreal Steampunk Library in the Sky
prompts+=( "Whimsical yet dark surreal steampunk library floating among the clouds at sunset, thousands of ancient books and golden gears flying through the air, a beautiful librarian with mechanical wings reading while sitting on a giant floating book, warm golden hour lighting mixed with cool blue shadows, intricate brass and leather details, rich cinematic atmosphere, highly detailed, artistic masterpiece, in the style of Hayao Miyazaki and Zdzisław Beksiński." )

# ── Qwen 3.6+ ───────────────────────────────────────────────────────────────

# 21 · Ethereal Watercolor & Surrealism
prompts+=( "A surreal ethereal watercolor painting of a dreamlike forest at dawn, where translucent geometric crystals float gently among ancient trees. Soft diffused morning light filters through a misty canopy, illuminating delicate ferns and moss-covered stones. Muted pastel palette with subtle gold leaf accents, atmospheric perspective, rule of thirds composition, highly detailed botanical elements, dreamy and tranquil mood, masterpiece illustration style." )

# 22 · Classical Romantic Oil Painting
prompts+=( "A classical romantic oil painting of a dramatic coastal cliff at twilight. A solitary figure stands at the edge, gazing at turbulent waves crashing against dark rocks. Warm golden hour sunlight pierces through heavy sea mist, creating dramatic chiaroscuro contrasts. Visible impasto brushstrokes, rich earthy and cerulean tones, cinematic leading lines, emotional and majestic atmosphere, inspired by 19th-century masterworks." )

# 23 · Contemporary Cyberpunk Digital Art
prompts+=( "A contemporary digital artwork of a rain-slicked neo-Tokyo street at midnight. Neon signs in cyan and magenta reflect on the wet pavement, casting vibrant glows through volumetric fog. Holographic cherry blossom petals drift in the air around a silhouetted figure holding a translucent umbrella. Low-angle cinematic framing, shallow depth of field, cyberpunk aesthetic with poetic solitude, ultra-detailed lighting and reflections." )

# 24 · Macro Botanical Fine Art
prompts+=( "A macro botanical photograph capturing a single dewdrop resting on a lotus petal at golden hour. The water droplet acts as a natural lens, reflecting a miniature inverted forest and sky. Delicate petal veins are sharply rendered, fading into a soft creamy bokeh background. Natural diffused sunlight, golden spiral composition, high contrast between crisp focal point and dreamy surroundings, nature photography meets fine art." )

# 25 · Art Nouveau Celestial Illustration
prompts+=( "An Art Nouveau inspired illustration of a celestial maiden whose flowing hair transforms into intertwining vines, silver stars, and crescent moons. Intricate linework frames the composition with ornamental botanical borders. Muted olive, cream, and silver palette with subtle metallic foil textures. Central symmetry, balanced negative space, decorative elegance, reminiscent of Mucha and Klimt, highly refined and poetic." )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · Neo-Oriental Cyberpunk
prompts+=( "Cyberpunk style Eastern ancient temple, rainy night, glowing holographic sutras wrapped around the flying eaves. Deep blue-purple tones contrasting sharply with dazzling neon pink. Puddled water reflecting intricate mechanical structures and neon signs, cinematic lighting, Unreal Engine 5 render, extreme detail, futuristic Eastern wasteland aesthetic, 8k resolution." )

# 27 · Ethereal Impressionist Fantasy
prompts+=( "Dreamy glowing forest, Monet Impressionist oil painting style. Giant translucent jellyfish floating slowly among the treetops, emitting faint blue and pale golden light. A girl in a white veil seen from behind stands quietly by the water, mist swirling, delicate brushstrokes with a sense of atmosphere, dappled light and shadow, healing and ethereal beautiful mood, masterful masterpiece." )

# 28 · Avant-Garde Minimalist Fashion
prompts+=( "Minimalist high-fashion editorial. In front of a pure red minimalist background wall, a model with a cold temperament wears an avant-garde sculptural dress woven from flowing liquid metal and white silk. Strong Rembrandt lighting (chiaroscuro), premium gray tones, extreme geometric tension and architectural feel, Vogue magazine cover texture, hyper-realistic photography." )

# 29 · Magical Realism Macro Art
prompts+=( "Macro photography, magical realism. A mechanical flower pieced together from shattered colored glazed glass, with a tiny glowing galaxy suspended in the stamen. Crystal-clear dewdrops hang on the petals, refracting the surrounding dreamy halos. Dark background, extremely shallow depth of field, extreme material texture, like an exquisite piece of art jewelry, macro lens, sharp focus." )

# 30 · Surreal Classical Still Life
prompts+=( "Surrealist classical still life painting. On a vintage dark green velvet tabletop lies a pomegranate sliced in half, its seeds scattered and suspended in mid-air like rubies, defying gravity. The background is a vast deep blue nebula and a massive moon with a classical oil painting texture. A collision of classical oil painting techniques and modern surreal composition, Pre-Raphaelite lighting, mysterious and noble." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · Ethereal Dreamscape
prompts+=( "A luminous angelic figure dissolving into thousands of bioluminescent petals, floating in an infinite mirrored ocean under a twilight sky of swirling violet and gold nebulae. Soft volumetric god-rays pierce through crystalline mist. Hyper-detailed, ethereal atmosphere, painterly digital art in the style of Ross Tran and WLOP, 8K resolution, cinematic composition, subtle film grain, dreamy bokeh." )

# 32 · Neo-Noir Cyberpunk Portrait
prompts+=( "A mysterious woman with chrome-infused skin and holographic tattoos, standing in a rain-soaked alley illuminated by neon kanji signs in electric pink and cyan. Reflections shimmer in puddles. Deep shadows, high contrast chiaroscuro lighting, cinematic depth of field, blade runner aesthetic, photorealistic rendering, moody atmosphere, ultra-detailed textures on wet concrete and synthetic fabrics." )

# 33 · Surrealist Floating Architecture
prompts+=( "An impossible baroque palace built on floating islands of moss-covered marble, connected by cascading waterfalls that flow upward into clouds made of liquid gold. Giant koi fish swim through the air between towers. Golden hour lighting with dramatic rim light, intricate ornamental details, fantasy concept art, majestic and serene mood, highly detailed, 8K, inspired by Zdzisław Beksiński and Studio Ghibli." )

# 34 · Abstract Floral Macro Universe
prompts+=( "An extreme close-up of a single dewdrop on a black rose petal, refracting an entire miniature galaxy inside it — swirling stars, nebulae, and cosmic dust visible within the water sphere. Deep crimson and obsidian color palette, macro photography style, shallow depth of field, hyper-realistic textures, dramatic side lighting, mystical and contemplative mood, award-winning nature photography aesthetic." )

# 35 · Classical Revival with a Twist
prompts+=( "A renaissance-style oil painting of a figure in flowing silk robes standing in a ruined Greek temple overgrown with giant luminescent mushrooms and ivy. Soft Rembrandt lighting, warm amber and sage green tones, visible impasto brushwork texture, dramatic diagonal composition, melancholic yet hopeful atmosphere, fusion of classical fine art and magical realism, museum-quality masterpiece aesthetic." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
