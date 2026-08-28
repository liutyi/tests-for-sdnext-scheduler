#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/Qwen/Qwen-Image-2512 [25468b98e3]"' >&2
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
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+3+-+silhouttes
# Theme: silhouettes — artistic, cinematic, double-exposure, minimalist
# 7 models × 5 prompts = 35 total
# Inline aspect ratio hints (e.g. "16:9", "2:3") and --stylize flags stripped
# as they are model-specific and not consumed by the A1111 API.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · Dancer at dusk
prompts+=( "A lone ballet dancer mid-arabesque rendered as a perfect ink-black silhouette against a gradient sky dissolving from deep amber into violet. Negative space fills with layered transparent gauze strokes suggesting fabric motion. Background features sparse bare branches as fine-line geometry. Ultra-sharp silhouette edge, no internal detail, cinematic framing, editorial illustration quality." )

# 02 · Cityscape reflection
prompts+=( "Panoramic silhouette of a dense skyline mirrored perfectly in still harbor water below, creating a symmetrical inkblot composition. Sky is a luminous rose-gold wash bleeding into cool cerulean at the horizon. Skyscraper spires end in fine needle-points. Double exposure technique merging flying birds into the upper half of the reflection. Hyper-flat graphic design aesthetic, no texture." )

# 03 · Forest spirit
prompts+=( "Silhouette of an ancient stag standing inside a perfectly circular moon, antlers organically branching into bare winter tree canopies that fill the upper frame. Moon surface glows with soft bioluminescent teal. Ground fog rendered as diffuse white brush strokes at the stag's hooves. Fine cross-hatch grain overlay. Monochromatic palette: deep indigo background, pure white moon disc, obsidian silhouette. Print-quality illustration, square format." )

# 04 · Solitary figure, rain
prompts+=( "Street-level view of a solitary figure holding an open umbrella, silhouetted against a backlit wet cobblestone alley. Neon signage reflected in the puddles bleeds electric magenta and cyan into the scene. Rain rendered as dense vertical hatching, heavier in the foreground, dissolving to mist mid-distance. Low angle perspective emphasizes depth. No facial features, pure contour form, high-contrast chiaroscuro lighting, photographic composition." )

