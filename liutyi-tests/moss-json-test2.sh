#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/OpenMOSS-Team/MOSS-Image-SFT"' >&2
  exit 1
fi

# Prompt 9A embeds these two values (as text rendered inside the image).
if [[ -z "${MODEL_LABEL:-}" || -z "${MODEL_COMPANY:-}" ]]; then
  echo "❌ MODEL_LABEL and/or MODEL_COMPANY is not set (used by prompt 9A). Export them, e.g.:" >&2
  echo '   export MODEL_LABEL="MOSS-Image" MODEL_COMPANY="OpenMOSS"' >&2
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
#  * {{MODEL_COMPANY}} / {{MODEL_LABEL}} placeholders (prompt 9A) are replaced
#    with the exported values (safe for quotes and special characters).
# Output is compact JSON.
layout_to_prompt() {
  jq -c \
    --argjson w "$WIDTH" --argjson h "$HEIGHT" \
    --arg company "$MODEL_COMPANY" --arg label "$MODEL_LABEL" '
    def cy: ((. * $h) - ($h / 2) | round);
    def cx: ((. * $w) - ($w / 2) | round);
    .items |= map(.bbox = [ (.bbox[0] | cy), (.bbox[1] | cx),
                            (.bbox[2] | cy), (.bbox[3] | cx) ])
    | (.. | strings) |= ( gsub("\\{\\{MODEL_COMPANY\\}\\}"; $company)
                        | gsub("\\{\\{MODEL_LABEL\\}\\}";   $label) )
    | . + { bbox_coord_space: "abs_centralized", bbox_format: "yxyx" }
  ' <<< "$1"
}

queue_job() {
  local index="$1"
  local layout="$2"

  local prompt caption task_name
  prompt="$(layout_to_prompt "$layout")"
  caption="$(jq -r '.summary.caption' <<< "$prompt")"
  task_name="$(printf '%02d' "$index") ${caption:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${caption:0:120}"

  local json
  json=$(jq -n \
    --arg  prompt   "$prompt"   \
    --arg  sampler  "$SAMPLER"  \
    --arg  model    "$MODEL"    \
    --argjson steps  $STEPS     \
    --argjson cfg    $CFG       \
    --argjson ag     $AG        \
    --arg gnm        "$GUIDANCENAME" \
    --argjson gsc    $GUIDANCESCALE \
    --argjson w      $WIDTH     \
    --argjson h      $HEIGHT    \
    --argjson seed   $SEED      \
    '{
      sd_model_checkpoint: $model,
      checkpoint:           $model,
      prompt:       $prompt,
      steps:        $steps,
      cfg_scale:    $cfg,
      cfg_true:     $ag,
      guidance_name: $gnm,
      guidance_scale: $gsc,
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
# Source: https://wiki.liutyi.info/display/AI/liutyi+text2image+test+v2
# Grid: 10 categories × 4 variants (A–D) = 40 prompts
# Ordering: row-major (1A, 1B, 1C, 1D, 2A, 2B, …)
# NOTE: prompt 9A is built from MODEL_LABEL and MODEL_COMPANY (placeholders
#       {{MODEL_COMPANY}} / {{MODEL_LABEL}} are filled in by layout_to_prompt)
#
# Every prompt is a MOSS-Image layout prompt:
#   summary.caption  – overall scene and style
#   items[]          – label (text | character | object), caption, bbox,
#                      plus "text" (exact string to render) for text items
# bbox values below are FRACTIONS (0..1) [y_min, x_min, y_max, x_max]; they are
# converted to abs_centralized pixels for your WIDTH/HEIGHT at queue time.
# ---------------------------------------------------------------------------
prompts=()

# --- Row 1: fruits ---
# 1A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro", "food"],
    "canvas": "single",
    "caption": "Close-up photo of gooseberry and strawberry, macro photography, shallow depth of field, focus on the center of the composition, fresh fruits, water droplets on the berries, vibrant colors, juicy textures, food magazine-style photography, high resolution"
  },
  "items": [
    {"label": "object", "caption": "Fresh gooseberries with water droplets, vibrant colors and juicy textures.", "bbox": [0.25, 0.05, 0.80, 0.50]},
    {"label": "object", "caption": "A fresh strawberry with water droplets, vibrant colors and juicy textures.", "bbox": [0.20, 0.45, 0.85, 0.95]}
  ]
}
JSON
)" )
# 1B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro", "food"],
    "canvas": "single",
    "caption": "Close-up photo of mango, kiwi and papaya, shallow depth of field, focus on the center of the composition, fresh fruits, water droplets on the fruits, vibrant colors, juicy textures, food magazine-style photography, high resolution"
  },
  "items": [
    {"label": "object", "caption": "A fresh mango with water droplets, vibrant colors and juicy textures.", "bbox": [0.20, 0.05, 0.85, 0.40]},
    {"label": "object", "caption": "A fresh kiwi with water droplets, vibrant colors and juicy textures.", "bbox": [0.25, 0.38, 0.80, 0.65]},
    {"label": "object", "caption": "A fresh papaya with water droplets, vibrant colors and juicy textures.", "bbox": [0.20, 0.62, 0.85, 0.97]}
  ]
}
JSON
)" )
# 1C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "drink"],
    "canvas": "single",
    "caption": "glass of mohito. Ice cubes. Lime slice for garnish."
  },
  "items": [
    {"label": "object", "caption": "A glass of mohito.", "bbox": [0.10, 0.30, 0.95, 0.70]},
    {"label": "object", "caption": "Ice cubes in the glass.", "bbox": [0.30, 0.35, 0.80, 0.65]},
    {"label": "object", "caption": "A lime slice for garnish.", "bbox": [0.08, 0.55, 0.28, 0.80]}
  ]
}
JSON
)" )
# 1D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "product photo"],
    "canvas": "single",
    "caption": "Table. Glass of wine. Bottle of wine. Grapes and cheese. Professional product photo. 40mm lens. f/2.0"
  },
  "items": [
    {"label": "object", "caption": "A table.", "bbox": [0.60, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "A bottle of wine.", "bbox": [0.15, 0.15, 0.75, 0.35]},
    {"label": "object", "caption": "A glass of wine.", "bbox": [0.35, 0.40, 0.75, 0.58]},
    {"label": "object", "caption": "Grapes and cheese.", "bbox": [0.60, 0.55, 0.90, 0.90]}
  ]
}
JSON
)" )

