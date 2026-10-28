#!/usr/bin/env bash

set -euo pipefail

MODEL="${MODEL:-}"

if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/OpenMOSS-Team/MOSS-Image-SFT"' >&2
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

# Converts an authored layout (bbox = [y_min, x_min, y_max, x_max] as 0..1
# fractions of the canvas) into a final MOSS-Image layout prompt:
#   bbox_coord_space = "abs_centralized"  (pixels, origin at canvas centre)
#   bbox_format      = "yxyx"
# using the WIDTH / HEIGHT of the image being generated. Output is compact JSON.
layout_to_prompt() {
  jq -c --argjson w "$WIDTH" --argjson h "$HEIGHT" '
    def cy: ((. * $h) - ($h / 2) | round);
    def cx: ((. * $w) - ($w / 2) | round);
    .items |= map(.bbox = [ (.bbox[0] | cy), (.bbox[1] | cx),
                            (.bbox[2] | cy), (.bbox[3] | cx) ])
    | . + { bbox_coord_space: "abs_centralized", bbox_format: "yxyx" }
  ' <<< "$1"
}

queue_job() {
  local index="$1"
  local layout="$2"

  local prompt caption task_name
  prompt="$(layout_to_prompt "$layout")"
  caption="$(jq -r '.summary.caption' <<< "$layout")"
  task_name="$(printf '%02d' "$index") ${caption:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${caption:0:120}"

  local json
  json=$(jq -n \
    --arg prompt "$prompt" \
    --arg sampler "$SAMPLER" \
    --arg model "$MODEL" \
    --argjson steps $STEPS \
    --argjson cfg $CFG \
    --argjson ag $AG \
    --argjson w $WIDTH \
    --argjson h $HEIGHT \
    --argjson seed $SEED \
    '{
      sd_model_checkpoint: $model,
      prompt: $prompt,
      steps: $steps,
      cfg_scale: $cfg,
      pag_scale: $ag,
      width: $w,
      height: $h,
      sampler_name: $sampler,
      seed: $seed,
      batch_size: 1,
      n_iter: 1,
      save_images: true
    }')

  curl -s -X POST "$SCHED?name=$(urlencode "$task_name")" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null
}

# ---- PROMPTS ---------------------------------------------------------------
# Source: https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v3
# Structure: 9 rows (themes) × 4 columns (A–D, escalating complexity) = 36 prompts
# Queued row-by-row: 1A 1B 1C 1D / 2A 2B … / 9A 9B 9C 9D
#
# Every prompt is a MOSS-Image layout prompt:
#   summary.caption  – overall scene and style
#   items[]          – label (text | character | object), caption, bbox,
#                      plus "text" (exact string to render) for text items
# Text that must appear in the image lives in the "text" field of text items.
#
# Authoring convention in this file: bbox = [y_min, x_min, y_max, x_max] as
# FRACTIONS (0..1) of the canvas. layout_to_prompt() turns them into the
# abs_centralized pixel coordinates MOSS expects, for whatever WIDTH/HEIGHT
# you export, so the same file works for any resolution or aspect ratio.
# ---------------------------------------------------------------------------

prompts=()

# ── Row 1 · Portraits ───────────────────────────────────────────────────────

# 1A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "close-up"],
    "canvas": "single",
    "caption": "A close-up photograph focuses on a nice young woman's left ear, featuring a multi-layered gold drop earring. The person has blonde hair, light skin, and is looking slightly downwards with their head tilted to the right. The setting is an indoor studio with a soft, warm light and a neutral, textured background."
  },
  "items": [
    {"label": "character", "caption": "A nice young woman with blonde hair and light skin, looking slightly downwards with her head tilted to the right; her left ear is the focus of the frame.", "bbox": [0.05, 0.15, 0.98, 0.85]},
    {"label": "object", "caption": "A multi-layered gold drop earring with two chains of different lengths, three cubic zirconia-studded flower clusters connected by thin chains and small gold beads.", "bbox": [0.35, 0.40, 0.80, 0.65]},
    {"label": "object", "caption": "A hand with neatly manicured nails resting near the hair.", "bbox": [0.15, 0.62, 0.55, 0.95]}
  ]
}
JSON
)" )

# 1B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph"],
    "canvas": "single",
    "caption": "A woman wearing a dress is laying in grass."
  },
  "items": [
    {"label": "character", "caption": "A woman wearing a dress, laying in the grass.", "bbox": [0.30, 0.10, 0.75, 0.90]},
    {"label": "object", "caption": "Grass surrounding the woman.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 1C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "fashion", "film noir"],
    "canvas": "single",
    "caption": "Close-up portrait of a mysterious and elegant black woman wearing a large wide-brimmed black hat that obscures her eyes, casting a deep shadow over the upper half of her face. Dramatic low-key lighting with a spotlight from the side creates high contrast between light and shadow (chiaroscuro), highlighting her cheek, lips, and shoulder against a dark, moody background. Cinematic noir style, fashion photography aesthetic, 8k resolution, highly detailed."
  },
  "items": [
    {"label": "object", "caption": "A large wide-brimmed black hat that obscures her eyes and casts a deep shadow over the upper half of her face.", "bbox": [0.02, 0.15, 0.40, 0.85]},
    {"label": "character", "caption": "A mysterious and elegant black woman with dark brown skin and dark glossy lips; her cheek and lips are lit by a side spotlight.", "bbox": [0.15, 0.25, 0.80, 0.80]},
    {"label": "object", "caption": "A black off-the-shoulder top that exposes her bare shoulder, which catches the spotlight.", "bbox": [0.65, 0.10, 1.0, 0.90]},
    {"label": "object", "caption": "Her hand with dark nail polish, gently touching the rim of the hat.", "bbox": [0.20, 0.65, 0.50, 0.95]}
  ]
}
JSON
)" )