# 05 · Child & kite, open field
prompts+=( "Wide-angle silhouette of a small child running across a vast open field, a diamond kite soaring high overhead trailing a long curving string that arcs across the entire frame. Sky transitions through five bands: white at the horizon, pale lemon, warm peach, terracotta, deep burnt sienna at the top edge. Flat grassy ground line as a single clean stroke. The kite and child are the only solid black forms; string is a single hairline. Minimalist mid-century modern poster aesthetic." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Noir Rainy Alleyway
prompts+=( "A sharp, high-contrast silhouette of a mysterious figure in a trench coat standing at the end of a narrow, rain-slicked alleyway. Deep, ink-black shadows dominate the frame. Dramatic rim lighting outlines the figure, reflecting off the wet cobblestones. A single, distant streetlamp provides the only light source. 8k resolution, selective focus, moody atmosphere, inspired by classic graphic novel aesthetics." )

# 07 · The Ethereal Double Exposure
prompts+=( "An artistic double exposure silhouette of a woman's profile. The interior of the silhouette is filled with a dense, misty pine forest during a golden sunrise. The outer edges of the silhouette are crisp and void-black, while the interior glows with soft orange light and volumetric rays hitting the trees. Ethereal, dreamlike, fine art photography style, clean white background." )

# 08 · The Neon Cyberpunk Overlook
prompts+=( "A void-black silhouette of a person sitting on a rooftop, overlooking a futuristic metropolis. The figure is framed by a colossal, glowing neon billboard in electric cyan and magenta. Raindrops on a foreground glass pane catch the vibrant light. High-contrast lighting, heavy bokeh in the background city lights, ultra-detailed, cinematic composition." )

# 09 · The Liquid Gold Minimalist
prompts+=( "A minimalist silhouette of a ballet dancer captured in a mid-air graceful leap. The background is a solid, textured matte black. A thin, elegant rim of shimmering liquid gold light traces the dancer's entire form, highlighting the muscular tension and movement. Abstract, high-end gallery art, clean lines, sharp edges, dramatic lighting." )

# 10 · The Theatrical Smoke & Cello
prompts+=( "A powerful silhouette of a cellist performing, enveloped in thick, swirling stage fog. Intense backlighting from a single overhead spotlight creates a brilliant halo effect around the musician and the instrument. Suspended dust particles are visible in the light beams. High-contrast monochrome with deep charcoal tones, soulful and theatrical atmosphere, wide-angle shot." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Neon Rain Noir Silhouette
prompts+=( "A cinematic silhouette of a lone woman standing under heavy rain in a futuristic neon-lit city alley, backlit by vibrant magenta and cyan signage, strong rim lighting outlining her figure, wet pavement reflecting distorted lights, fog and steam drifting through the scene, high contrast, deep blacks, minimal facial detail, Blade Runner inspired, noir atmosphere, volumetric lighting, 85mm lens look, shallow depth of field, ultra-detailed reflections, film grain, artistic composition." )

# 12 · Golden Hour Desert Dancer
prompts+=( "A graceful silhouette of a dancer mid-motion on a sand dune at sunset, flowing fabric trailing in the wind, sun positioned directly behind creating a radiant halo, warm golden-orange gradient sky, fine sand particles glowing in backlight, elegant pose with strong negative space, minimalistic yet expressive, soft haze, long shadows, cinematic wide shot, natural color harmony, high dynamic range, artistic photography style." )

# 13 · Double Exposure Forest Silhouette
prompts+=( "A human silhouette filled with a dense forest landscape using double exposure technique, tall pine trees and mist blending seamlessly inside the figure, soft light rays piercing through fog, monochrome base with subtle green tint, surreal and introspective mood, clean edges with slight texture bleed, layered composition, fine art photography, high detail, soft contrast, ethereal atmosphere." )

# 14 · Liquid Chrome Silhouette (Fashion Editorial)
prompts+=( "A high-fashion silhouette of a model standing in a minimal studio, body outlined by reflective liquid chrome edges instead of light, pitch-black interior silhouette, glossy metallic highlights forming contours, stark white background, avant-garde editorial style, sharp shadows, geometric composition, ultra-clean, futuristic aesthetic, high resolution, studio lighting precision, Guy Bourdin meets sci-fi minimalism." )

# 15 · Cosmic Silhouette (Galaxy Within)
prompts+=( "A silhouette of a person looking upward, their interior filled with a vivid cosmic scene of galaxies, nebulae, and stars, deep purples, blues, and pinks glowing from within, subtle outer rim light separating figure from dark background, space dust particles floating outward, dreamy and philosophical tone, ultra-detailed astrophotography textures, soft glow, high contrast, surreal digital art." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Ethereal Dancer
prompts+=( "A breathtaking full-body silhouette of a graceful ballerina mid-pirouette, perfectly elegant pose with flowing dress and extended arms, dramatic rim lighting, strong black silhouette against a vibrant twilight sky with soft glowing clouds and subtle golden hour glow, minimalist yet highly detailed, cinematic composition, moody atmosphere, fine art photography, masterpiece, 8k." )

# 17 · Mystic Forest Spirit
prompts+=( "Stunning silhouette of a mysterious forest spirit woman standing among ancient trees, long flowing hair and cape merging with the wind, intricate organic shapes, powerful backlight from a blood moon, deep misty forest background with glowing particles, dark fantasy aesthetic, intricate branches framing the figure, ultra-detailed silhouette, ethereal and haunting beauty, cinematic, fine art, masterpiece." )

# 18 · Urban Goddess
prompts+=( "Elegant female silhouette standing on a rooftop at night, confident pose with wind-blown coat and dress, strong contrast against a futuristic cyberpunk city skyline with neon lights and flying cars, dramatic purple and teal rim lighting, breathtaking composition, cyber-noir aesthetic, sharp geometric lines, moody and stylish, cinematic masterpiece, highly detailed silhouette." )

# 19 · Desert Phantom
prompts+=( "Powerful and majestic silhouette of a lone figure in flowing robes walking across endless sand dunes at sunset, dramatic golden hour backlight creating a perfect black silhouette, massive sky with burning orange and magenta clouds, epic scale, minimalist composition, surreal desert atmosphere, fine art photography, National Geographic style, ultra cinematic, masterpiece." )

# 20 · Abstract Divine Form
prompts+=( "Highly artistic abstract silhouette of a divine feminine form made of pure elegant curves and flowing fabric, merging with cosmic elements, floating in space among stars and nebulae, strong backlight from a radiant galaxy, perfect composition with negative space, surreal fine art, ethereal glowing edges, minimalist yet incredibly detailed, symbolic and spiritual, dark academia aesthetic, masterpiece, 8k." )

# ── Qwen 3.6+ ───────────────────────────────────────────────────────────────

# 21 · Art Nouveau Dancer
prompts+=( "A solid black silhouette of a graceful dancer mid-leap against a soft gradient background transitioning from deep twilight blue to warm peach. Negative space subtly reveals delicate Art Nouveau floral and vine patterns woven into the figure's form. Faint golden rim lighting traces the outer edges. Minimalist composition, high contrast, dreamlike and elegant aesthetic, clean vector-like silhouette with atmospheric depth." )

# 22 · Cinematic Neon Noir Rooftop
prompts+=( "A striking silhouette of a lone figure standing on a rain-slicked urban rooftop at dusk. The figure is completely solid black, sharply contrasted against a moody sky blending indigo, magenta, and charcoal. Subtle neon rim lighting from unseen city signs casts cyan and amber glows along the silhouette's edges. Strong geometric framing, dramatic negative space, cinematic atmosphere, photorealistic lighting with a minimalist graphic aesthetic." )

# 23 · Cosmic Double-Exposure Profile
prompts+=( "An elegant side-profile silhouette of a human head and shoulders, filled with a seamless double-exposure of a swirling nebula, distant stars, and faint planetary rings. The outer boundary is a crisp, solid black shape against a clean off-white background. High-contrast minimalist design, ethereal and contemplative, contemporary digital illustration style, masterful use of negative space and internal texture blending." )

# 24 · Ink Wash Scholar with Gold Contour
prompts+=( "A highly aesthetic silhouette of a traditional East Asian scholar holding a folding fan, rendered in the style of classical ink wash painting. The figure is a rich, solid black shape against a textured rice-paper background with faint misty mountain gradients. Subtle brushstroke irregularities define the silhouette's edges, and a single delicate line of metallic gold traces the outer contour. Serene, poetic composition, cultural elegance, balanced positive/negative space." )

# 25 · Geometric Stained-Glass Fragment
prompts+=( "A modern artistic silhouette of a standing human figure fractured into sharp geometric facets, evoking a contemporary stained-glass window. The base shape is solid black, but precise negative space gaps reveal a luminous background of prismatic light rays in teal, amber, and violet. Clean graphic design composition, high contrast, minimalist yet visually rich, gallery-ready contemporary art style, crisp vector-like edges." )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · Ethereal Forest Dancer
prompts+=( "A breathtaking silhouette of an elegant dancer mid-pirouette among ancient gnarled trees, captured during golden hour sunset. The figure's flowing dress creates dynamic sweeping curves against a vibrant gradient sky transitioning from deep amber to soft lavender and rose pink. Delicate leaves and petals float in the air, catching the backlight and glowing like tiny embers. The composition features dramatic negative space, with the dancer's arms extended gracefully upward. Ultra-high contrast between the solid black silhouette and luminous atmospheric background. Cinematic lighting, ethereal mood, fine art photography style, 8k resolution, dreamlike quality, bokeh light particles scattered throughout." )

# 27 · Urban Romance at Dusk
prompts+=( "Romantic silhouette of a couple embracing on a rooftop overlooking a sprawling cityscape at twilight. Their profiles merge into one harmonious shape against a magnificent sky painted in deep indigo, magenta, and burning orange hues. Below them, countless city lights begin to twinkle like scattered diamonds, creating a sea of warm bokeh. The couple's outlines are crisp and defined, showing details of flowing hair and clothing billowing in the gentle breeze. Architectural silhouettes of distant skyscrapers layer into the misty atmosphere. Moody, cinematic composition with strong emotional resonance. Fine art aesthetic, dramatic chiaroscuro effect, ultra-detailed, professional photography." )

# 28 · Mythical Phoenix Rising
prompts+=( "A majestic phoenix bird in explosive mid-flight silhouette, wings fully spread in a powerful ascending arc, rising from mystical flames. The mythical creature's elegant form features intricate feather details visible as delicate textural edges against a supernatural cosmic background of swirling nebula colors — deep violet, electric blue, and fiery crimson blending into cosmic clouds. Golden sparks and ember-like particles trail behind the phoenix, creating a sense of motion and magic. Epic fantasy art style, highly dramatic, otherworldly atmosphere, celestial lighting, masterpiece quality, incredibly detailed silhouette with ornate feather patterns suggested through edge lighting." )

# 29 · Solitary Sailor on Stormy Seas
prompts+=( "A lone sailor standing resolute at the helm of a ship, captured as a powerful silhouette against a tumultuous stormy ocean sunset. Massive waves crest and crash around the vessel, their spray catching the dying light and creating silver-edged foam. The sailor's posture conveys determination and solitude — one hand gripping the wheel, coat whipping in the wind. Lightning forks in the distance through dark purple-gray clouds, while breaks in the storm reveal brilliant golden-orange light piercing through. Seagulls circle as small silhouetted shapes. Dramatic maritime atmosphere, romantic era painting inspiration, high contrast, emotional depth, epic scale, fine art photography aesthetic, moody and atmospheric." )

# 30 · Ballet of Wild Horses
prompts+=( "A stunning ensemble of wild horses galloping across a vast plain, captured as multiple overlapping silhouettes against an expansive African savanna sunset. The horses display various dynamic poses — some rearing, others running full stride, manes and tails flowing wildly. Their muscular forms create beautiful curved lines and negative space patterns. The background features a massive sun sitting low on the horizon, casting long golden rays through atmospheric dust and creating a radiant halo effect. Acacia trees dot the landscape as smaller silhouettes. Dust kicked up by hooves catches the light, creating golden mist. National Geographic meets fine art style, incredible sense of movement and freedom, warm color palette, epic wilderness beauty, museum-quality composition." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · Ethereal Forest Dancer
prompts+=( "A lone ballerina silhouette mid-pirouette, her flowing dress dissolving into thousands of luminous fireflies and bioluminescent spores. Deep indigo twilight forest background, towering ancient trees framing the scene. Ethereal volumetric light rays piercing through the canopy, catching the glowing particles. Dreamlike atmosphere, soft bokeh, magical realism, highly detailed, cinematic composition." )

# 32 · Neon City Replicant
prompts+=( "Sharp profile silhouette of a cyberpunk figure standing on a rain-slicked rooftop, long coat billowing in the wind. Behind them, a sprawling futuristic megacity glows with saturated magenta, electric cyan, and warm amber neon signs. Reflections shimmer on wet surfaces. Moody atmosphere, high contrast, Blade Runner aesthetic, cinematic lighting, ultra-detailed architecture." )

# 33 · Celestial Cartographer
prompts+=( "A solitary astronomer silhouette standing atop a craggy mountain peak, pointing a brass telescope toward a breathtaking cosmic sky filled with swirling galaxies, nebulae in deep purple and gold, and a massive blood moon. Wisps of clouds curl around the mountain. Epic scale, wonder and discovery mood, painterly digital art style, rich color grading, dramatic chiaroscuro." )

# 34 · Kintsugi Warrior
prompts+=( "Graceful silhouette of a samurai in mid-draw, composed entirely of shattered golden cracks and glowing amber light against a void-black background. The cracks emit warm radiance, suggesting inner strength through brokenness. Minimalist composition, negative space, Japanese aesthetic, spiritual atmosphere, elegant lines, museum-quality fine art, ultra-high contrast." )

# 35 · Desert Mirage Weaver
prompts+=( "A robed Bedouin figure silhouette walking across endless golden dunes, their form partially translucent and merging with a massive swirling sandstorm that catches the last light of sunset — burning oranges, deep crimsons, and violet shadows. Flocks of birds scatter in the distance. Timeless, contemplative mood, epic landscape photography style, warm palette, atmospheric haze, painterly textures." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