# --- Row 2: Close-Up ---
# 2A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "macro", "close-up"],
    "canvas": "single",
    "caption": "woman blue eye high details retina close-up macro photo"
  },
  "items": [
    {"label": "object", "caption": "A woman's blue eye with high details retina, in close-up macro.", "bbox": [0.20, 0.10, 0.80, 0.90]}
  ]
}
JSON
)" )
# 2B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "close-up"],
    "canvas": "single",
    "caption": "close up on small key necklace in woman hand. nails are polished and pretty."
  },
  "items": [
    {"label": "object", "caption": "A woman's hand with polished and pretty nails.", "bbox": [0.25, 0.15, 0.95, 0.85]},
    {"label": "object", "caption": "A small key necklace held in the hand.", "bbox": [0.35, 0.35, 0.70, 0.65]}
  ]
}
JSON
)" )
# 2C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "low angle", "fashion"],
    "canvas": "single",
    "caption": "A tiny heart shaped golden key hangs near an ankle on a gold chain anklet of a gorgeous 36yo woman. Low angle shot."
  },
  "items": [
    {"label": "character", "caption": "A gorgeous 36yo woman in a long red maxi dress, seen from a low angle; her toes have red nail polish.", "bbox": [0.0, 0.15, 1.0, 0.85]},
    {"label": "object", "caption": "A tiny heart shaped golden key hanging near the ankle on a gold chain anklet.", "bbox": [0.45, 0.35, 0.65, 0.60]},
    {"label": "object", "caption": "Jimmy Choo high heels.", "bbox": [0.65, 0.25, 1.0, 0.75]}
  ]
}
JSON
)" )
# 2D
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