# 1D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "low-key", "widescreen"],
    "canvas": "single",
    "caption": "A dark-toned portrait photograph. The horizontal widescreen composition is highly dramatic and artistic, with at least 80% of the area being pure negative space from deep graphite to absolute black, pooling thickly on the left side and center of the frame. Studio low-key lighting with refined edge illumination traces her brow, the sharp ridge of her nose, the compressed line of her lips, and the geometric cold glint of the brass instrument, while the unlit side of her face and hand dissolve entirely into the black. The mood is precise, architectural, and quietly formidable."
  },
  "items": [
    {"label": "object", "caption": "Pure negative space from deep graphite to absolute black, pooling thickly on the left side and center of the frame.", "bbox": [0.0, 0.0, 1.0, 0.78]},
    {"label": "character", "caption": "A close-up profile of a young Polish woman in her late twenties, facing left. Only the clean line of her profile, the pale curve of her ear, and a loose strand of ash-blonde hair escaping from a bun are visible. Her expression is one of concentrated analysis, as though measuring something invisible.", "bbox": [0.10, 0.78, 0.80, 1.0]},
    {"label": "object", "caption": "A traditional drafting compass, its metal handle rising from her grip, the two legs closed together so that the fine brass pivot point rests lightly at the corner of her mouth where lip meets skin. Her fingers hold it the way a conductor holds a baton.", "bbox": [0.35, 0.72, 0.95, 0.92]}
  ]
}
JSON
)" )

# ── Row 2 · Body Part ───────────────────────────────────────────────────────

# 2A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "fine art", "wedding photography", "high key"],
    "canvas": "single",
    "caption": "A woman's hand reaching toward the camera in extreme close-up foreshortening, crushed white background, dutch angle 18°, skin texture lit by a single cold silver sidelight, fine art wedding photography, shot on large format film, grain texture, high key."
  },
  "items": [
    {"label": "object", "caption": "A woman's hand reaching toward the camera with neatly manicured nails; the fingertips are razor-sharp and enormous in the foreground while the wrist and arm taper into soft creamy distance.", "bbox": [0.10, 0.20, 0.95, 0.85]},
    {"label": "object", "caption": "A delicate ring on the ring finger catching specular highlights.", "bbox": [0.40, 0.45, 0.55, 0.60]}
  ]
}
JSON
)" )

# 2B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "commercial", "macro", "studio"],
    "canvas": "single",
    "caption": "Close-up profile view of a woman with dark skin holding a piece of dark chocolate in her mouth by her teeth. The background is plain white. High-resolution commercial photography, studio lighting, macro shot focusing on texture and detail."
  },
  "items": [
    {"label": "character", "caption": "A woman with dark skin in close-up profile view. Her lips are coated in high-gloss taupe lipstick, appearing very shiny and moist, and her white upper teeth are visible.", "bbox": [0.10, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "A piece of dark chocolate held in her mouth by her teeth.", "bbox": [0.50, 0.55, 0.65, 0.78]},
    {"label": "object", "caption": "A hand with matte taupe nail polish.", "bbox": [0.60, 0.10, 0.95, 0.40]}
  ]
}
JSON
)" )

# 2C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "low angle", "close-up"],
    "canvas": "single",
    "caption": "A low-angle, close-up photograph capturing the lower half of a Black woman walking carefully and barefoot along a single, polished steel railway rail, centered in the frame. The background is a soft, natural bokeh of green foliage and trees in diffuse natural light. The focus is sharp on the feet, rail."
  },
  "items": [
    {"label": "character", "caption": "The lower half of a Black woman wearing a white pen dress, walking carefully and barefoot; her dark-skinned feet are poised on the narrow top of the rail.", "bbox": [0.10, 0.30, 1.0, 0.70]},
    {"label": "object", "caption": "A single, polished steel railway rail, centered in the frame, set among textured ballast (gravel), old wooden sleepers, and scattered dry autumn leaves.", "bbox": [0.0, 0.30, 1.0, 0.70]},
    {"label": "object", "caption": "A pair of vibrant, glossy red patent leather high-heeled stiletto pumps, held in her hand on the right side of the frame and dangling by their heels.", "bbox": [0.35, 0.65, 0.85, 0.90]},
    {"label": "object", "caption": "Soft, natural bokeh of green foliage and trees in diffuse natural light.", "bbox": [0.0, 0.0, 0.40, 1.0]}
  ]
}
JSON
)" )

