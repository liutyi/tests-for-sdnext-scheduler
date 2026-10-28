#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/OpenMOSS-Team/MOSS-Image-SFT"' >&2
  exit 1
fi

# Prompts 5A and 5B render these values as text inside the image.
if [[ -z "${MODEL_LABEL:-}" || -z "${MODEL_PARAMS:-}" ]]; then
  echo "❌ MODEL_LABEL and/or MODEL_PARAMS is not set (used by prompts 5A and 5B). Export them, e.g.:" >&2
  echo '   export MODEL_LABEL="MOSS-Image" MODEL_PARAMS="16B (32GB)"' >&2
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

# Converts an authored layout into a final MOSS-Image layout prompt:
#  * bbox = [y_min, x_min, y_max, x_max] is authored as 0..1 fractions of the
#    canvas and converted to bbox_coord_space "abs_centralized" (pixels, origin
#    at canvas centre) for the WIDTH x HEIGHT being generated, bbox_format "yxyx";
#  * {{MODEL_LABEL}} {{MODEL_PARAMS}} {{STEPS}} {{CFG}} placeholders (prompts
#    5A / 5B) are replaced with the exported values (safe for quotes etc.).
# Output is compact JSON.
layout_to_prompt() {
  jq -c \
    --argjson w "$WIDTH" --argjson h "$HEIGHT" \
    --arg label "$MODEL_LABEL" --arg params "$MODEL_PARAMS" \
    --arg steps "$STEPS" --arg cfg "$CFG" '
    def cy: ((. * $h) - ($h / 2) | round);
    def cx: ((. * $w) - ($w / 2) | round);
    .items |= map(.bbox = [ (.bbox[0] | cy), (.bbox[1] | cx),
                            (.bbox[2] | cy), (.bbox[3] | cx) ])
    | (.. | strings) |= ( gsub("\\{\\{MODEL_LABEL\\}\\}";  $label)
                        | gsub("\\{\\{MODEL_PARAMS\\}\\}"; $params)
                        | gsub("\\{\\{STEPS\\}\\}";        $steps)
                        | gsub("\\{\\{CFG\\}\\}";          $cfg) )
    | . + { bbox_coord_space: "abs_centralized", bbox_format: "yxyx" }
  ' <<< "$1"
}

# Layout shared by the eight "solitary woman" art-style prompts (12A–13D).
# $1 = art style, appended to the caption exactly as in the original prompt.
art_style_layout() {
  jq -n --arg style "$1" '{
    summary: {
      meta: [$style],
      canvas: "single",
      caption: ("solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. " + $style + ".")
    },
    items: [
      {label: "character", caption: "A solitary woman figure watching the sunset over the ocean from a cliff.", bbox: [0.45, 0.10, 0.90, 0.35]},
      {label: "object", caption: "A cliff.", bbox: [0.60, 0.0, 1.0, 0.50]},
      {label: "object", caption: "A sunset over the ocean.", bbox: [0.0, 0.0, 0.70, 1.0]},
      {label: "object", caption: "A sailboat leaving.", bbox: [0.50, 0.65, 0.70, 0.85]}
    ]
  }'
}

queue_job() {
  local index="$1"
  local layout="$2"
  local negative="${3:-}"

  local prompt caption task_name
  prompt="$(layout_to_prompt "$layout")"
  caption="$(jq -r '.summary.caption' <<< "$prompt")"
  task_name="$(printf '%02d' "$index") ${caption:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${caption:0:120}"

  local json
  json=$(jq -n \
    --arg  prompt    "$prompt"    \
    --arg  negative  "$negative"  \
    --arg  sampler   "$SAMPLER"   \
    --arg  model     "$MODEL"     \
    --argjson steps   $STEPS      \
    --argjson cfg     $CFG        \
    --argjson ag      $AG         \
    --argjson w       $WIDTH      \
    --argjson h       $HEIGHT     \
    --argjson seed    $SEED       \
    '{
      sd_model_checkpoint: $model,
      checkpoint:           $model,
      prompt:          $prompt,
      negative_prompt: $negative,
      steps:           $steps,
      cfg_scale:       $cfg,
      pag_scale:       $ag,
      width:           $w,
      height:          $h,
      sampler_name:    $sampler,
      seed:            $seed,
      batch_size:      1,
      n_iter:          1,
      save_images:     true
    }')

  curl -s -X POST "$SCHED?name=$(urlencode "$task_name")" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null
}

# ---- PROMPTS ---------------------------------------------------------------
# Source: https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v1
# Structure: 12 rows (categories) × 4 columns (A–D) + 4 extra art style variants = 52 prompts
# Queued row-by-row: 1A 1B 1C 1D / 2A 2B … / 12A–12D / extra A–D
#
# Every prompt is a MOSS-Image layout prompt:
#   summary.caption  – overall scene and style
#   items[]          – label (text | character | object), caption, bbox,
#                      plus "text" (exact string to render) for text items
# bbox values are FRACTIONS (0..1) [y_min, x_min, y_max, x_max]; they are
# converted to abs_centralized pixels for your WIDTH/HEIGHT at queue time.
#
# Negative prompts are kept as plain text in a parallel negatives[] array
# (they are NOT converted to JSON). Empty string = no negative prompt.
#
# ⚠ PROMPTS 5A and 5B embed MODEL_LABEL, MODEL_PARAMS (and 5A also STEPS and
#   CFG) as text rendered in the image. Export MODEL_LABEL and MODEL_PARAMS
#   before running; the {{...}} placeholders are filled in automatically.
#
# Row 8C uses a danmaku-style positive (quality tags) and explicit negative —
# intended for fine-tuned anime models that respond to score_N tags.
# ---------------------------------------------------------------------------
prompts=()
negatives=()

# ── Row 1 · Photorealistic ──────────────────────────────────────────────────