# --- Row 3: portraits ---
# 3A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "glamour"],
    "canvas": "single",
    "caption": "Elegant woman making quiet gesture with finger to lips in professional portrait suggesting flirt and playfulness."
  },
  "items": [
    {"label": "character", "caption": "An elegant woman with glamour red lipstick, making a quiet gesture with a finger to her lips, suggesting flirt and playfulness.", "bbox": [0.05, 0.20, 0.98, 0.80]},
    {"label": "object", "caption": "Her finger at her lips, with black and red cat eye nail polish.", "bbox": [0.30, 0.45, 0.55, 0.70]},
    {"label": "object", "caption": "A small key necklace she wears.", "bbox": [0.60, 0.40, 0.78, 0.60]}
  ]
}
JSON
)" )
# 3B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "dramatic"],
    "canvas": "single",
    "caption": "Cold stare of an elegant woman making quiet gesture with finger to lips in dramatic professional portrait suggesting her absolute superiority."
  },
  "items": [
    {"label": "character", "caption": "An elegant woman with a cold stare, suggesting her absolute superiority.", "bbox": [0.05, 0.20, 0.98, 0.80]},
    {"label": "object", "caption": "Her finger held to her lips in a quiet gesture.", "bbox": [0.30, 0.45, 0.55, 0.70]}
  ]
}
JSON
)" )
# 3C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "portrait", "black and white", "fine art", "studio"],
    "canvas": "single",
    "caption": "A dramatic black and white studio portrait of an elderly man, half-length, wearing a dark suit jacket. He sits against a deep black background. Strong directional lighting from above and slightly to the side emphasizes deep facial wrinkles, skin texture, and veins on the hands. High contrast chiaroscuro lighting, cinematic mood, minimalist composition, fine art photography, ultra-sharp focus, realistic skin texture, shallow depth of field, professional studio portrait, emotional intensity, timeless aesthetic."
  },
  "items": [
    {"label": "character", "caption": "An elderly man, half-length, wearing a dark suit jacket, seated against a deep black background, in a gesture of emotional exhaustion or contemplation.", "bbox": [0.05, 0.15, 1.0, 0.85]},
    {"label": "object", "caption": "Both hands covering his face, with veins and skin texture on the hands.", "bbox": [0.15, 0.30, 0.65, 0.70]},
    {"label": "object", "caption": "Dark sunglasses partially pressed against his face by his hands.", "bbox": [0.20, 0.35, 0.40, 0.65]}
  ]
}
JSON
)" )
# 3D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "photorealistic", "portrait", "editorial", "fashion", "low angle"],
    "canvas": "single",
    "caption": "Photorealistic low-angle portrait of a confident young woman standing in front of a tall modern office building with vertical glass and concrete lines. Camera positioned near ground level, dramatic upward perspective. Soft overcast daylight. Shallow depth of field, cinematic perspective distortion, 35mm lens, f/2.8, sharp focus on subject, slightly blurred architectural background. Realistic skin texture, professional color grading, high dynamic range, ultra-detailed, editorial fashion photography style."
  },
  "items": [
    {"label": "character", "caption": "A confident young woman looking down toward the camera with a calm, powerful expression. She wears a light gray blazer, white blouse, and dark high-waisted skirt, with natural makeup and long brown hair slightly windswept. One hand is touching her hair.", "bbox": [0.05, 0.20, 1.0, 0.80]},
    {"label": "object", "caption": "One hand slightly forward toward the lens.", "bbox": [0.55, 0.55, 0.95, 0.90]},
    {"label": "object", "caption": "A symmetrical high-rise office building facade with vertical glass and concrete lines and strong leading lines stretching into the sky.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# --- Row 4: reflective ---
# 4A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "night", "cinematic"],
    "canvas": "single",
    "caption": "Classic car on a night road. Car reflection on a wet asphalt. Taillights. Rain and fog."
  },
  "items": [
    {"label": "object", "caption": "A classic car on a night road with glowing taillights, in rain and fog.", "bbox": [0.35, 0.10, 0.80, 0.90]},
    {"label": "object", "caption": "The car's reflection on wet asphalt.", "bbox": [0.75, 0.10, 1.0, 0.90]},
    {"label": "character", "caption": "A male driver in the car.", "bbox": [0.45, 0.20, 0.65, 0.40]},
    {"label": "character", "caption": "Male and female passenger silhouettes visible through the wet rear car windows.", "bbox": [0.45, 0.45, 0.65, 0.80]}
  ]
}
JSON
)" )
# 4B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "selfie"],
    "canvas": "single",
    "caption": "23yo boy in a sportswear creating a selfie in the elevator with two parallel mirrors that creates the infinity mirror trap."
  },
  "items": [
    {"label": "character", "caption": "A 23yo boy in sportswear taking a selfie in the elevator.", "bbox": [0.20, 0.25, 0.95, 0.75]},
    {"label": "object", "caption": "A mirror on one elevator wall, parallel to the opposite mirror, creating an infinity mirror trap of repeated reflections.", "bbox": [0.0, 0.0, 1.0, 0.20]},
    {"label": "object", "caption": "A mirror on the opposite elevator wall, parallel to the first mirror, creating an infinity mirror trap of repeated reflections.", "bbox": [0.0, 0.80, 1.0, 1.0]}
  ]
}
JSON
)" )
# 4C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "monochrome", "close-up"],
    "canvas": "single",
    "caption": "Reflection of woman face, close-up from lips to eyes, in a piece of broken mirror which she holds in her hand. Almost monochrome. Blurry dark background behind the mirror."
  },
  "items": [
    {"label": "object", "caption": "A piece of broken mirror showing the reflection of a woman's face, close-up from lips to eyes.", "bbox": [0.20, 0.20, 0.75, 0.75]},
    {"label": "object", "caption": "Her hand holding the mirror, with fingernails in a dark polish.", "bbox": [0.50, 0.35, 1.0, 0.85]}
  ]
}
JSON
)" )
# 4D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "night", "cityscape"],
    "canvas": "single",
    "caption": "A nice black woman in slingback heels and long red cocktail dress is applying red nail polish on toenails at the windowsill of a New York high-rise building with a view of the night city. Dim warm light."
  },
  "items": [
    {"label": "character", "caption": "A nice black woman in slingback heels and a long red cocktail dress, applying red nail polish on her toenails at the windowsill.", "bbox": [0.25, 0.15, 0.95, 0.70]},
    {"label": "object", "caption": "Toenails being painted with red nail polish.", "bbox": [0.65, 0.25, 0.85, 0.50]},
    {"label": "object", "caption": "A window of a New York high-rise building with a view of the night city.", "bbox": [0.0, 0.50, 0.85, 1.0]},
    {"label": "object", "caption": "Her reflection on the window glass.", "bbox": [0.20, 0.55, 0.85, 0.95]}
  ]
}
JSON
)" )