# 2D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "low angle", "foreshortening"],
    "canvas": "single",
    "caption": "A beautiful Japanese woman seated on a bar bench, crossed legs in high heel sandals. Looking at the camera, expressionless. Camera angle low angle, point of view from the ground. Focus on toes. Foreshortening."
  },
  "items": [
    {"label": "character", "caption": "A beautiful Japanese woman seated with crossed legs, looking at the camera, expressionless.", "bbox": [0.05, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "High heel sandals on her crossed legs, with the toes in sharp focus in the foreground, strongly foreshortened.", "bbox": [0.60, 0.30, 1.0, 0.80]},
    {"label": "object", "caption": "A bar bench she is seated on.", "bbox": [0.40, 0.20, 0.85, 0.80]}
  ]
}
JSON
)" )

# ── Row 3 · Nature ──────────────────────────────────────────────────────────

# 3A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "minimalism", "landscape", "golden hour"],
    "canvas": "single",
    "caption": "Sacura blossom branch on the right 25%, minimalism, blurred mountains and ocean with small fisher boats far away from a coast, on a still water surface, golden hour lighting."
  },
  "items": [
    {"label": "object", "caption": "A Sacura blossom branch occupying the right 25% of the frame.", "bbox": [0.05, 0.75, 0.60, 1.0]},
    {"label": "object", "caption": "Blurred mountains in the distance.", "bbox": [0.35, 0.0, 0.55, 0.75]},
    {"label": "object", "caption": "Ocean on a still water surface, lit by golden hour light.", "bbox": [0.50, 0.0, 1.0, 0.75]},
    {"label": "object", "caption": "Small fisher boats far away from a coast.", "bbox": [0.58, 0.20, 0.68, 0.60]}
  ]
}
JSON
)" )

# 3B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "landscape"],
    "canvas": "single",
    "caption": "Beautiful nature scenery."
  },
  "items": [
    {"label": "object", "caption": "Beautiful nature scenery filling the whole frame.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 3C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "minimalist", "seascape", "photorealistic"],
    "canvas": "single",
    "caption": "Single Boat on Calm Sea. Minimalist seascape, serene and contemplative mood, soft diffused daylight, highly detailed yet simple, photorealistic, square composition with incredible breathing room."
  },
  "items": [
    {"label": "object", "caption": "A perfectly still, mirror-like ocean that fills most of the image, with subtle reflections and gentle gradients of deep blue to turquoise; vast open water creating powerful negative space.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "A small wooden fishing boat floating alone in the lower right corner of the frame.", "bbox": [0.68, 0.60, 0.88, 0.90]}
  ]
}
JSON
)" )