# 1A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cinematic", "portrait"],
    "canvas": "single",
    "caption": "A cinematic portrait, wide side view shot of a woman seen through a New York taxi window on. Her face partially obscured by reflections and shadow. Shallow depth of field focuses softly on her curious eyes, while the foreground glass and background dissolve into blur."
  },
  "items": [
    {"label": "object", "caption": "A New York taxi window; the foreground glass dissolves into blur with reflections.", "bbox": [0.05, 0.05, 0.95, 0.95]},
    {"label": "character", "caption": "A woman seen from a wide side view, with a bob care haircut style and a black cocktail dress. Her face is partially obscured by reflections and shadow, and her curious eyes are softly in focus.", "bbox": [0.15, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "A part of a car's doors visible.", "bbox": [0.70, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 1B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cinematic", "retro", "analog film", "portrait"],
    "canvas": "single",
    "caption": "A cinematic retro analog portrait, wide side view shot of a woman seen through a vintage taxi car window on a New York street. Shallow depth of field focuses softly on her eyes, while the foreground glass and background dissolve into blur. Dramatic natural light filters through the window, creating organic patterns of light and shadow across her face, freckles and skin texture emphasized by directional sunlight. Warm, muted color palette with earthy browns, olive greens and soft golden highlights. Strong analog film character: visible grain, subtle color fading, low contrast, dust and micro scratches, gentle softness, slight vignetting. Emotional, introspective mood, quiet tension, cinematic stillness."
  },
  "items": [
    {"label": "object", "caption": "A vintage taxi car window on a New York street; the foreground glass dissolves into blur.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "character", "caption": "A woman on the passenger seat with red hair and a bob care haircut style, wearing a black cocktail dress. Her face is partially obscured by reflections and shadow, with freckles and skin texture emphasized.", "bbox": [0.15, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "Organic patterns of light and shadow from directional sunlight across her face.", "bbox": [0.20, 0.30, 0.65, 0.70]},
    {"label": "object", "caption": "A part of a car's doors visible.", "bbox": [0.70, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 1C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "macro", "high-key", "business"],
    "canvas": "single",
    "caption": "High-key macro close-up captures of a business scene, focusing sharply on a woman's right hand holding expensive pen slightly above the fine print agreement papers. The skin is rendered with soft, lifelike texture and subtle subsurface scattering, illuminated by warm, dappled sunlight from panoramic office windows. Shallow depth of field. Photorealistic."
  },
  "items": [
    {"label": "object", "caption": "A woman's right hand with soft lifelike skin texture. The nails are manicured in a glossy, pale pastel pink oval shape. On the ring finger, a thin gold ring with a small brilliant-cut diamond.", "bbox": [0.20, 0.30, 0.65, 0.80]},
    {"label": "object", "caption": "An expensive pen held slightly above the papers.", "bbox": [0.15, 0.35, 0.55, 0.60]},
    {"label": "object", "caption": "A taupe business blazer visible at the far right edge, from which the hand emerges.", "bbox": [0.40, 0.85, 1.0, 1.0]},
    {"label": "object", "caption": "Fine print agreement papers laying on the wooden office table.", "bbox": [0.55, 0.10, 0.95, 0.75]},
    {"label": "object", "caption": "A couple of metal clips on the table.", "bbox": [0.75, 0.05, 0.90, 0.25]},
    {"label": "object", "caption": "A slightly blurry cityscape behind the panoramic office window.", "bbox": [0.0, 0.0, 0.40, 1.0]}
  ]
}
JSON
)" )
negatives+=( "Low resolution, low image quality, distorted limbs and fingers, oversaturated image, wax figure appearance, lack of facial detail, excessive smoothing, AI-like appearance. Chaotic composition. Blurry and distorted text." )

# 1D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "corporate", "commercial"],
    "canvas": "single",
    "caption": "Ultra-realistic professional corporate photography, close-up shot of a woman's right hand signing a legal document on a polished wooden office desk. Shallow depth of field, modern executive office interior, soft daylight illumination, neutral business atmosphere, minimalistic office aesthetic. Photorealistic, 85mm lens look, f/1.8 depth of field, cinematic soft light, realistic shadows, high dynamic range, natural color grading, professional commercial photography style, clean composition, calm corporate mood."
  },
  "items": [
    {"label": "object", "caption": "A woman's right hand signing the document, with soft pink manicured nails, subtle natural skin texture, and a diamond solitaire ring with a gold band on the ring finger.", "bbox": [0.45, 0.30, 0.80, 0.70]},
    {"label": "object", "caption": "An elegant black fountain pen with gold accents held delicately between the fingers.", "bbox": [0.45, 0.35, 0.70, 0.55]},
    {"label": "object", "caption": "Crisp white paper with fine printed text.", "bbox": [0.60, 0.15, 0.95, 0.70]},
    {"label": "object", "caption": "Silver binder clips resting on the desk to the left.", "bbox": [0.75, 0.02, 0.90, 0.18]},
    {"label": "object", "caption": "A beige tailored blazer sleeve visible on the arm.", "bbox": [0.65, 0.60, 1.0, 0.95]},
    {"label": "object", "caption": "A polished wooden office desk.", "bbox": [0.55, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "A large floor-to-ceiling window in the background with a blurred city skyline and tall buildings outside.", "bbox": [0.0, 0.0, 0.40, 1.0]},
    {"label": "object", "caption": "A black leather office chair slightly out of focus.", "bbox": [0.15, 0.72, 0.55, 1.0]}
  ]
}
JSON
)" )
negatives+=( "cartoon, illustration, anime, over-stylized, exaggerated hands, extra fingers, deformed hands, low detail, blurry foreground, harsh lighting, oversaturated colors, text artifacts, watermark, logo, stock photo look, unreal skin" )

# ── Row 2 · Architecture ────────────────────────────────────────────────────

# 2A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "architecture"],
    "canvas": "single",
    "caption": "Oslo opera house"
  },
  "items": [
    {"label": "object", "caption": "The Oslo opera house.", "bbox": [0.20, 0.05, 0.85, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# 2B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cityscape", "night"],
    "canvas": "single",
    "caption": "Manhattan bridge with night New York cityscape on the background"
  },
  "items": [
    {"label": "object", "caption": "The Manhattan bridge.", "bbox": [0.25, 0.0, 0.85, 1.0]},
    {"label": "object", "caption": "The night New York cityscape in the background.", "bbox": [0.15, 0.0, 0.60, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 2C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "architecture", "low angle", "negative space"],
    "canvas": "single",
    "caption": "A futuristic circular pavilion on a distance, in a misty mountain landscape. Photo from a distance. Low angle shot. Large negative space."
  },
  "items": [
    {"label": "object", "caption": "A futuristic circular pavilion with some people and warm light inside, with panoramic windows, embedded into an edge of a steep cliff.", "bbox": [0.20, 0.55, 0.38, 0.85]},
    {"label": "object", "caption": "A steep cliff at whose edge the pavilion is embedded.", "bbox": [0.15, 0.45, 0.85, 1.0]},
    {"label": "object", "caption": "A curvy narrow concrete upward path and stairs going up to the pavilion.", "bbox": [0.40, 0.30, 1.0, 0.75]},
    {"label": "object", "caption": "A misty mountain landscape with large negative space.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 2D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "architecture", "brutalist", "low angle"],
    "canvas": "single",
    "caption": "Ultra-realistic architectural photography of a futuristic circular pavilion embedded into a steep, misty mountain landscape. Minimalist brutalist concrete textures, smooth curved geometry, organic integration with terrain. Dense fog and overcast sky, dramatic moody atmosphere, soft diffused light. Shot from a low angle along the path, strong leading lines, architectural composition. Hyper-detailed, photorealistic, 8k quality, global illumination, natural color grading, modern architectural magazine style."
  },
  "items": [
    {"label": "object", "caption": "A futuristic circular pavilion with a wide cantilevered concrete roof and floor, forming a floating ring, with full-height vertical glass panels glowing with warm amber interior light.", "bbox": [0.30, 0.30, 0.55, 0.85]},
    {"label": "character", "caption": "Interior silhouettes of a few people visible through the glass, a subtle human presence for scale.", "bbox": [0.38, 0.50, 0.50, 0.70]},
    {"label": "object", "caption": "A narrow winding concrete path with shallow steps leading uphill through lush, vivid green moss-covered hills toward the structure.", "bbox": [0.50, 0.10, 1.0, 0.80]},
    {"label": "object", "caption": "Dark rocky cliffs fading into mist in the background, with cinematic depth and scale.", "bbox": [0.0, 0.0, 0.50, 1.0]},
    {"label": "object", "caption": "Dense fog and an overcast sky.", "bbox": [0.0, 0.0, 0.25, 1.0]}
  ]
}
JSON
)" )
negatives+=( "low resolution, cartoon, anime, fantasy illustration, oversaturated colors, harsh sunlight, blue sky, flat lighting, cluttered environment, trees with leaves, city buildings, vehicles, text, logos, distortion, warped geometry, unrealistic proportions" )

# ── Row 3 · Interior ────────────────────────────────────────────────────────

# 3A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "interior"],
    "canvas": "single",
    "caption": "Charcoal Blue kitchen"
  },
  "items": [
    {"label": "object", "caption": "A charcoal blue kitchen.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 3B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["interior design", "art nouveau"],
    "canvas": "single",
    "caption": "art nouveau interior design that incorporate nature-inspired motifs and includes glamour metallic elements, jewel tones and decorative furniture"
  },
  "items": [
    {"label": "object", "caption": "An art nouveau interior with nature-inspired motifs, glamour metallic elements and jewel tones.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "Decorative furniture.", "bbox": [0.45, 0.10, 0.95, 0.90]}
  ]
}
JSON
)" )
negatives+=( "" )

# 3C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "interior"],
    "canvas": "single",
    "caption": "loft bedroom with panoramic window"
  },
  "items": [
    {"label": "object", "caption": "A panoramic window in a loft bedroom.", "bbox": [0.05, 0.0, 0.65, 1.0]},
    {"label": "object", "caption": "A bed in a loft bedroom.", "bbox": [0.55, 0.15, 0.95, 0.70]}
  ]
}
JSON
)" )
negatives+=( "" )