# --- Row 5: nature ---
# 5A
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
# 5B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["landscape", "sunset"],
    "canvas": "single",
    "caption": "A tranquil sunset over a mirror-like lake reflects a lone tree and flitting birds above."
  },
  "items": [
    {"label": "object", "caption": "A tranquil sunset sky.", "bbox": [0.0, 0.0, 0.50, 1.0]},
    {"label": "object", "caption": "A mirror-like lake.", "bbox": [0.50, 0.0, 1.0, 1.0]},
    {"label": "object", "caption": "A lone tree.", "bbox": [0.25, 0.30, 0.55, 0.50]},
    {"label": "object", "caption": "The reflection of the lone tree in the lake.", "bbox": [0.55, 0.30, 0.80, 0.50]},
    {"label": "object", "caption": "Flitting birds above.", "bbox": [0.10, 0.50, 0.30, 0.85]}
  ]
}
JSON
)" )
# 5C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["landscape", "minimalist realism", "painterly"],
    "canvas": "single",
    "caption": "A serene mountain range shrouded in soft morning fog, rendered in delicate layers with subtle gradients of light blue tones, ranging from pale sky-blue at the peaks to deeper cerulean near the valleys. The scene is bathed in diffused dawn light filtering through low-hanging clouds, casting quiet shadows and luminous highlights. Minimalist composition emphasizes tranquility; distant peaks fade into atmospheric haze, evoking solitude and calm. Mood: peaceful, dreamlike, untouched nature. Style: minimalist realism with painterly texture and muted palette."
  },
  "items": [
    {"label": "object", "caption": "Jagged ridges and snow-dusted summits, with mossy rock faces.", "bbox": [0.10, 0.0, 0.75, 1.0]},
    {"label": "object", "caption": "Mist curling gently around the ridges and hidden forested slopes, creating ethereal depth.", "bbox": [0.45, 0.0, 0.85, 1.0]},
    {"label": "object", "caption": "Low-hanging clouds with diffused dawn light.", "bbox": [0.0, 0.0, 0.30, 1.0]},
    {"label": "object", "caption": "Hidden forested slopes and valleys in deeper cerulean tones.", "bbox": [0.60, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
# 5D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "landscape", "tropical"],
    "canvas": "single",
    "caption": "Tropical remote island shoreline, white sand, gentle waves, bright tropical sunlight."
  },
  "items": [
    {"label": "object", "caption": "A single wooden outrigger canoe resting at the water's edge.", "bbox": [0.62, 0.35, 0.80, 0.65]},
    {"label": "object", "caption": "Palm trees leaning toward the sea.", "bbox": [0.05, 0.0, 0.60, 0.35]},
    {"label": "object", "caption": "Crystal-clear turquoise water with gentle waves, revealing coral and rippled sand beneath the surface.", "bbox": [0.45, 0.0, 0.95, 1.0]},
    {"label": "object", "caption": "White sand shoreline.", "bbox": [0.70, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# --- Row 6: sociotypes ---
# 6A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cartoon"],
    "canvas": "single",
    "caption": "Cartoon style illustration of Socionics type EIE, Ethical-Intuitive Extrovert, \"Hamlet\" archetype. Dynamic theatrical scene with bold red and black color palette. High contrast lighting, thick outline, vibrant colors, 4k, sharp clean cartoon rendering."
  },
  "items": [
    {"label": "character", "caption": "A full-body female character standing on a stage under a dramatic spotlight, in a flowing cape and an exaggerated expressive pose with open arms. Large emotional eyes, intense passionate facial expression.", "bbox": [0.15, 0.25, 0.97, 0.75]},
    {"label": "object", "caption": "Stylized glowing energy waves radiating from the character.", "bbox": [0.10, 0.10, 0.90, 0.90]},
    {"label": "object", "caption": "A silhouetted audience in the background.", "bbox": [0.60, 0.0, 0.95, 1.0]},
    {"label": "object", "caption": "A subtle symbolic clock or spiral time motif behind the character.", "bbox": [0.05, 0.30, 0.55, 0.70]},
    {"label": "text", "caption": "Text in the bottom right corner, first line.", "text": "Mentor", "bbox": [0.86, 0.70, 0.92, 0.97]},
    {"label": "text", "caption": "Text in the bottom right corner, second line.", "text": "(ENFJ, EIE)", "bbox": [0.92, 0.70, 0.98, 0.97]}
  ]
}
JSON
)" )
# 6B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cartoon"],
    "canvas": "single",
    "caption": "Cartoon style illustration of Socionics type LSI, Logical-Sensory Introvert, \"Maxim Gorky\" archetype. Structured and symmetrical composition. Cold blue, steel and dark gray color palette. Sharp clean outlines, minimal exaggerated emotion. High contrast cool lighting, strong shadows. Symbolic order, discipline, and control atmosphere. 4k, sharp clean cartoon rendering."
  },
  "items": [
    {"label": "character", "caption": "A full-body male character standing firmly with straight posture, arms crossed or behind back, with a serious calm expression. He wears a structured formal coat or uniform-style outfit.", "bbox": [0.10, 0.30, 0.97, 0.70]},
    {"label": "object", "caption": "Geometric grid lines and architectural fortress elements in the background.", "bbox": [0.0, 0.0, 1.0, 1.0]},
    {"label": "text", "caption": "Text in the bottom right corner, first line.", "text": "Inspector", "bbox": [0.86, 0.70, 0.92, 0.97]},
    {"label": "text", "caption": "Text in the bottom right corner, second line.", "text": "(ISTJ, LSI)", "bbox": [0.92, 0.70, 0.98, 0.97]}
  ]
}
JSON
)" )
# 6C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cartoon"],
    "canvas": "single",
    "caption": "Cartoon style illustration of Socionics type ILI, Intuitive-Logical Introvert, \"Balzac\" archetype. Dark purple, graphite and deep blue color palette. Soft cool lighting, clean sharp cartoon outlines. Intellectual calm atmosphere, high detail, 4k resolution."
  },
  "items": [
    {"label": "character", "caption": "A calm analytical full-body female character standing slightly aside, with hands in pockets or holding a tablet or book. Subtle skeptical thoughtful facial expression.", "bbox": [0.15, 0.45, 0.97, 0.85]},
    {"label": "object", "caption": "An urban twilight background with distant city lights.", "bbox": [0.30, 0.0, 0.85, 1.0]},
    {"label": "object", "caption": "A transparent timeline or spiral perspective fading into the distance.", "bbox": [0.20, 0.0, 0.80, 0.55]},
    {"label": "object", "caption": "Floating minimalistic charts, numbers and data interface elements.", "bbox": [0.05, 0.05, 0.50, 0.50]},
    {"label": "text", "caption": "Text in the bottom right corner, first line.", "text": "Critic", "bbox": [0.86, 0.70, 0.92, 0.97]},
    {"label": "text", "caption": "Text in the bottom right corner, second line.", "text": "(INTP, ILI)", "bbox": [0.92, 0.70, 0.98, 0.97]}
  ]
}
JSON
)" )
# 6D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cartoon"],
    "canvas": "single",
    "caption": "Cartoon style illustration of Socionics type IEI, Intuitive-Ethical Introvert, \"Yesenin\" archetype. Soft dreamy atmosphere with twilight sky. Blue, violet and soft pink color palette. Soft lighting, smooth shading, clean cartoon outlines. Poetic romantic mood, high detail, 4k resolution."
  },
  "items": [
    {"label": "character", "caption": "A full-body female character standing on a balcony or open space with a gentle posture. Large expressive thoughtful eyes, calm melancholic expression. Flowing hair and light fabric moving in a soft wind. A warm emotional glow around the character.", "bbox": [0.20, 0.30, 0.97, 0.70]},
    {"label": "object", "caption": "A glowing spiral mist or symbolic timeline fading into the distance.", "bbox": [0.20, 0.0, 0.80, 0.40]},
    {"label": "object", "caption": "A subtle transparent clock motif in the background.", "bbox": [0.05, 0.55, 0.45, 0.95]},
    {"label": "object", "caption": "A twilight sky.", "bbox": [0.0, 0.0, 0.50, 1.0]},
    {"label": "text", "caption": "Text in the bottom right corner, first line.", "text": "Lyricist", "bbox": [0.86, 0.70, 0.92, 0.97]},
    {"label": "text", "caption": "Text in the bottom right corner, second line.", "text": "(INFP, IEI)", "bbox": [0.92, 0.70, 0.98, 0.97]}
  ]
}
JSON
)" )