# 3D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["conceptual", "negative space"],
    "canvas": "single",
    "caption": "A conceptual negative space image. A solid, pitch-black canvas. Atmospheric fog, mystical mood, sharp transitions between light and shadow."
  },
  "items": [
    {"label": "object", "caption": "Thin, elegant beams of ethereal white light piercing downward from the top, forming the gaps between invisible trees. The shapes of the trunks are created purely by the absence of light.", "bbox": [0.0, 0.05, 1.0, 0.95]},
    {"label": "object", "caption": "Atmospheric fog drifting through the beams of light.", "bbox": [0.55, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# ── Row 4 · City ────────────────────────────────────────────────────────────

# 4A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cityscape"],
    "canvas": "single",
    "caption": "Small town street with gas station, cafe with tables outside, couple of cars and next big city cityscape on the horizon."
  },
  "items": [
    {"label": "object", "caption": "A big city cityscape on the horizon.", "bbox": [0.15, 0.0, 0.40, 1.0]},
    {"label": "object", "caption": "A gas station.", "bbox": [0.35, 0.02, 0.75, 0.40]},
    {"label": "object", "caption": "A cafe with tables outside.", "bbox": [0.40, 0.55, 0.80, 0.98]},
    {"label": "object", "caption": "A couple of cars on the street.", "bbox": [0.65, 0.25, 0.90, 0.65]},
    {"label": "object", "caption": "A small town street.", "bbox": [0.65, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 4B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "street photography", "vintage", "Kodachrome"],
    "canvas": "single",
    "caption": "Authentic 1970s Kodachrome street photography: a young stylish Caucasian woman in wide bell-bottom jeans and a patterned blouse walks past a record store. Film grain, slightly faded warm color shift, 1971, New York City, slice of life documentary."
  },
  "items": [
    {"label": "character", "caption": "A young stylish Caucasian woman in wide bell-bottom jeans and a patterned blouse, walking past the record store.", "bbox": [0.25, 0.05, 0.98, 0.40]},
    {"label": "text", "caption": "The record store name written on the glass in the center of the shop window.", "text": "Music", "bbox": [0.20, 0.50, 0.30, 0.90]},
    {"label": "object", "caption": "The record store window displaying albums, including the four listed covers and other albums.", "bbox": [0.32, 0.45, 0.80, 0.98]},
    {"label": "text", "caption": "Album cover in the window.", "text": "The Rolling Stones - Sticky Fingers", "bbox": [0.35, 0.50, 0.52, 0.72]},
    {"label": "text", "caption": "Album cover in the window.", "text": "Bee Gees - Cucumber Castle", "bbox": [0.35, 0.74, 0.52, 0.96]},
    {"label": "text", "caption": "Album cover in the window.", "text": "The Beatles - Abbey Road", "bbox": [0.55, 0.50, 0.72, 0.72]},
    {"label": "text", "caption": "Album cover in the window.", "text": "Led Zeppelin - Led Zeppelin II", "bbox": [0.55, 0.74, 0.72, 0.96]},
    {"label": "text", "caption": "Handwritten text on the bent upper left corner of the photo.", "text": "1971 N.Y.", "bbox": [0.02, 0.02, 0.10, 0.25]}
  ]
}
JSON
)" )

# 4C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "liminal space", "cinematic"],
    "canvas": "single",
    "caption": "A photorealistic liminal space of a vintage gas station isolated in a thick, heavy midnight fog. The only light source is the glowing white canopy and a single buzzing neon sign. The surrounding environment is pitch black. Volumetric lighting catching the mist, cinematic bokeh, eerie loneliness."
  },
  "items": [
    {"label": "object", "caption": "A vintage gas station with a glowing white canopy, isolated in thick, heavy midnight fog.", "bbox": [0.30, 0.15, 0.55, 0.85]},
    {"label": "object", "caption": "A single buzzing neon sign.", "bbox": [0.15, 0.60, 0.35, 0.80]},
    {"label": "object", "caption": "Hyper-realistic asphalt texture with puddles reflecting the light.", "bbox": [0.70, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 4D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["sgraffito", "metal", "minimalism", "wallpaper"],
    "canvas": "single",
    "caption": "A sparse cityscape suggested by the absolute minimum of scratched lines in black paint revealing warm brass beneath, sgraffito on metal. Vast areas of unscratched matte black dominate the composition; the city reads from near-emptiness, economy of mark, each scratch deliberate and load-bearing, architectural shorthand, no fill no shading no texture beyond the bare structural lines. Wide horizontal composition, the scratches feel like a draftsman's first skeleton pass never completed, warm antique gold lines on deep black, desktop wallpaper."
  },
  "items": [
    {"label": "object", "caption": "Only the essential scratched strokes needed to imply a skyline: a few vertical towers, window grids, and a horizon line, in warm antique gold lines revealing brass beneath the paint.", "bbox": [0.25, 0.05, 0.80, 0.95]},
    {"label": "object", "caption": "Vast areas of unscratched matte black paint with negative space doing most of the work.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# ── Row 5 · Art Styles ──────────────────────────────────────────────────────

# 5A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["watercolor", "ink painting", "illustration"],
    "canvas": "single",
    "caption": "Watercolor ink painting. Woman holding umbrella. Rain. City. Taxi. Neon lights."
  },
  "items": [
    {"label": "character", "caption": "A woman holding an umbrella in the rain.", "bbox": [0.20, 0.30, 0.85, 0.60]},
    {"label": "object", "caption": "An umbrella.", "bbox": [0.10, 0.22, 0.35, 0.68]},
    {"label": "object", "caption": "A taxi on a rainy city street.", "bbox": [0.60, 0.55, 0.90, 0.95]},
    {"label": "object", "caption": "A rainy city with glowing neon lights.", "bbox": [0.0, 0.0, 0.55, 1.0]}
  ]
}
JSON
)" )

# 5B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["pixel art"],
    "canvas": "single",
    "caption": "Pixel art. Beautiful young woman in a light dress sitting in the cafe of coastal city, drinking wine and watching sunset. Solo."
  },
  "items": [
    {"label": "character", "caption": "A beautiful young woman in a light dress, sitting alone, drinking wine and watching the sunset.", "bbox": [0.35, 0.25, 0.95, 0.60]},
    {"label": "object", "caption": "A cafe in a coastal city.", "bbox": [0.30, 0.0, 1.0, 0.80]},
    {"label": "object", "caption": "A sunset over the sea.", "bbox": [0.0, 0.0, 0.50, 1.0]}
  ]
}
JSON
)" )

# 5C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "triple exposure", "fine art", "coming-of-age"],
    "canvas": "single",
    "caption": "Triple exposure with a teenage girl's side profile silhouette as the containing form. The two light sources of layers two and three, road and room, are engaged in a precise chromatic tension within the portrait, neither resolving; the profile silhouette holds both realities without choosing between them. Palette of television amber, headlight white, taillight red, and deep suburban shadow, the in-between rendered as portraiture. Fujifilm GFX 50SII, 110mm f/2, blue hour, Provia simulation, fine art coming-of-age photography, Huis Marseille exhibition quality."
  },
  "items": [
    {"label": "character", "caption": "Layer one: a teenage girl's side profile silhouette as the containing form.", "bbox": [0.05, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "Layer two: an elevated motorway overpass shot at blue hour, with headlight and taillight trails of opposing traffic streams bisecting the face in warm red and cool white arcs, and asphalt texture mapping onto the skin of her neck and jaw.", "bbox": [0.30, 0.30, 0.95, 0.80]},
    {"label": "object", "caption": "Layer three: a suburban living room interior at evening, with television glow, a low bookshelf, and a half-open door projecting soft domestic amber into the skull cavity.", "bbox": [0.05, 0.35, 0.55, 0.75]},
    {"label": "object", "caption": "Her hair dissolving into the dark periphery of a motorway shoulder at night.", "bbox": [0.0, 0.55, 0.45, 1.0]}
  ]
}
JSON
)" )