# 3D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["interior design", "futuristic"],
    "canvas": "single",
    "caption": "futuristic interior design living room"
  },
  "items": [
    {"label": "object", "caption": "A futuristic interior design living room.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 4 · Nature ──────────────────────────────────────────────────────────

# 4A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "underwater"],
    "canvas": "single",
    "caption": "whale surrounded by fishes underwater photo"
  },
  "items": [
    {"label": "object", "caption": "A whale underwater.", "bbox": [0.25, 0.15, 0.75, 0.85]},
    {"label": "object", "caption": "Fishes surrounding the whale.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 4B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["landscape"],
    "canvas": "single",
    "caption": "mountains and foggy valleys"
  },
  "items": [
    {"label": "object", "caption": "Mountains.", "bbox": [0.10, 0.0, 0.65, 1.0]},
    {"label": "object", "caption": "Foggy valleys.", "bbox": [0.50, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 4C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro", "autumn"],
    "canvas": "single",
    "caption": "Golden Maple Leaves In Autumn Sunlight With Delicate Details"
  },
  "items": [
    {"label": "object", "caption": "Golden maple leaves in autumn sunlight with delicate details.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 4D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["landscape", "fantasy realism", "HDR", "high saturation"],
    "canvas": "single",
    "caption": "Ultra-vibrant tropical waterfall cascading from lush jungle cliffs into a crystal-clear turquoise lagoon, surrounded by dense rainforest foliage in neon greens, emeralds, and deep teals. Sunlight pierces through misty air, creating glowing god rays and subtle rainbow refractions in the waterfall spray. Cinematic wide-angle composition, strong depth, high saturation, HDR lighting, extreme clarity, sharp focus, fantasy-realism style, breathtaking postcard aesthetic, ultra high resolution, masterpiece quality."
  },
  "items": [
    {"label": "object", "caption": "A tropical waterfall cascading from lush jungle cliffs, with hyper-detailed water motion, silky waterfall flow, and dynamic splashes and foam.", "bbox": [0.05, 0.30, 0.65, 0.70]},
    {"label": "object", "caption": "A crystal-clear turquoise lagoon.", "bbox": [0.60, 0.10, 1.0, 0.90]},
    {"label": "object", "caption": "Misty air with glowing god rays and subtle rainbow refractions in the waterfall spray.", "bbox": [0.0, 0.20, 0.60, 0.80]},
    {"label": "object", "caption": "Dense rainforest foliage in neon greens, emeralds, and deep teals, with exotic tropical plants with oversized leaves, framing the left of the scene.", "bbox": [0.20, 0.0, 0.95, 0.30]},
    {"label": "object", "caption": "Bright flowers in magenta, orange, and yellow among oversized leaves, framing the right of the scene.", "bbox": [0.20, 0.72, 0.95, 1.0]}
  ]
}
JSON
)" )
negatives+=( "dull colors, low saturation, flat lighting, overexposed highlights, muddy water, foggy blur, washed-out tones, people, animals, buildings, text, watermark, logo, artifacts, low resolution, noise" )

# ── Row 5 · Text ────────────────────────────────────────────────────────────
# ⚠ 5A and 5B use MODEL_LABEL / MODEL_PARAMS (and STEPS / CFG) from the environment.

# 5A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "urban", "chalkboard"],
    "canvas": "single",
    "caption": "Urban exterior setting. A-frame chalkboard sign on cobblestone street with chalk writing."
  },
  "items": [
    {"label": "object", "caption": "An A-frame chalkboard sign on a cobblestone street.", "bbox": [0.10, 0.20, 0.95, 0.80]},
    {"label": "text", "caption": "The title, written in yellow color chalk.", "text": "{{MODEL_LABEL}}", "bbox": [0.18, 0.28, 0.30, 0.72]},
    {"label": "text", "caption": "The next line, an orange chalk drawing.", "text": "⭐⭐⭐", "bbox": [0.32, 0.35, 0.42, 0.65]},
    {"label": "text", "caption": "The next lines, in white chalk for smaller text.", "text": "- {{MODEL_PARAMS}}  - steps {{STEPS}} - guidance {{CFG}}", "bbox": [0.46, 0.28, 0.70, 0.72]},
    {"label": "object", "caption": "A cobblestone street.", "bbox": [0.80, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 5B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "urban", "graffiti"],
    "canvas": "single",
    "caption": "Bright graffiti on mirror glass wall of skyscraper. Graffiti background resemble simplified cat face. Dark grey asphalt on a sidewalk below."
  },
  "items": [
    {"label": "object", "caption": "The mirror glass wall of a skyscraper.", "bbox": [0.0, 0.0, 0.80, 1.0]},
    {"label": "object", "caption": "Graffiti background resembling a simplified cat face.", "bbox": [0.25, 0.15, 0.65, 0.85]},
    {"label": "text", "caption": "Bright graffiti lettering on the mirror glass wall.", "text": "{{MODEL_LABEL}}", "bbox": [0.30, 0.20, 0.60, 0.80]},
    {"label": "text", "caption": "A large building number sign on the top left corner above the graffiti.", "text": "{{MODEL_PARAMS}}", "bbox": [0.10, 0.05, 0.20, 0.30]},
    {"label": "character", "caption": "An 8yo boy cyclist riding in front of the building.", "bbox": [0.60, 0.40, 0.92, 0.70]},
    {"label": "object", "caption": "Dark grey asphalt on a sidewalk below.", "bbox": [0.80, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 5C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "book"],
    "canvas": "single",
    "caption": "Book Alice's Adventures in Wonderland by Lewis Carroll is opened on CHAPTER VII. Left page is relevant illustration and right page is text."
  },
  "items": [
    {"label": "object", "caption": "The book Alice's Adventures in Wonderland by Lewis Carroll, opened on CHAPTER VII.", "bbox": [0.05, 0.03, 0.97, 0.97]},
    {"label": "object", "caption": "The left page: a relevant illustration.", "bbox": [0.10, 0.05, 0.90, 0.48]},
    {"label": "text", "caption": "The right page: the text of the page.", "text": "CHAPTER VII. A Mad Tea-Party There was a table set out under a tree in front of the house, and the March Hare and the Hatter were having tea at it: a Dormouse was sitting between them, fast asleep, and the other two were using it as a cushion, resting their elbows on it, and talking over its head. \"Very uncomfortable for the Dormouse,\" thought Alice; \"only, as it's asleep, I suppose it doesn't mind.\" The table was a large one, but the three were all crowded together at one corner of it: \"No room! No room!\" they cried out when they saw Alice coming. \"There's plenty of room!\" said Alice indignantly, and she sat down in a large arm-chair at one end of the table. \"Have some wine,\" the March Hare said in an encouraging tone. Alice looked all round the table, but there was nothing on it but tea. \"I don't see any wine,\" she remarked. \"There isn't any,\" said the March Hare. \"Then it wasn't very civil of you to offer it,\" said Alice angrily. \"It wasn't very civil of you to sit down without being invited,\" said the March Hare. \"I didn't know it was your table,\" said Alice; \"it's laid for a great many more than three.\" \"Your hair wants cutting,\" said the Hatter. He had been looking at Alice for some time with great curiosity, and this was his first speech.", "bbox": [0.10, 0.52, 0.90, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# 5D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["meme", "three-panel", "photograph"],
    "canvas": "single",
    "caption": "High-resolution three-panel meme recreation, clean modern meme style. Straight panel borders, equal spacing, perfect alignment, ultra-sharp 4K quality, no blur, no pose ambiguity, faithful meme recreation."
  },
  "items": [
    {"label": "object", "caption": "TOP PANEL, strict typography constraints: two identical wooden house-shaped decorations placed side by side, equal size, perfectly aligned, each with a rustic wooden roof above it, realistic wood grain, black bold block letters, on a white retail shelf with neutral store lighting, sharp focus. Each decoration contains text in exactly two lines only; do not spell HOME horizontally. Reading each decoration vertically is HOME and HOME; reading across decorations by rows is HO HO and ME ME.", "bbox": [0.0, 0.0, 0.48, 1.0]},
    {"label": "text", "caption": "Text on the first house-shaped decoration, exactly two lines: line 1 at the top, line 2 at the bottom.", "text": "HO\nME", "bbox": [0.10, 0.12, 0.40, 0.45]},
    {"label": "text", "caption": "Text on the second house-shaped decoration, exactly two lines: line 1 at the top, line 2 at the bottom.", "text": "HO\nME", "bbox": [0.10, 0.55, 0.40, 0.88]},
    {"label": "character", "caption": "BOTTOM LEFT PANEL, original meme pose required: two women seated at a dinner table. In the foreground, a blonde woman angrily shouting and pointing forward. Behind her, a second woman leaning in, holding the shouting woman by placing one hand firmly on her shoulder, expression tense and supportive, as if restraining or backing her up. Clear physical contact is visible and intentional. Dramatic reality-TV lighting and expressions.", "bbox": [0.50, 0.0, 1.0, 0.49]},
    {"label": "text", "caption": "Bold white Impact-style meme caption with black outline, bottom left panel.", "text": "HOME HOME", "bbox": [0.88, 0.04, 0.98, 0.45]},
    {"label": "character", "caption": "BOTTOM RIGHT PANEL: a white cat sitting at a table, with a judgmental and confused expression, mouth slightly open, iconic meme framing.", "bbox": [0.50, 0.51, 1.0, 1.0]},
    {"label": "text", "caption": "Bold white Impact-style meme caption with black outline, bottom right panel.", "text": "HOHO MEME", "bbox": [0.88, 0.55, 0.98, 0.97]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 6 · Comics ──────────────────────────────────────────────────────────

# 6A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["comic", "illustration"],
    "canvas": "single",
    "caption": "Iron man comics"
  },
  "items": [
    {"label": "character", "caption": "Iron Man in a comics illustration style.", "bbox": [0.05, 0.15, 0.95, 0.85]}
  ]
}
JSON
)" )
negatives+=( "" )

# 6B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["meme", "comic"],
    "canvas": "single",
    "caption": "3 spider man pointing meme"
  },
  "items": [
    {"label": "character", "caption": "The left Spider-Man, pointing at the others.", "bbox": [0.30, 0.05, 0.95, 0.38]},
    {"label": "character", "caption": "The center Spider-Man, pointing at the others.", "bbox": [0.25, 0.33, 0.95, 0.67]},
    {"label": "character", "caption": "The right Spider-Man, pointing at the others.", "bbox": [0.30, 0.62, 0.95, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# 6C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cartoon", "cel animation", "vintage", "meme"],
    "canvas": "single",
    "caption": "Three identical Spider-Man characters stand indoors, all pointing at each other simultaneously in a perfect triangular standoff, in an interior warehouse/garage space. 1960s–1970s American cartoon cel animation still, hand-drawn look, flat colors, thick black outlines, minimal shading, slightly off-model anatomy, vintage TV animation aesthetic. Mid-wide shot, straight-on eye-level camera, all three characters fully visible, equal scale, meme-accurate spacing, no dramatic perspective. Faded retro palette, soft edges, mild film grain, no modern lighting, no realism, no depth of field. All three Spider-Men must look identical. Finger pointing must be precisely aligned toward each other. Background elements must stay flat and simple."
  },
  "items": [
    {"label": "character", "caption": "Left Spider-Man: foreground left, body angled right, right arm fully extended pointing toward center.", "bbox": [0.30, 0.05, 0.98, 0.38]},
    {"label": "character", "caption": "Center Spider-Man: slightly farther back, centered, legs apart, torso forward, both arms extended, pointing left and right.", "bbox": [0.25, 0.33, 0.90, 0.67]},
    {"label": "character", "caption": "Right Spider-Man: foreground right, body angled left, left arm extended pointing toward center.", "bbox": [0.30, 0.62, 0.98, 0.95]},
    {"label": "object", "caption": "Left background: a white NYPD police van, side view partially visible, parked indoors, simple blocky shape, blue stripe.", "bbox": [0.20, 0.0, 0.55, 0.35]},
    {"label": "text", "caption": "Subtle NYPD style markings on the van, cartoon-simplified, not realistic.", "text": "NYPD", "bbox": [0.30, 0.10, 0.38, 0.28]},
    {"label": "object", "caption": "Back wall: a flat muted pink / salmon-colored wall, solid color, no texture.", "bbox": [0.0, 0.0, 0.65, 1.0]},
    {"label": "object", "caption": "Floor: flat blue-gray concrete.", "bbox": [0.65, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "Right side: stacked wooden crates, simple box shapes.", "bbox": [0.45, 0.78, 0.80, 1.0]}
  ]
}
JSON
)" )
negatives+=( "photorealism, modern Spider-Man suit, MCU style, 3D render, cinematic lighting, dramatic shadows, blur, depth of field, extra limbs, extra fingers, incorrect pointing, asymmetry, cropped bodies, text, logos, realism" )

# 6D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["comic", "illustration", "3-panel"],
    "canvas": "single",
    "caption": "3-panel comic strip set in the DC Universe. Style: Bright, comic-book illustration reminiscent of DC Comics, bold outlines, vibrant colors, dynamic angles. Include word balloons with clear, readable comic font. Keep the humor lighthearted and on-brand for DC's tone."
  },
  "items": [
    {"label": "character", "caption": "Panel 1: Superman stands heroically on a rooftop at sunset, fists on hips, wearing his classic red and blue suit with the \"S\" emblem. Raising one eyebrow with a skeptical but amused expression.", "bbox": [0.02, 0.02, 0.98, 0.18]},
    {"label": "character", "caption": "Panel 1: Lois Lane stands nearby, wearing a professional reporter outfit, blazer, blouse, pencil skirt, looking confident but slightly confused. Lois touch her lips with a tip of a pen in her hand.", "bbox": [0.20, 0.18, 0.98, 0.32]},
    {"label": "character", "caption": "Panel 2: Superman looking in the Lois eyes. Lois Lane and Superman glancing at each other in a moment of silence.", "bbox": [0.05, 0.35, 0.98, 0.65]},
    {"label": "text", "caption": "Panel 2: Superman speech bubble.", "text": "Why did I bring a pencil to the fight?", "bbox": [0.04, 0.36, 0.20, 0.65]},
    {"label": "character", "caption": "Panel 3: Close-up of Lois Lane grinning proudly. She winks and holds up the pencil like a mic drop moment.", "bbox": [0.05, 0.68, 0.98, 0.98]},
    {"label": "character", "caption": "Panel 3: Superman facepalms in the background, smiling despite himself.", "bbox": [0.35, 0.80, 0.98, 0.98]},
    {"label": "text", "caption": "Panel 3: Lois speech bubble.", "text": "In case you needed to draw some attention!", "bbox": [0.04, 0.69, 0.20, 0.98]}
  ]
}
JSON
)" )
negatives+=( "photorealistic, grimdark horror, blurry text, extra panels, messy composition" )

# ── Row 7 · Celebrities ─────────────────────────────────────────────────────

# 7A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph"],
    "canvas": "single",
    "caption": "Barack Obama mic drop"
  },
  "items": [
    {"label": "character", "caption": "Barack Obama doing a mic drop.", "bbox": [0.05, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "A microphone being dropped.", "bbox": [0.45, 0.55, 0.85, 0.75]}
  ]
}
JSON
)" )
negatives+=( "" )