# --- Row 7: unreal ---
# 7A
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "fantasy", "tags"],
    "canvas": "single",
    "caption": "Library, mystical woman, celestial, reading enchanted book, glowing, lights, ethereal, blonde, illuminated, magic, crown, jewelry, absorbed, tales, shelves, sparkling, atmospheric, ancient, delicate, soft, glow, platinum, dim, magical, quiet, whisper, stories, surrounded, magic book, blue eyes, platinum long hair, strong wind, ancient books, soft glow, magical glow, quiet library, dimly lit, luminous book, intricate, dark vivid colors"
  },
  "items": [
    {"label": "character", "caption": "A mystical, celestial, ethereal woman with blue eyes and platinum long blonde hair in a strong wind, wearing a crown and jewelry, absorbed in reading.", "bbox": [0.10, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "An enchanted, luminous magic book with a magical glow, held and read by the woman.", "bbox": [0.50, 0.30, 0.85, 0.70]},
    {"label": "object", "caption": "A quiet, dimly lit library with shelves of ancient books.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
# 7B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "pop-out effect", "POV"],
    "canvas": "single",
    "caption": "A young woman breaks the fourth wall by emerging through a jagged tear in a solid white paper background. High depth of field, clean linework, cinematic lighting, vibrant colors, immersive 3D-pop-out effect. Style: Illustration."
  },
  "items": [
    {"label": "character", "caption": "A young woman with short, wavy red hair and piercing violet eyes, emerging through the tear. She has a slightly angry, annoyed expression with furrowed brows and a subtle blush.", "bbox": [0.10, 0.25, 0.85, 0.75]},
    {"label": "object", "caption": "Her right hand thrust forward toward the viewer in extreme perspective, holding a large black TV remote, her thumb pressing the red power button. The remote dominates the foreground with sharp focus.", "bbox": [0.45, 0.50, 1.0, 0.95]},
    {"label": "object", "caption": "Her left hand actively gripping the edge of the ripped white paper, as if she is physically tearing her way out of the darkness into the viewer's space.", "bbox": [0.30, 0.05, 0.60, 0.30]},
    {"label": "object", "caption": "A jagged tear in a solid white color #FFFFFF paper background.", "bbox": [0.05, 0.15, 0.90, 0.85]},
    {"label": "object", "caption": "Inside the tear, a cozy living room with a brown sofa is visible.", "bbox": [0.20, 0.30, 0.75, 0.70]}
  ]
}
JSON
)" )
# 7C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["illustration", "cinematic", "action"],
    "canvas": "single",
    "caption": "Anthropomorphic gangster duck in a 1920s bank robbery. Cinematic action scene."
  },
  "items": [
    {"label": "character", "caption": "An anthropomorphic gangster duck in a 1920s bank robbery, pointing his Colt revolver to the viewer.", "bbox": [0.15, 0.20, 0.95, 0.80]},
    {"label": "object", "caption": "A cigar the duck is smoking.", "bbox": [0.30, 0.35, 0.42, 0.55]},
    {"label": "object", "caption": "A Colt revolver pointed at the viewer, its barrel smoking.", "bbox": [0.40, 0.50, 0.85, 0.95]},
    {"label": "object", "caption": "A 1920s bank interior.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )
# 7D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "sci-fi", "cyberpunk", "photorealistic", "concept art"],
    "canvas": "single",
    "caption": "Sci-fi cinematic close-up, ultra-realistic. Lighting: cinematic low-key lighting, rim light on fingers, soft reflections, realistic glass refraction. Camera: macro close-up, 85mm lens look, shallow DOF, photorealistic, high detail, sharp focus on device. Style: realistic sci-fi, cyberpunk mood, high-end concept art, ultra-detailed, 8K quality."
  },
  "items": [
    {"label": "object", "caption": "A woman's hand holding a futuristic communication device, with rim light on the fingers.", "bbox": [0.35, 0.20, 1.0, 0.80]},
    {"label": "object", "caption": "A futuristic communication device shaped like a rhombus mirror, with a glass half-mirror surface, polished chrome edges, and a subtle blue neon glow.", "bbox": [0.15, 0.25, 0.85, 0.75]},
    {"label": "object", "caption": "A monochrome holographic video-call face of a woman floating about 2 mm above the glass surface, slightly transparent, with soft light emission.", "bbox": [0.30, 0.35, 0.65, 0.65]},
    {"label": "text", "caption": "The caller name above the hologram, in a clean futuristic UI font, white minimal typography.", "text": "ANNA", "bbox": [0.20, 0.42, 0.28, 0.58]},
    {"label": "object", "caption": "A soft realistic reflection of the face of the woman holding the device, visible in the mirror surface and aligned with the glass angle.", "bbox": [0.50, 0.30, 0.80, 0.70]},
    {"label": "object", "caption": "Background: a dark interior room with a large window behind, showing a futuristic neon city at night, cyberpunk skyline, colorful blurred lights in blue, magenta, cyan, shallow depth of field.", "bbox": [0.0, 0.0, 1.0, 1.0]}
  ]
}
JSON
)" )