# 5D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["abstract art"],
    "canvas": "single",
    "caption": "Abstract art in gold and black colors."
  },
  "items": [
    {"label": "object", "caption": "An abstract composition in gold and black colors filling the whole canvas.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# ── Row 6 · Illustration ────────────────────────────────────────────────────

# 6A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "watercolor", "ukiyo-e", "gold leaf"],
    "canvas": "single",
    "caption": "A detailed illustration and watercolor painting of a red-crowned crane standing gracefully in shallow water, rendered in a style blending traditional Japanese ukiyo-e woodblock printing and gold-leaf lacquer techniques. The palette is restrained to black, white, red, gold, and cool gray tones, with fine ink-line detailing and visible paper grain."
  },
  "items": [
    {"label": "object", "caption": "A red-crowned crane standing gracefully in shallow water, shown in profile facing left, depicted in crisp whites, deep blacks, and accents of vermilion and brushed gold along its wings.", "bbox": [0.20, 0.10, 0.90, 0.65]},
    {"label": "object", "caption": "A tranquil marsh landscape with distant reeds and a fading horizon, composed of layered washes of muted indigo, soft ash gray, and pale ivory.", "bbox": [0.35, 0.0, 0.65, 0.65]},
    {"label": "object", "caption": "Tall lotus stems and seed pods arching from the right, framing the composition.", "bbox": [0.0, 0.65, 0.85, 1.0]},
    {"label": "object", "caption": "Scattered gold-leaf textures applied to ripples in the water.", "bbox": [0.75, 0.05, 1.0, 0.65]},
    {"label": "object", "caption": "Subtle cloud forms above with gold-leaf texture.", "bbox": [0.0, 0.05, 0.25, 0.60]}
  ]
}
JSON
)" )

# 6B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["pixel art", "icon"],
    "canvas": "single",
    "caption": "256 colors 32px pixel-art diskette icon."
  },
  "items": [
    {"label": "object", "caption": "A 256 colors 32px pixel-art diskette icon.", "bbox": [0.15, 0.15, 0.85, 0.85]}
  ]
}
JSON
)" )

# 6C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "silhouette"],
    "canvas": "single",
    "caption": "Samurai, sunset, silhouette, dramatic lighting, wind, dynamic pose, dynamic angle."
  },
  "items": [
    {"label": "character", "caption": "A samurai in silhouette with a dynamic pose, seen from a dynamic angle, with wind in the clothing.", "bbox": [0.25, 0.25, 0.95, 0.75]},
    {"label": "object", "caption": "A sunset sky with dramatic lighting.", "bbox": [0.0, 0.0, 0.65, 1.0]}
  ]
}
JSON
)" )

# 6D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "graphic novel", "surreal", "noir"],
    "canvas": "single",
    "caption": "A surreal noir masterpiece. Extremely high contrast, dramatic chiaroscuro, graphic novel illustration style, moody and ethereal."
  },
  "items": [
    {"label": "character", "caption": "A woman sitting on a skyscraper ledge overlooking a dark, stylized city. Her eyes are a piercing, supernatural glowing cyan.", "bbox": [0.25, 0.30, 0.75, 0.65]},
    {"label": "object", "caption": "Her wings, made of liquid black ink that drips upward toward the moon like smoke.", "bbox": [0.0, 0.15, 0.55, 0.85]},
    {"label": "object", "caption": "The moon in the night sky.", "bbox": [0.02, 0.60, 0.22, 0.80]},
    {"label": "object", "caption": "A dark, stylized city far below.", "bbox": [0.65, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# ── Row 7 · Anime / Comics / Poster ─────────────────────────────────────────

# 7A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["doodle", "cartoon"],
    "canvas": "single",
    "caption": "Doodle of a cat peeking out from behind a corner. Cat speech bubble reads Need food."
  },
  "items": [
    {"label": "character", "caption": "A cat peeking out from behind a corner.", "bbox": [0.30, 0.15, 0.90, 0.55]},
    {"label": "text", "caption": "The cat's speech bubble.", "text": "Need food", "bbox": [0.10, 0.45, 0.35, 0.90]}
  ]
}
JSON
)" )

