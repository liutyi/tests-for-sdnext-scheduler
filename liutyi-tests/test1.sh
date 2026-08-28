#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="..."' >&2
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
  local negative="${3:-}"
  local task_name
  task_name="$(printf '%02d' "$index") ${prompt:0:16}"

  printf "[QUEUE %02d] %s…\n" "$index" "${prompt:0:120}"

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
# Negative prompts are kept in a parallel negatives[] array.
# Empty string = no negative prompt for that slot.
#
# ⚠ PROMPTS 5A and 5B contain "Model Name" and parameter placeholders (##B, ##).
#   Per test guidance these must be edited for each model before queuing.
#   Current values: MODEL_NAME_HERE, ##B (##GB), steps ##, guidance ##
#
# Row 8C uses a danmaku-style positive (quality tags) and explicit negative —
# intended for fine-tuned anime models that respond to score_N tags.
# ---------------------------------------------------------------------------
prompts=()
negatives=()

# ── Row 1 · Photorealistic ──────────────────────────────────────────────────

# 1A
prompts+=( "A cinematic portrait, wide side view shot of a woman seen through a New York taxi window on. Her face partially obscured by reflections and shadow. She has bob care haircut style, and black cocktail dress. Shallow depth of field focuses softly on her curious eyes, while the foreground glass and background dissolve into blur. There is a part of a car's doors visible." )
negatives+=( "" )