# --- Row 8: places ---
# 8A
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
# 8B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "architecture", "night"],
    "canvas": "single",
    "caption": "Neuschwanstein Castle. night lighted"
  },
  "items": [
    {"label": "object", "caption": "Neuschwanstein Castle, lighted at night.", "bbox": [0.15, 0.15, 0.85, 0.85]}
  ]
}
JSON
)" )
# 8C
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
# 8D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "telephoto", "golden hour"],
    "canvas": "single",
    "caption": "Itsukushima Shrine at high tide. Golden hour. telephoto"
  },
  "items": [
    {"label": "object", "caption": "Itsukushima Shrine standing in the water at high tide, shot with a telephoto lens.", "bbox": [0.30, 0.05, 0.80, 0.95]},
    {"label": "object", "caption": "Golden hour light in the sky.", "bbox": [0.0, 0.0, 0.30, 1.0]}
  ]
}
JSON
)" )

# --- Row 9: text ---
# 9A — model-specific prompt (placeholders filled from MODEL_LABEL and MODEL_COMPANY)
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["photograph", "cinematic"],
    "canvas": "single",
    "caption": "A wooden library card index tray being opened by a female librarian with dark red nail polish. Cinematic lighting. Medium field of depth."
  },
  "items": [
    {"label": "object", "caption": "A wooden library card index tray being opened.", "bbox": [0.30, 0.10, 0.95, 0.90]},
    {"label": "character", "caption": "A female librarian's hands with dark red nail polish opening the tray.", "bbox": [0.10, 0.55, 0.70, 1.0]},
    {"label": "text", "caption": "The tray label.", "text": "{{MODEL_COMPANY}}", "bbox": [0.70, 0.35, 0.80, 0.65]},
    {"label": "object", "caption": "Index cards inside the tray.", "bbox": [0.35, 0.15, 0.70, 0.85]},
    {"label": "text", "caption": "The title of the visible card.", "text": "{{MODEL_LABEL}}", "bbox": [0.40, 0.30, 0.48, 0.70]},
    {"label": "object", "caption": "A small image of a girl printed on the visible card.", "bbox": [0.50, 0.25, 0.62, 0.38]},
    {"label": "object", "caption": "A small image of a car printed on the visible card.", "bbox": [0.50, 0.40, 0.62, 0.52]},
    {"label": "object", "caption": "A small image of a home printed on the visible card.", "bbox": [0.50, 0.54, 0.62, 0.66]}
  ]
}
JSON
)" )
# 9B
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
# 9C
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
# 9D
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