# 7B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["poster", "infographic", "cafe", "hand made paper"],
    "canvas": "single",
    "caption": "Charming, aesthetically pleasing photo info-graphic poster for a small cafe. The entire poster has a soft and warm texture, printed on hand made paper. The background is a soft cream color, decorated with subtle coffee beans and floral motifs. The poster has a rustic, cozy feel, framed by a delicate line border."
  },
  "items": [
    {"label": "text", "caption": "The poster title above the glass, written in modern script.", "text": "LATTE vs. CAPPUCCINO", "bbox": [0.04, 0.10, 0.16, 0.90]},
    {"label": "object", "caption": "In the center, a clear glass mug split vertically down the middle by a thin, dotted line. Left side, latte: the glass is filled mostly with creamy, light-brown steamed milk, topped with a thin layer of microfoam and simple, elegant latte art. Right side, cappuccino: the glass has distinct layers, a dark-espresso base, a generous layer of steamed milk, and a thick, airy head of frothy milk foam, topped with a sprinkle of cocoa powder.", "bbox": [0.20, 0.30, 0.65, 0.70]},
    {"label": "text", "caption": "Three numbered points listed to the left of the glass, about the latte.", "text": "1. More Steamed Milk\n2. Milder & Smoother\n3. Small Layer of Foam", "bbox": [0.30, 0.04, 0.60, 0.28]},
    {"label": "text", "caption": "Three numbered points listed to the right of the glass, about the cappuccino.", "text": "1. Balanced Milk/Foam\n2. Richer Espresso\n3. Thicker Frothy Cap", "bbox": [0.30, 0.72, 0.60, 0.96]},
    {"label": "text", "caption": "Subtly written at the very bottom of the poster.", "text": "Nerd Cafe", "bbox": [0.93, 0.35, 0.99, 0.65]},
    {"label": "object", "caption": "Soft cream background decorated with subtle coffee beans and floral motifs, framed by a delicate line border.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 7C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["comic", "illustration", "4-panel"],
    "canvas": "single",
    "caption": "A vertically arranged 4-panel comic page in a cinematic, semi-realistic comic book illustration style, clean line art with rich colors and dramatic lighting, Star Wars prequel aesthetic mixed with modern meme humor. Layout: clean 2x2 grid comic page layout with thin white borders between panels, subtle drop shadows on panels, overall warm golden hour lighting, high detail, vibrant colors, professional comic book style, sharp focus, quality illustration. Star Wars Episode II characters: Padmé Amidala is 24 years old. Her hair styled in the classic side buns covered with intricate gold hair nets (snoods) and wears a green headband adorned with small pink flower knitting her forehead above her eyebrows. She is wearing a revealing off-shoulder beige floral dress with deep cleavage. She has brown eyes. Anakin Skywalker is 19 years old. He has short, swept-back dirty blonde hair with a distinctive long, thin braided lock hanging down past his right shoulder. He is wearing brown Jedi tunic robes layered under a dark blue, sleeveless vest. He has piercing blue eyes."
  },
  "items": [
    {"label": "character", "caption": "Panel 1 (top left): Anakin sitting in a sunny green meadow full of wildflowers, looking slightly concerned toward the right.", "bbox": [0.01, 0.01, 0.49, 0.49]},
    {"label": "text", "caption": "Panel 1 speech bubble from Anakin.", "text": "We need to build more Data Centers. AI needs it.", "bbox": [0.03, 0.05, 0.18, 0.47]},
    {"label": "character", "caption": "Panel 2 (top right): face only close-up of Padmé smiling brightly and happily in the meadow, looking excited.", "bbox": [0.01, 0.51, 0.49, 0.99]},
    {"label": "text", "caption": "Panel 2 speech bubble from Padmé.", "text": "To cure cancer, right?", "bbox": [0.03, 0.53, 0.15, 0.97]},
    {"label": "character", "caption": "Panel 3 (bottom left): face only close-up of Anakin with a skeptical, slightly annoyed expression, one eyebrow raised, looking toward the right, meadow background.", "bbox": [0.51, 0.01, 0.99, 0.49]},
    {"label": "character", "caption": "Panel 4 (bottom right): a slightly pulled-back medium shot of Padmé standing in the meadow, now with a much more voluptuous figure, looking at the viewer with a mix of confusion and pleading expression. The composition shows her from the waist up in the field.", "bbox": [0.51, 0.51, 0.99, 0.99]},
    {"label": "text", "caption": "Panel 4 speech bubble from Padmé.", "text": "We are curing cancer, right?", "bbox": [0.53, 0.53, 0.65, 0.97]}
  ]
}
JSON
)" )