# 7B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["film still", "action"],
    "canvas": "single",
    "caption": "Arnold Schwarzenegger on a motorcycle in Terminator 2 movie"
  },
  "items": [
    {"label": "character", "caption": "Arnold Schwarzenegger riding a motorcycle, as in the Terminator 2 movie.", "bbox": [0.15, 0.20, 0.90, 0.80]},
    {"label": "object", "caption": "A motorcycle.", "bbox": [0.45, 0.10, 1.0, 0.90]}
  ]
}
JSON
)" )
negatives+=( "" )

# 7C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["grid", "illustration"],
    "canvas": "single",
    "caption": "Marvel Avengers Characters Grid"
  },
  "items": [
    {"label": "object", "caption": "A grid of Marvel Avengers characters.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 7D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["grid", "portrait", "cinematic", "photorealistic"],
    "canvas": "single",
    "caption": "Marvel Avengers character grid, 3x3 layout, each cell featuring a different iconic superhero portrait. Front-facing or slight three-quarter view, consistent framing and scale, cinematic studio lighting, ultra-detailed faces and costumes, realistic textures, sharp focus. Clean neutral background per cell with subtle color variation matching each character's theme. High contrast, polished blockbuster look, symmetrical composition, modern Marvel cinematic style, ultra-high resolution, crisp edges, no text."
  },
  "items": [
    {"label": "character", "caption": "Top row, left cell: an Iron Man portrait.", "bbox": [0.0, 0.0, 0.33, 0.33]},
    {"label": "character", "caption": "Top row, middle cell: a Captain America portrait.", "bbox": [0.0, 0.335, 0.33, 0.665]},
    {"label": "character", "caption": "Top row, right cell: a Thor portrait.", "bbox": [0.0, 0.67, 0.33, 1.0]},
    {"label": "character", "caption": "Middle row, left cell: a Hulk portrait.", "bbox": [0.335, 0.0, 0.665, 0.33]},
    {"label": "character", "caption": "Middle row, middle cell: a Black Widow portrait.", "bbox": [0.335, 0.335, 0.665, 0.665]},
    {"label": "character", "caption": "Middle row, right cell: a Hawkeye portrait.", "bbox": [0.335, 0.67, 0.665, 1.0]},
    {"label": "character", "caption": "Bottom row, left cell: a Spider-Man portrait.", "bbox": [0.67, 0.0, 1.0, 0.33]},
    {"label": "character", "caption": "Bottom row, middle cell: a Doctor Strange portrait.", "bbox": [0.67, 0.335, 1.0, 0.665]},
    {"label": "character", "caption": "Bottom row, right cell: a Black Panther portrait.", "bbox": [0.67, 0.67, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "low resolution, blurry, deformed face, extra limbs, incorrect anatomy, inconsistent proportions, oversaturated colors, cartoon, anime, painterly, text, logos, watermark, cropped heads, duplicate characters" )

# ── Row 8 · Anime ───────────────────────────────────────────────────────────

# 8A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["anime", "illustration"],
    "canvas": "single",
    "caption": "Naruto vs Sasuke final battle"
  },
  "items": [
    {"label": "character", "caption": "Naruto, in the final battle.", "bbox": [0.15, 0.05, 0.85, 0.45]},
    {"label": "character", "caption": "Sasuke, in the final battle.", "bbox": [0.15, 0.55, 0.85, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# 8B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["anime", "illustration", "hand-drawn", "action"],
    "canvas": "single",
    "caption": "Epic anime final battle scene, Naruto Uzumaki vs Sasuke Uchiha facing each other mid-air, frozen at the moment before impact. Ultra-dynamic action pose, extreme motion blur on energy trails, cinematic wide shot, anime masterpiece, hand-drawn style, sharp lineart, rich saturated colors, high contrast lighting, ultra-detailed, 8k anime illustration."
  },
  "items": [
    {"label": "character", "caption": "Naruto Uzumaki mid-air, glowing with intense golden Kurama chakra, with swirling energy tails and cracked earth beneath him.", "bbox": [0.20, 0.05, 0.85, 0.45]},
    {"label": "character", "caption": "Sasuke Uchiha mid-air, enveloped in a dark purple Susanoo aura with crackling lightning and a glowing Rinnegan eye.", "bbox": [0.20, 0.55, 0.85, 0.95]},
    {"label": "object", "caption": "A massive Rasengan colliding with Chidori at the center.", "bbox": [0.35, 0.40, 0.65, 0.60]},
    {"label": "object", "caption": "An explosive energy shockwave tearing the valley apart, with shattered rocks suspended in the air, and rain and dust particles illuminated by energy.", "bbox": [0.55, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "Dramatic storm clouds overhead, split by blinding light.", "bbox": [0.0, 0.0, 0.30, 1.0]}
  ]
}
JSON
)" )
negatives+=( "low detail, blurry, extra limbs, bad anatomy, distorted faces, flat lighting, dull colors, cropped characters, watermark, text, logo" )

# 8C — danmaku quality tags (intended for fine-tuned anime models)
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["anime", "tags"],
    "canvas": "single",
    "caption": "score_9, score_8_up, score_7_up, source_anime, 1girl"
  },
  "items": [
    {"label": "character", "caption": "1girl.", "bbox": [0.05, 0.20, 0.95, 0.80]}
  ]
}
JSON
)" )
negatives+=( "score_1, score_2, score_3, worst quality, bad quality, jpeg artifacts, source_cartoon, 3d, monochrome, blurry, lowres, text, watermark" )