# --- Row 10: art / anime ---
# 10A
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
# 10B
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["ASCII art"],
    "canvas": "single",
    "caption": "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. ASCII Art."
  },
  "items": [
    {"label": "character", "caption": "A solitary woman figure watching the sunset over the ocean from a cliff.", "bbox": [0.45, 0.10, 0.90, 0.35]},
    {"label": "object", "caption": "A cliff.", "bbox": [0.60, 0.0, 1.0, 0.50]},
    {"label": "object", "caption": "A sunset over the ocean.", "bbox": [0.0, 0.0, 0.70, 1.0]},
    {"label": "object", "caption": "A sailboat leaving.", "bbox": [0.50, 0.65, 0.70, 0.85]}
  ]
}
JSON
)" )
# 10C
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["anime", "ghibli", "tags"],
    "canvas": "single",
    "caption": "anime,ghibli,1girl,cat,bus,Tokyo, street"
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
# 10D
prompts+=( "$(cat <<'JSON'
{
  "summary": {
    "meta": ["poster", "advertising", "vintage"],
    "canvas": "single",
    "caption": "1970s style woman drinking Coca-Cola. Advertising poster"
  },
  "items": [
    {"label": "character", "caption": "A 1970s style woman drinking Coca-Cola.", "bbox": [0.10, 0.25, 0.95, 0.75]},
    {"label": "object", "caption": "The Coca-Cola drink she is drinking.", "bbox": [0.35, 0.45, 0.60, 0.62]}
  ]
}
JSON
)" )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