# 7D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["3D render", "isometric", "miniature", "diorama", "cartoon"],
    "canvas": "single",
    "caption": "A charming isometric 45° top-down miniature 3D cartoon scene of Oslo during a bright spring day, presented as a clean, whimsical diorama under a clear blue sky with soft white clouds. Use soft, refined PBR textures with gentle realistic materials: natural wood cladding and glass on the Opera House, weathered stone and aged metal on the fortress, and polished metal and glass on modern buildings. Apply lifelike yet soft daytime lighting and shadows, golden spring sunlight from the south-east casting gentle highlights and long soft shadows. Integrate current weather: clear sunny skies, crisp spring air. Keep the composition clean and minimalistic with a soft solid pastel blue background. All text centered with balanced spacing, subtly overlapping the tops of the tallest buildings without obscuring landmarks. Square resolution, high detail, cute yet sophisticated miniature style, vibrant spring colors and harmonious daylight lighting."
  },
  "items": [
    {"label": "text", "caption": "Title at the top-center in large bold modern sans-serif font.", "text": "Oslo", "bbox": [0.03, 0.30, 0.13, 0.70]},
    {"label": "object", "caption": "A prominent sunny weather icon beneath the title.", "bbox": [0.14, 0.45, 0.22, 0.55]},
    {"label": "text", "caption": "The date in small elegant text.", "text": "May 9, 2026", "bbox": [0.23, 0.38, 0.28, 0.62]},
    {"label": "text", "caption": "The temperature in medium-sized text.", "text": "15°C", "bbox": [0.29, 0.40, 0.36, 0.60]},
    {"label": "object", "caption": "The unique, wave-like Oslo Opera House by the water.", "bbox": [0.50, 0.05, 0.85, 0.40]},
    {"label": "object", "caption": "The Akershus Fortress overlooking the harbor.", "bbox": [0.40, 0.40, 0.75, 0.70]},
    {"label": "object", "caption": "The Holmenkollen Ski Jump standing tall on the distant hills.", "bbox": [0.28, 0.65, 0.55, 0.95]},
    {"label": "object", "caption": "The intricate buildings of the Aker Brygge waterfront.", "bbox": [0.55, 0.60, 0.90, 0.98]}
  ]
}
JSON
)" )

# ── Row 8 · Macro ───────────────────────────────────────────────────────────

# 8A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro"],
    "canvas": "single",
    "caption": "Water drop hanging on a leaf tip reflecting the cityscape."
  },
  "items": [
    {"label": "object", "caption": "A leaf with its tip pointing down.", "bbox": [0.10, 0.05, 0.85, 0.80]},
    {"label": "object", "caption": "A water drop hanging on the leaf tip, reflecting the cityscape.", "bbox": [0.60, 0.55, 0.88, 0.80]}
  ]
}
JSON
)" )

# 8B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "tilt shift", "miniature effect"],
    "canvas": "single",
    "caption": "Tilt shift photo of busy city street from the office window. Makes real world appear tiny."
  },
  "items": [
    {"label": "object", "caption": "A busy city street seen from the office window, with the tilt-shift effect making the real world appear tiny.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# 8C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "surreal", "macro", "dramatic lighting"],
    "canvas": "single",
    "caption": "The Explorer of the Ink Ocean. Surreal macro realism with dramatic lighting and fluid motion frozen in time."
  },
  "items": [
    {"label": "object", "caption": "A black ink spill spreading across a sketchbook page, becoming a vast ocean; ink waves curl like storm clouds while reflections of desk light shimmer across the liquid surface.", "bbox": [0.10, 0.0, 1.0, 1.0]},
    {"label": "character", "caption": "A miniature explorer sailing a tiny paper boat on the ink ocean.", "bbox": [0.45, 0.35, 0.70, 0.65]}
  ]
}
JSON
)" )

# 8D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro", "fantasy"],
    "canvas": "single",
    "caption": "A tiny fairy near the fire at the end of a match in a macro, shallow-focus scene. Lighting is intimate and diffused. Snow in the background dissolving into blur. Still, tender, and quietly whimsical."
  },
  "items": [
    {"label": "character", "caption": "A tiny fairy heating her hands on a fire. She appears fragile and doll-like, with a large head and soft translucent wings.", "bbox": [0.35, 0.15, 0.75, 0.45]},
    {"label": "object", "caption": "A small fire at the end of a match.", "bbox": [0.50, 0.40, 0.72, 0.58]},
    {"label": "object", "caption": "A woman's fingers holding the match, with black nail polish.", "bbox": [0.60, 0.50, 1.0, 0.95]},
    {"label": "object", "caption": "Snow in the background dissolving into blur.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# ── Row 9 · Complex Prompts ─────────────────────────────────────────────────

# 9A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["digital art", "illustration", "surreal", "extreme foreshortening"],
    "canvas": "single",
    "caption": "A digital art illustration with a strong visual impact. The image employs extreme foreshortening, with a very low and forward-extending perspective. The background is a deep, dark gray with subtle noise, which accentuates the brightness of the yellow lightning bolt symbol. The overall color scheme is dominated by bright yellow and deep, subdued colors, with extremely strong light and shadow contrasts, creating a surreal, urgent, and energetic atmosphere. The composition is compact and full of tension."
  },
  "items": [
    {"label": "object", "caption": "A gigantic hand with dark red pearl nail polish reaching out to the viewer, occupying most of the central space. The fingers, due to perspective, appear unusually thick and converge towards the camera. Light penetrates the outline of the fingers, causing the details of the hand to be obscured by the translucent light and shadow.", "bbox": [0.20, 0.15, 1.0, 0.85]},
    {"label": "object", "caption": "A large, backlit yellow plastic lightning bolt symbol ⚡ held in the hand; the most prominent object in the image, with a translucent texture, emitting a dazzling bright yellow light from within and creating a strong backlighting effect.", "bbox": [0.10, 0.30, 0.85, 0.70]},
    {"label": "character", "caption": "Behind the hand, the outline of a Caucasian woman's face with short red hair, vaguely visible and half-obscured by the lightning bolt symbol; only a slightly blurred profile and slightly parted lips are visible. She is gazing forward.", "bbox": [0.05, 0.30, 0.70, 0.80]}
  ]
}
JSON
)" )