# 1B
prompts+=( "A cinematic retro analog portrait, wide side view shot of a woman seen through a vintage taxi car window on a New York street, he is on the passenger seat, her face partially obscured by reflections and shadow. She has red hair and bob care haircut style, She wear black cocktail dress. Shallow depth of field focuses softly on her eyes, while the foreground glass and background dissolve into blur. There is a part of a car's doors visible. Dramatic natural light filters through the window, creating organic patterns of light and shadow across her face, freckles and skin texture emphasized by directional sunlight.
Warm, muted color palette with earthy browns, olive greens and soft golden highlights. Strong analog film character: visible grain, subtle color fading, low contrast, dust and micro scratches, gentle softness, slight vignetting. Emotional, introspective mood, quiet tension, cinematic stillness." )
negatives+=( "" )

# 1C
prompts+=( "High-key macro close-up captures of a business scene, focusing sharply on a woman's right hand holding expensive pen slightly above the fine print agreement papers. The skin is rendered with soft, lifelike texture and subtle subsurface scattering, illuminated by warm, dappled sunlight from panoramic office windows. The nails are manicured in a glossy, pale pastel pink oval shape. On the ring finger, a thin gold ring with small brilliant-cut diamond. The hand emerges from a taupe business blazer visible at the far right edge. The papers laying on the wooden office table. On the table there are also couple of metal clips. The background is slightly blurry cityscape behind the window. Shallow depth of field. Photorealistic." )
negatives+=( "Low resolution, low image quality, distorted limbs and fingers, oversaturated image, wax figure appearance, lack of facial detail, excessive smoothing, AI-like appearance. Chaotic composition. Blurry and distorted text." )

# 1D
prompts+=( "ultra-realistic professional corporate photography, close-up shot of a woman's right hand signing a legal document on a polished wooden office desk, elegant black fountain pen with gold accents held delicately between fingers, soft pink manicured nails, subtle natural skin texture, diamond solitaire ring on ring finger with gold band, shallow depth of field
modern executive office interior, large floor-to-ceiling window in background, soft daylight illumination, blurred city skyline with tall buildings outside the window, neutral business atmosphere
beige tailored blazer sleeve visible, minimalistic office aesthetic, black leather office chair slightly out of focus, silver binder clips resting on the desk to the left, crisp white paper with fine printed text
photorealistic, 85mm lens look, f/1.8 depth of field, cinematic soft light, realistic shadows, high dynamic range, natural color grading, professional commercial photography style, clean composition, calm corporate mood" )
negatives+=( "cartoon, illustration, anime, over-stylized, exaggerated hands, extra fingers, deformed hands, low detail, blurry foreground, harsh lighting, oversaturated colors, text artifacts, watermark, logo, stock photo look, unreal skin" )

# ── Row 2 · Architecture ────────────────────────────────────────────────────

# 2A
prompts+=( "Oslo opera house" )
negatives+=( "" )

# 2B
prompts+=( "Manhattan bridge with night New York cityscape on the background" )
negatives+=( "" )

# 2C
prompts+=( "Futuristic circular pavilion with some people and warm light inside is on a distance. The pavilion got panoramic windows. It is embedded into an edge of steep cliff. Curvy narrow concrete upward path and stairs goes to it. Misty mountain landscape. Photo from a distance. Low angle shot. Large negative space." )
negatives+=( "" )

# 2D
prompts+=( "Ultra-realistic architectural photography of a futuristic circular pavilion embedded into a steep, misty mountain landscape. The building has a wide cantilevered concrete roof and floor, forming a floating ring, with full-height vertical glass panels glowing with warm amber interior light. Minimalist brutalist concrete textures, smooth curved geometry, organic integration with terrain. A narrow winding concrete path with shallow steps leads uphill through lush, vivid green moss-covered hills toward the structure. Dense fog and overcast sky, dramatic moody atmosphere, soft diffused light. Background: dark rocky cliffs fading into mist, cinematic depth and scale. Interior silhouettes of a few people visible through the glass, subtle human presence for scale. Shot from a low angle along the path, strong leading lines, architectural composition. Hyper-detailed, photorealistic, 8k quality, global illumination, natural color grading, modern architectural magazine style." )
negatives+=( "low resolution, cartoon, anime, fantasy illustration, oversaturated colors, harsh sunlight, blue sky, flat lighting, cluttered environment, trees with leaves, city buildings, vehicles, text, logos, distortion, warped geometry, unrealistic proportions" )

# ── Row 3 · Interior ────────────────────────────────────────────────────────

# 3A
prompts+=( "Charcoal Blue kitchen" )
negatives+=( "" )

# 3B
prompts+=( "art nouveau interior design that incorporate nature-inspired motifs and includes glamour metallic elements, jewel tones and decorative furniture" )
negatives+=( "" )

# 3C
prompts+=( "loft bedroom with panoramic window" )
negatives+=( "" )

# 3D
prompts+=( "futuristic interior design living room" )
negatives+=( "" )

# ── Row 4 · Nature ──────────────────────────────────────────────────────────

# 4A
prompts+=( "whale surrounded by fishes underwater photo" )
negatives+=( "" )

# 4B
prompts+=( "mountains and foggy valleys" )
negatives+=( "" )

# 4C
prompts+=( "Golden Maple Leaves In Autumn Sunlight With Delicate Details" )
negatives+=( "" )

# 4D
prompts+=( "Ultra-vibrant tropical waterfall cascading from lush jungle cliffs into a crystal-clear turquoise lagoon, surrounded by dense rainforest foliage in neon greens, emeralds, and deep teals. Sunlight pierces through misty air, creating glowing god rays and subtle rainbow refractions in the waterfall spray. Exotic tropical plants with oversized leaves, bright flowers in magenta, orange, and yellow framing the scene. Hyper-detailed water motion, silky waterfall flow with dynamic splashes and foam. Cinematic wide-angle composition, strong depth, high saturation, HDR lighting, extreme clarity, sharp focus, fantasy-realism style, breathtaking postcard aesthetic, ultra high resolution, masterpiece quality." )
negatives+=( "dull colors, low saturation, flat lighting, overexposed highlights, muddy water, foggy blur, washed-out tones, people, animals, buildings, text, watermark, logo, artifacts, low resolution, noise" )

# ── Row 5 · Text ────────────────────────────────────────────────────────────
# ⚠ Replace MODEL_NAME_HERE with the actual model name before queuing.
# ⚠ Replace ##B (##GB), ## with actual model size / steps / guidance values.

# 5A
prompts+=( "Urban exterior setting. A-frame chalkboard sign on cobblestone street. Yellow color chalk used to write title \"${MODEL_LABEL}\". Next line is orange chalk drawing of \"⭐⭐⭐\". Next lines are white chalk for smaller text: \"- ${MODEL_PARAMS}  - steps ${STEPS} - guidance ${CFG}\"" )
negatives+=( "" )

# 5B
prompts+=( "Bright graffiti \"${MODEL_LABEL}\". on mirror glass wall of skyscraper. Graffiti background resemble simplified cat face. Dark grey asphalt on a sidewalk below. Large building number sign with text \"${MODEL_PARAMS}\" is on the top left corner above the graffiti. 8yo boy cyclist riding in front of the building." )
negatives+=( "" )

# 5C
prompts+=( "Book Alice's Adventures in Wonderland by Lewis Carroll is opened on CHAPTER VII. Left page is relevant illustration and right page is text. Text of the page is following: CHAPTER VII. A Mad Tea-Party There was a table set out under a tree in front of the house, and the March Hare and the Hatter were having tea at it: a Dormouse was sitting between them, fast asleep, and the other two were using it as a cushion, resting their elbows on it, and talking over its head. \"Very uncomfortable for the Dormouse,\" thought Alice; \"only, as it's asleep, I suppose it doesn't mind.\" The table was a large one, but the three were all crowded together at one corner of it: \"No room! No room!\" they cried out when they saw Alice coming. \"There's plenty of room!\" said Alice indignantly, and she sat down in a large arm-chair at one end of the table. \"Have some wine,\" the March Hare said in an encouraging tone. Alice looked all round the table, but there was nothing on it but tea. \"I don't see any wine,\" she remarked. \"There isn't any,\" said the March Hare. \"Then it wasn't very civil of you to offer it,\" said Alice angrily. \"It wasn't very civil of you to sit down without being invited,\" said the March Hare. \"I didn't know it was your table,\" said Alice; \"it's laid for a great many more than three.\" \"Your hair wants cutting,\" said the Hatter. He had been looking at Alice for some time with great curiosity, and this was his first speech." )
negatives+=( "" )

# 5D
prompts+=( "High-resolution three-panel meme recreation, clean modern meme style. TOP PANEL, STRICT TYPOGRAPHY CONSTRAINTS: Two identical wooden house-shaped decorations placed side by side, equal size, perfectly aligned. Each decoration MUST contain text in EXACTLY TWO LINES ONLY: Line 1 (top): \"HO\", Line 2 (bottom): \"ME\". DO NOT spell \"HOME\" horizontally. Reading logic MUST be visually correct: Reading each decoration vertically is \"HOME\" / \"HOME\", Reading across decorations by rows is \"HO HO\" / \"ME ME\". Black bold block letters, rustic wooden roof above each decoration, realistic wood grain, white retail shelf, neutral store lighting, sharp focus. BOTTOM LEFT PANEL — ORIGINAL MEME POSE REQUIRED: Two women seated at a dinner table. Foreground: blonde woman angrily shouting and pointing forward. Behind her: second woman leaning in, holding the shouting woman by placing one hand firmly on her shoulder, expression tense and supportive, as if restraining or backing her up. Clear physical contact is visible and intentional. Dramatic reality-TV lighting and expressions. Bold white Impact-style meme caption with black outline: \"HOME HOME\". BOTTOM RIGHT PANEL: White cat sitting at a table, judgmental and confused expression, mouth slightly open, iconic meme framing. Bold white Impact-style meme caption with black outline: \"HOHO MEME\". Straight panel borders, equal spacing, perfect alignment, ultra-sharp 4K quality, no blur, no pose ambiguity, faithful meme recreation." )
negatives+=( "" )

# ── Row 6 · Comics ──────────────────────────────────────────────────────────

# 6A
prompts+=( "Iron man comics" )
negatives+=( "" )

# 6B
prompts+=( "3 spider man pointing meme" )
negatives+=( "" )

# 6C
prompts+=( "Three identical Spider-Man characters stand indoors, all pointing at each other simultaneously in a perfect triangular standoff. Left Spider-Man: foreground left, body angled right, right arm fully extended pointing toward center. Center Spider-Man: slightly farther back, centered, legs apart, torso forward, both arms extended, pointing left and right. Right Spider-Man: foreground right, body angled left, left arm extended pointing toward center. Interior warehouse/garage space. Left background: a white NYPD police van, side view partially visible, parked indoors, simple blocky shape, blue stripe, subtle \"NYPD\" style markings (cartoon-simplified, not realistic). Back wall: flat muted pink / salmon-colored wall, solid color, no texture. Floor: flat blue-gray concrete. Right side: stacked wooden crates, simple box shapes.
1960s–1970s American cartoon cel animation still, hand-drawn look, flat colors, thick black outlines, minimal shading, slightly off-model anatomy, vintage TV animation aesthetic. Mid-wide shot, straight-on eye-level camera, all three characters fully visible, equal scale, meme-accurate spacing, no dramatic perspective. Faded retro palette, soft edges, mild film grain, no modern lighting, no realism, no depth of field.
All three Spider-Men must look identical. Finger pointing must be precisely aligned toward each other. Background elements must stay flat and simple." )
negatives+=( "photorealism, modern Spider-Man suit, MCU style, 3D render, cinematic lighting, dramatic shadows, blur, depth of field, extra limbs, extra fingers, incorrect pointing, asymmetry, cropped bodies, text, logos, realism" )

# 6D
prompts+=( "3-panel comic strip set in the DC Universe. Panel 1: Superman stands heroically on a rooftop at sunset, fists on hips, wearing his classic red and blue suit with the \"S\" emblem. Raising one eyebrow with a skeptical but amused expression. Lois Lane stands nearby, wearing a professional reporter outfit (blazer, blouse, pencil skirt), looking confident but slightly confused. Lois touch her lips with a tip of a pen in her hand. Panel 2: Superman looking in the Lois eyes. Superman speech bubble: \"Why did I bring a pencil to the fight?\". Lois Lane and Superman glancing at each other in a moment of silence. Panel 3: Close-up of Lois Lane grinning proudly. He winks and holds up the pencil like a mic drop moment. Lois speech bubble: \"In case you needed to draw some attention!\". Superman facepalms in the background, smiling despite herself. Style: Bright, comic-book illustration reminiscent of DC Comics—bold outlines, vibrant colors, dynamic angles. Include word balloons with clear, readable comic font. Keep the humor lighthearted and on-brand for DC's tone." )
negatives+=( "photorealistic, grimdark horror, blurry text, extra panels, messy composition" )

# ── Row 7 · Celebrities ─────────────────────────────────────────────────────

# 7A
prompts+=( "Barack Obama mic drop" )
negatives+=( "" )

# 7B
prompts+=( "Arnold Schwarzenegger on a motorcycle in Terminator 2 movie" )
negatives+=( "" )

# 7C
prompts+=( "Marvel Avengers Characters Grid" )
negatives+=( "" )

# 7D
prompts+=( "Marvel Avengers character grid, 3x3 layout, each cell featuring a different iconic superhero portrait: Iron Man, Captain America, Thor, Hulk, Black Widow, Hawkeye, Spider-Man, Doctor Strange, Black Panther. Front-facing or slight three-quarter view, consistent framing and scale, cinematic studio lighting, ultra-detailed faces and costumes, realistic textures, sharp focus. Clean neutral background per cell with subtle color variation matching each character's theme. High contrast, polished blockbuster look, symmetrical composition, modern Marvel cinematic style, ultra-high resolution, crisp edges, no text." )
negatives+=( "low resolution, blurry, deformed face, extra limbs, incorrect anatomy, inconsistent proportions, oversaturated colors, cartoon, anime, painterly, text, logos, watermark, cropped heads, duplicate characters" )

# ── Row 8 · Anime ───────────────────────────────────────────────────────────

# 8A
prompts+=( "Naruto vs Sasuke final battle" )
negatives+=( "" )

# 8B
prompts+=( "Epic anime final battle scene, Naruto Uzumaki vs Sasuke Uchiha facing each other mid-air, frozen at the moment before impact, Naruto glowing with intense golden Kurama chakra, swirling energy tails and cracked earth beneath him, Sasuke enveloped in dark purple Susanoo aura with crackling lightning and glowing Rinnegan eye, massive Rasengan colliding with Chidori, explosive energy shockwave tearing the valley apart, shattered rocks suspended in the air, dramatic storm clouds overhead split by blinding light, rain and dust particles illuminated by energy, ultra-dynamic action pose, extreme motion blur on energy trails, cinematic wide shot, anime masterpiece, hand-drawn style, sharp lineart, rich saturated colors, high contrast lighting, ultra-detailed, 8k anime illustration" )
negatives+=( "low detail, blurry, extra limbs, bad anatomy, distorted faces, flat lighting, dull colors, cropped characters, watermark, text, logo" )

# 8C — danmaku quality tags (intended for fine-tuned anime models)
prompts+=( "score_9, score_8_up, score_7_up, source_anime, 1girl" )
negatives+=( "score_1, score_2, score_3, worst quality, bad quality, jpeg artifacts, source_cartoon, 3d, monochrome, blurry, lowres, text, watermark" )

# 8D
prompts+=( "anime, ghibli, 1girl, cat, bus, Tokyo, street" )
negatives+=( "" )

# ── Row 9 · Illustrations ───────────────────────────────────────────────────

# 9A
prompts+=( "Fence painting illustration for \"The Adventures of Tom Sawyer\" book cover." )
negatives+=( "" )

# 9B
prompts+=( "Highly detailed, educational illustration of the Solar System, textbook style, labeled planets orbiting the Sun, realistic planetary textures, correct relative sizes and positions, clear orbit paths, annotated with planet names, scientific style, clean vector-like lines, bright but natural colors, easy-to-read labels, high clarity and contrast, front view layout, diagrammatic yet visually appealing, suitable for children and students, no artistic exaggeration, neutral lighting, crisp and precise." )
negatives+=( "" )

# 9C
prompts+=( "Educational diagram of the Solar System in textbook style, front/orthographic view, all planets labeled and positioned in orbit around the Sun, accurate relative sizes for illustration purposes, labeled clearly with planet names, each planet placed from left to right as Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune.
Sun: large yellow-orange sphere on the left, labeled 'Sun' above it.
Mercury: smallest, gray, closest to Sun, labeled above.
Venus: slightly larger, pale yellow, second from Sun, labeled above.
Earth: blue-green with white clouds, third from Sun, labeled above.
Mars: small red planet, fourth from Sun, labeled above.
Jupiter: largest planet, brown-orange stripes, fifth from Sun, labeled above.
Saturn: large yellow-gold with wide rings, sixth from Sun, labeled above.
Uranus: light blue-green, seventh from Sun, labeled above.
Neptune: deep blue, eighth from Sun, labeled above.
Orbit paths: subtle thin circular lines behind each planet, evenly spaced, labeled with orbital numbers or distances if possible.
Background: dark space with faint stars, subtle grid lines for scale.
Text labels: clear, white, easy-to-read font, positioned above each planet.
Lighting: neutral and even, minimal shadows, diagrammatic style.
Style: realistic planetary textures but simplified for textbook clarity, vector-diagram-like, scientific and educational, no artistic exaggeration, all planets in a single line orbit for clarity." )
negatives+=( "" )

# 9D
prompts+=( "apartment plan drawing. 120 square meters, 1 living room, 2 bathrooms, 2 bedroom, kitchen, balcony" )
negatives+=( "" )

# ── Row 10 · Materials ──────────────────────────────────────────────────────

# 10A
prompts+=( "Clay-crafted girl is playing with the clay cat." )
negatives+=( "" )

# 10B
prompts+=( "Knitting of the phoenix on the white fabric. With stitched text \"Phoenix\" below." )
negatives+=( "" )

# 10C
prompts+=( "Marble cat figure" )
negatives+=( "" )

# 10D
prompts+=( "Ice sculpture of a man in a hat" )
negatives+=( "" )

# ── Row 11 · Abstract Art ───────────────────────────────────────────────────

# 11A
prompts+=( "abstract art" )
negatives+=( "" )

# 11B
prompts+=( "abstract art wallpaper. gold on sepia. masterpiece." )
negatives+=( "" )

# 11C
prompts+=( "abstract art wallpaper. gold color splash on dark grayscale. masterpiece." )
negatives+=( "" )

# 11D
prompts+=( "abstract art wallpaper. city theme. masterpiece." )
negatives+=( "" )

# ── Row 12 · Art Styles (first four) ────────────────────────────────────────

# 12A
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. Pop art." )
negatives+=( "" )

# 12B
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. Shin-hanga Art." )
negatives+=( "" )

# 12C
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. Futurism Art." )
negatives+=( "" )

# 12D
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. ASCII Art." )
negatives+=( "" )

# ── Row 12 · Art Styles (extra four — unnumbered in source) ─────────────────

# 13A (extra)
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. cubism art." )
negatives+=( "" )

# 13B (extra)
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. expressionist art." )
negatives+=( "" )

# 13C (extra)
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. Hokusai art." )
negatives+=( "" )

# 13D (extra)
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. Salvador Dali art." )
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