# 8D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["anime", "ghibli", "tags"],
    "canvas": "single",
    "caption": "anime, ghibli, 1girl, cat, bus, Tokyo, street"
  },
  "items": [
    {"label": "character", "caption": "1girl.", "bbox": [0.35, 0.15, 0.95, 0.45]},
    {"label": "object", "caption": "A cat.", "bbox": [0.65, 0.45, 0.90, 0.65]},
    {"label": "object", "caption": "A bus.", "bbox": [0.35, 0.55, 0.80, 0.98]},
    {"label": "object", "caption": "A Tokyo street.", "bbox": [0.60, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 9 · Illustrations ───────────────────────────────────────────────────

# 9A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "book cover"],
    "canvas": "single",
    "caption": "Fence painting illustration for \"The Adventures of Tom Sawyer\" book cover."
  },
  "items": [
    {"label": "object", "caption": "A fence painting scene, illustrated for the book cover of The Adventures of Tom Sawyer.", "bbox": [0.10, 0.0, 0.95, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 9B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "educational", "textbook", "vector"],
    "canvas": "single",
    "caption": "Highly detailed, educational illustration of the Solar System, textbook style, labeled planets orbiting the Sun, realistic planetary textures, correct relative sizes and positions, clear orbit paths, annotated with planet names, scientific style, clean vector-like lines, bright but natural colors, easy-to-read labels, high clarity and contrast, front view layout, diagrammatic yet visually appealing, suitable for children and students, no artistic exaggeration, neutral lighting, crisp and precise."
  },
  "items": [
    {"label": "object", "caption": "The Sun with labeled planets orbiting it, with realistic planetary textures, correct relative sizes and positions, and easy-to-read planet name labels.", "bbox": [0.05, 0.05, 0.95, 0.95]},
    {"label": "object", "caption": "Clear orbit paths.", "bbox": [0.05, 0.05, 0.95, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# 9C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["diagram", "educational", "textbook", "vector"],
    "canvas": "single",
    "caption": "Educational diagram of the Solar System in textbook style, front/orthographic view, all planets labeled and positioned in orbit around the Sun, accurate relative sizes for illustration purposes, labeled clearly with planet names, each planet placed from left to right as Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune. Lighting: neutral and even, minimal shadows, diagrammatic style. Style: realistic planetary textures but simplified for textbook clarity, vector-diagram-like, scientific and educational, no artistic exaggeration, all planets in a single line orbit for clarity."
  },
  "items": [
    {"label": "object", "caption": "Background: dark space with faint stars and subtle grid lines for scale. Orbit paths: subtle thin circular lines behind each planet, evenly spaced, labeled with orbital numbers or distances if possible.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "Sun: a large yellow-orange sphere on the left.", "bbox": [0.41, 0.0, 0.59, 0.18]},
    {"label": "text", "caption": "Label above the Sun, clear white easy-to-read font.", "text": "Sun", "bbox": [0.34, 0.04, 0.40, 0.14]},
    {"label": "object", "caption": "Mercury: the smallest planet, gray, closest to the Sun.", "bbox": [0.485, 0.20, 0.515, 0.23]},
    {"label": "text", "caption": "Label above Mercury, clear white easy-to-read font.", "text": "Mercury", "bbox": [0.36, 0.18, 0.42, 0.25]},
    {"label": "object", "caption": "Venus: slightly larger, pale yellow, second from the Sun.", "bbox": [0.48, 0.27, 0.52, 0.31]},
    {"label": "text", "caption": "Label above Venus, clear white easy-to-read font.", "text": "Venus", "bbox": [0.36, 0.255, 0.42, 0.325]},
    {"label": "object", "caption": "Earth: blue-green with white clouds, third from the Sun.", "bbox": [0.48, 0.35, 0.52, 0.39]},
    {"label": "text", "caption": "Label above Earth, clear white easy-to-read font.", "text": "Earth", "bbox": [0.36, 0.335, 0.42, 0.405]},
    {"label": "object", "caption": "Mars: a small red planet, fourth from the Sun.", "bbox": [0.485, 0.43, 0.515, 0.46]},
    {"label": "text", "caption": "Label above Mars, clear white easy-to-read font.", "text": "Mars", "bbox": [0.36, 0.41, 0.42, 0.48]},
    {"label": "object", "caption": "Jupiter: the largest planet, with brown-orange stripes, fifth from the Sun.", "bbox": [0.44, 0.50, 0.56, 0.62]},
    {"label": "text", "caption": "Label above Jupiter, clear white easy-to-read font.", "text": "Jupiter", "bbox": [0.36, 0.52, 0.42, 0.60]},
    {"label": "object", "caption": "Saturn: large yellow-gold with wide rings, sixth from the Sun.", "bbox": [0.435, 0.66, 0.565, 0.79]},
    {"label": "text", "caption": "Label above Saturn, clear white easy-to-read font.", "text": "Saturn", "bbox": [0.36, 0.68, 0.42, 0.77]},
    {"label": "object", "caption": "Uranus: light blue-green, seventh from the Sun.", "bbox": [0.47, 0.83, 0.53, 0.89]},
    {"label": "text", "caption": "Label above Uranus, clear white easy-to-read font.", "text": "Uranus", "bbox": [0.36, 0.82, 0.42, 0.90]},
    {"label": "object", "caption": "Neptune: deep blue, eighth from the Sun.", "bbox": [0.47, 0.93, 0.53, 0.99]},
    {"label": "text", "caption": "Label above Neptune, clear white easy-to-read font.", "text": "Neptune", "bbox": [0.36, 0.925, 0.42, 0.995]}
  ]
}
JSON
)" )
negatives+=( "" )

# 9D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["architectural drawing", "floor plan"],
    "canvas": "single",
    "caption": "apartment plan drawing. 120 square meters, 1 living room, 2 bathrooms, 2 bedroom, kitchen, balcony"
  },
  "items": [
    {"label": "object", "caption": "The living room of a 120 square meters apartment plan.", "bbox": [0.05, 0.05, 0.50, 0.55]},
    {"label": "object", "caption": "The kitchen.", "bbox": [0.05, 0.57, 0.40, 0.95]},
    {"label": "object", "caption": "The first bedroom.", "bbox": [0.55, 0.05, 0.95, 0.32]},
    {"label": "object", "caption": "The second bedroom.", "bbox": [0.55, 0.34, 0.95, 0.60]},
    {"label": "object", "caption": "The first bathroom.", "bbox": [0.45, 0.62, 0.70, 0.80]},
    {"label": "object", "caption": "The second bathroom.", "bbox": [0.45, 0.82, 0.70, 0.95]},
    {"label": "object", "caption": "The balcony.", "bbox": [0.75, 0.62, 0.95, 0.95]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 10 · Materials ──────────────────────────────────────────────────────

# 10A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["clay", "craft"],
    "canvas": "single",
    "caption": "Clay-crafted girl is playing with the clay cat."
  },
  "items": [
    {"label": "character", "caption": "A clay-crafted girl playing with the clay cat.", "bbox": [0.15, 0.15, 0.95, 0.60]},
    {"label": "object", "caption": "A clay cat.", "bbox": [0.50, 0.55, 0.90, 0.90]}
  ]
}
JSON
)" )
negatives+=( "" )

# 10B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["knitting", "craft", "textile"],
    "canvas": "single",
    "caption": "Knitting of the phoenix on the white fabric. With stitched text \"Phoenix\" below."
  },
  "items": [
    {"label": "object", "caption": "A knitting of the phoenix on white fabric.", "bbox": [0.05, 0.10, 0.78, 0.90]},
    {"label": "text", "caption": "Stitched text below the phoenix.", "text": "Phoenix", "bbox": [0.82, 0.30, 0.95, 0.70]}
  ]
}
JSON
)" )
negatives+=( "" )