# 9B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "sculpture", "studio"],
    "canvas": "single",
    "caption": "A dynamic sculpture of a dancing figure made from wide golden-yellow ribbons. Dark gradient background, professional studio lighting with dramatic side lighting highlighting the golden ribbons. Photorealistic style, high detail, elegant and ethereal atmosphere."
  },
  "items": [
    {"label": "object", "caption": "A dancing figure made from wide golden-yellow ribbons that wrap and swirl around forming a human silhouette in a graceful dance pose with arms outstretched. The ribbons are approximately 2-3 inches wide, creating intentional gaps and holes in the silhouette, revealing empty space inside. The figure appears mid-twirl with ribbons flowing outward dramatically.", "bbox": [0.05, 0.20, 0.95, 0.80]},
    {"label": "text", "caption": "Printed repeatedly along the length of the ribbons in bold black letters.", "text": "LIUTYI TEST V3", "bbox": [0.30, 0.30, 0.70, 0.70]}
  ]
}
JSON
)" )

# 9C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "surreal", "baroque"],
    "canvas": "single",
    "caption": "A silhouette of a woman standing perfectly still as an entire collapsing city spirals around her in slow rotation. The city fractures into surreal districts. The woman is the only still point in the chaos, her silhouette centered and grounded. The lighting is ghostly pale blue and deep crimson, baroque and melancholic."
  },
  "items": [
    {"label": "character", "caption": "A silhouette of a woman standing perfectly still, centered and grounded, the only still point in the chaos.", "bbox": [0.30, 0.40, 0.78, 0.60]},
    {"label": "object", "caption": "A marketplace suspended upside-down where merchants sell bottled shadows.", "bbox": [0.02, 0.02, 0.24, 0.32]},
    {"label": "object", "caption": "A bathhouse carved into a glacier with steam freezing mid-air.", "bbox": [0.26, 0.02, 0.48, 0.32]},
    {"label": "object", "caption": "A rooftop zoo where caged animals are made of smoke.", "bbox": [0.02, 0.68, 0.24, 0.98]},
    {"label": "object", "caption": "A hospital ward where the beds are boats drifting down white hallways.", "bbox": [0.50, 0.02, 0.72, 0.32]},
    {"label": "object", "caption": "A music conservatory where instruments play themselves in an empty auditorium.", "bbox": [0.26, 0.68, 0.48, 0.98]},
    {"label": "object", "caption": "A cinema where the screen shows the audience watching themselves.", "bbox": [0.50, 0.68, 0.72, 0.98]},
    {"label": "object", "caption": "A florist shop overgrown into a forest consuming its own walls.", "bbox": [0.74, 0.02, 0.96, 0.32]},
    {"label": "object", "caption": "A clock tower where time spills out like water.", "bbox": [0.0, 0.36, 0.30, 0.64]},
    {"label": "object", "caption": "A grand ballroom with a floor made of reflective black water beneath a chandelier of frozen flame.", "bbox": [0.74, 0.34, 1.0, 0.98]}
  ]
}
JSON
)" )

# 9D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cinematic", "pareidolia", "film grain"],
    "canvas": "single",
    "caption": "A cozy interior contrasted with a rainy evening outside. NO actual face, NO actual silhouette. NO horizontal lines. Just a pareidolia effect: seemingly random phenomena coincidentally align to form a subtle outline that, looked at closely, resembles a distorted woman's face in profile. Subtle, partial and extremely low contrast woman's face outlines, without solid lines or steam shadowing on the glass. No forced shadowing of a subtle silhouette outline. All lighting and shadows are related to real items, with no silhouette illusion. Moody atmospheric lighting, filmic grain, cinematic composition, melancholic mood."
  },
  "items": [
    {"label": "object", "caption": "A dark ceramic mug of hot tea steaming on a rustic wooden table by a window. One side of the steam curls from the mug and widens with height, creating the illusion of a nose.", "bbox": [0.55, 0.38, 0.85, 0.62]},
    {"label": "object", "caption": "An empty wooden chair to the left of the table.", "bbox": [0.45, 0.05, 0.90, 0.32]},
    {"label": "object", "caption": "A lit candle in a brass holder resting on the right side of the table.", "bbox": [0.55, 0.70, 0.85, 0.88]},
    {"label": "object", "caption": "A window pane with rain streaming down it, thick water droplets and vertical rivulets. Subtle, curved, mostly vertical thin rivulets create the illusion of hair.", "bbox": [0.0, 0.0, 0.55, 1.0]},
    {"label": "object", "caption": "Blurred orange and yellow evening city lights outside the window creating bokeh effects: red car taillights create the illusion of lips, street blue neon signs create the illusion of an eye, and a branch of a tree creates the illusion of a forehead.", "bbox": [0.05, 0.30, 0.55, 0.75]}
  ]
}
JSON
)" )

# ---- QUEUE JOBS ------------------------------------------------------------

for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