# 10C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["sculpture", "marble"],
    "canvas": "single",
    "caption": "Marble cat figure"
  },
  "items": [
    {"label": "object", "caption": "A marble cat figure.", "bbox": [0.10, 0.15, 0.95, 0.85]}
  ]
}
JSON
)" )
negatives+=( "" )

# 10D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["sculpture", "ice"],
    "canvas": "single",
    "caption": "Ice sculpture of a man in a hat"
  },
  "items": [
    {"label": "object", "caption": "An ice sculpture of a man in a hat.", "bbox": [0.05, 0.20, 0.95, 0.80]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 11 · Abstract Art ───────────────────────────────────────────────────

# 11A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["abstract art"],
    "canvas": "single",
    "caption": "abstract art"
  },
  "items": [
    {"label": "object", "caption": "An abstract art composition filling the whole canvas.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 11B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["abstract art", "wallpaper"],
    "canvas": "single",
    "caption": "abstract art wallpaper. gold on sepia. masterpiece."
  },
  "items": [
    {"label": "object", "caption": "An abstract art wallpaper in gold on sepia, a masterpiece.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# 11C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["abstract art", "wallpaper"],
    "canvas": "single",
    "caption": "abstract art wallpaper. gold color splash on dark grayscale. masterpiece."
  },
  "items": [
    {"label": "object", "caption": "A dark grayscale abstract art background.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "A gold color splash.", "bbox": [0.20, 0.20, 0.80, 0.80]}
  ]
}
JSON
)" )
negatives+=( "" )

# 11D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["abstract art", "wallpaper"],
    "canvas": "single",
    "caption": "abstract art wallpaper. city theme. masterpiece."
  },
  "items": [
    {"label": "object", "caption": "An abstract art wallpaper with a city theme, a masterpiece.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
negatives+=( "" )

# ── Row 12 · Art Styles (first four) ────────────────────────────────────────

# 12A
prompts+=( "$(art_style_layout "Pop art")" )
negatives+=( "" )

# 12B
prompts+=( "$(art_style_layout "Shin-hanga Art")" )
negatives+=( "" )

# 12C
prompts+=( "$(art_style_layout "Futurism Art")" )
negatives+=( "" )

# 12D
prompts+=( "$(art_style_layout "ASCII Art")" )
negatives+=( "" )

# ── Row 12 · Art Styles (extra four — unnumbered in source) ─────────────────

# 13A (extra)
prompts+=( "$(art_style_layout "cubism art")" )
negatives+=( "" )

# 13B (extra)
prompts+=( "$(art_style_layout "expressionist art")" )
negatives+=( "" )

# 13C (extra)
prompts+=( "$(art_style_layout "Hokusai art")" )
negatives+=( "" )

# 13D (extra)
prompts+=( "$(art_style_layout "Salvador Dali art")" )
negatives+=( "" )

# ---- QUEUE JOBS ------------------------------------------------------------
if [[ ${#prompts[@]} -ne ${#negatives[@]} ]]; then
  echo "❌ prompts[] and negatives[] length mismatch — fix the script." >&2
  exit 1
fi

for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}" "${negatives[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
