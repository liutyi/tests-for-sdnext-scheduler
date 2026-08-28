#!/usr/bin/env bash
set -euo pipefail


MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="HiDream-ai/HiDream-O1-Image"' >&2
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
# NOTE: prompt 9A is dynamically built from MODEL_LABEL and MODEL_COMPANY above
# ---------------------------------------------------------------------------
prompts=()

# --- Row 1: fruits ---
# 1A
prompts+=( "Close-up photo of gooseberry and strawberry, macro photography, shallow depth of field, focus on the center of the composition, fresh fruits, water droplets on the berries, vibrant colors, juicy textures, food magazine-style photography, high resolution" )
# 1B
prompts+=( "Close-up photo of mango, kiwi and papaya, shallow depth of field, focus on the center of the composition, fresh fruits, water droplets on the fruits, vibrant colors, juicy textures, food magazine-style photography, high resolution" )
# 1C
prompts+=( "glass of mohito. Ice cubes. Lime slice for garnish." )
# 1D
prompts+=( "Table. Glass of wine. Bottle of wine. Grapes and cheese. Professional product photo. 40mm lens. f/2.0" )

# --- Row 2: Close-Up ---
# 2A
prompts+=( "woman blue eye high details retina close-up macro photo" )
# 2B
prompts+=( "close up on small key necklace in woman hand. nails are polished and pretty." )
# 2C
prompts+=( "tiny heart shaped golden key hangs near an ankle on gold chain anklet of gorgeous 36yo woman. Low angle shot. High heels is Jimmy Choo. Toes with red nail polish. Long red maxi dress." )
# 2D
prompts+=( "ultra-realistic professional corporate photography, close-up shot of a woman's right hand signing a legal document on a polished wooden office desk, elegant black fountain pen with gold accents held delicately between fingers, soft pink manicured nails, subtle natural skin texture, diamond solitaire ring on ring finger with gold band, shallow depth of field, modern executive office interior, large floor-to-ceiling window in background, soft daylight illumination, blurred city skyline with tall buildings outside the window, neutral business atmosphere, beige tailored blazer sleeve visible, minimalistic office aesthetic, black leather office chair slightly out of focus, silver binder clips resting on the desk to the left, crisp white paper with fine printed text, photorealistic, 85mm lens look, f/1.8 depth of field, cinematic soft light, realistic shadows, high dynamic range, natural color grading, professional commercial photography style, clean composition, calm corporate mood" )

# --- Row 3: portraits ---
# 3A
prompts+=( "Elegant woman making quiet gesture with finger to lips in professional portrait suggesting flirt and playfulness. She wear small key necklace. Glamour red lipstick, black and red cat eye nail polish." )
# 3B
prompts+=( "cold stare of an elegant woman making quiet gesture with finger to lips in dramatic professional portrait suggesting her absolute superiority" )
# 3C
prompts+=( "A dramatic black and white studio portrait of an elderly man, half-length, wearing a dark suit jacket. He sits against a deep black background, both hands covering his face in a gesture of emotional exhaustion or contemplation. Dark sunglasses are partially pressed against his face by his hands. Strong directional lighting from above and slightly to the side emphasizes deep facial wrinkles, skin texture, and veins on the hands. High contrast chiaroscuro lighting, cinematic mood, minimalist composition, fine art photography, ultra-sharp focus, realistic skin texture, shallow depth of field, professional studio portrait, emotional intensity, timeless aesthetic." )
# 3D
prompts+=( "Photorealistic low-angle portrait of a confident young woman standing in front of a tall modern office building with vertical glass and concrete lines. Camera positioned near ground level, dramatic upward perspective. She is looking down toward the camera with a calm, powerful expression. One hand slightly forward toward the lens, the other touching her hair. She wears a light gray blazer, white blouse, and dark high-waisted skirt. Long brown hair slightly windswept. Natural makeup. Soft overcast daylight. Background shows a symmetrical high-rise facade with strong leading lines stretching into the sky. Shallow depth of field, cinematic perspective distortion, 35mm lens, f/2.8, sharp focus on subject, slightly blurred architectural background. Realistic skin texture, professional color grading, high dynamic range, ultra-detailed, editorial fashion photography style." )

# --- Row 4: reflective ---
# 4A
prompts+=( "Classic car on a night road. Car reflection on a wet asphalt. Taillights. Rain and fog. In the car male driver and 2 passengers. Male and female passenger silhouettes visible through wet rear car windows." )
# 4B
prompts+=( "23yo boy in a sportswear creating a selfie in the elevator with two parallel mirrors that creates the infinity mirror trap." )
# 4C
prompts+=( "Reflection of woman face, close-up from lips to eyes, in a a piece of broken mirror which she holds in her hand. Her fingernails are with a dark polish. Almost monochrome. Blurry dark background behind the mirror." )
# 4D
prompts+=( "A nice black woman in slingback heels and long red cocktail dress is applying red nail polish on toenails at the windowsill of a New York high-rise building with a view of the night city. Dim warm light. Her reflection on window glass." )

# --- Row 5: nature ---
# 5A
prompts+=( "whale surrounded by fishes underwater photo" )
# 5B
prompts+=( "A tranquil sunset over a mirror-like lake reflects a lone tree and flitting birds above." )
# 5C
prompts+=( "A serene mountain range shrouded in soft morning fog, rendered in delicate layers with subtle gradients of light blue tones - ranging from pale sky-blue at the peaks to deeper cerulean near the valleys. Mist curls gently around jagged ridges and hidden forested slopes, creating ethereal depth. The scene is bathed in diffused dawn light filtering through low-hanging clouds, casting quiet shadows and luminous highlights across snow-dusted summits and mossy rock faces. Minimalist composition emphasizes tranquility; distant peaks fade into atmospheric haze, evoking solitude and calm. Mood: peaceful, dreamlike, untouched nature. Style: minimalist realism with painterly texture and muted palette." )
# 5D
prompts+=( "Tropical remote island shoreline, white sand, a single wooden outrigger canoe resting at the water's edge, crystal-clear turquoise water revealing coral and rippled sand beneath the surface, gentle waves, palm trees leaning toward the sea, bright tropical sunlight." )

# --- Row 6: sociotypes ---
# 6A
prompts+=( "Cartoon style illustration of Socionics type EIE (Ethical-Intuitive Extrovert, \"Hamlet\" archetype). Dynamic theatrical scene with bold red and black color palette. Full-body female character standing on a stage under a dramatic spotlight. Flowing cape, exaggerated expressive pose with open arms. Large emotional eyes, intense passionate facial expression. Stylized glowing energy waves radiating from the character. Silhouetted audience in background. Subtle symbolic clock or spiral time motif behind. High contrast lighting, thick outline, vibrant colors, 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Mentor\" and \"(ENFJ, EIE)\"" )
# 6B
prompts+=( "Cartoon style illustration of Socionics type LSI (Logical-Sensory Introvert, \"Maxim Gorky\" archetype). Structured and symmetrical composition. Full-body male character standing firmly with straight posture. Arms crossed or behind back, serious calm expression. Wearing a structured formal coat or uniform-style outfit. Cold blue, steel and dark gray color palette. Geometric grid lines and architectural fortress elements in the background. Sharp clean outlines, minimal exaggerated emotion. High contrast cool lighting, strong shadows. Symbolic order, discipline, and control atmosphere. 4k, sharp clean cartoon rendering. Text in a bottom right corner reads \"Inspector\" and \"(ISTJ, LSI)\"" )
# 6C
prompts+=( "Cartoon style illustration of Socionics type ILI (Intuitive-Logical Introvert, \"Balzac\" archetype). Calm analytical full-body female character standing slightly aside. Hands in pockets or holding a tablet/book. Subtle skeptical thoughtful facial expression. Dark purple, graphite and deep blue color palette. Urban twilight background with distant city lights. Transparent timeline or spiral perspective fading into distance. Floating minimalistic charts, numbers and data interface elements. Soft cool lighting, clean sharp cartoon outlines. Intellectual calm atmosphere, high detail, 4k resolution. Text in a bottom right corner reads \"Critic\" and \"(INTP, ILI)\"" )
# 6D
prompts+=( "Cartoon style illustration of Socionics type IEI (Intuitive-Ethical Introvert, \"Yesenin\" archetype). Soft dreamy atmosphere with twilight sky. Full-body female character standing on a balcony or open space with gentle posture. Large expressive thoughtful eyes, calm melancholic expression. Flowing hair and light fabric moving in soft wind. Blue, violet and soft pink color palette. Glowing spiral mist or symbolic timeline fading into distance. Subtle transparent clock motif in background. Warm emotional glow around the character. Soft lighting, smooth shading, clean cartoon outlines. Poetic romantic mood, high detail, 4k resolution. Text in a bottom right corner reads \"Lyricist\" and \"(INFP, IEI)\"" )

# --- Row 7: unreal ---
# 7A
prompts+=( "Library, mystical woman, celestial, reading enchanted book, glowing, lights, ethereal, blonde, illuminated, magic, crown, jewelry, absorbed, tales, shelves, sparkling, atmospheric, ancient, delicate, soft, glow, platinum, dim, magical, quiet, whisper, stories, surrounded, magic book, blue eyes, platinum long hair, strong wind, ancient books, soft glow, magical glow, quiet library, dimly lit, luminous book, intricate, dark vivid colors" )
# 7B
prompts+=( "A young woman with short, wavy red hair and piercing violet eyes breaks the fourth wall by emerging through a jagged tear in a solid white (color #FFFFFF) paper background. She has a slightly angry, annoyed expression with furrowed brows and a subtle blush. Her right hand is thrust forward toward the viewer in extreme perspective (POV), holding a large black TV remote (Pressing red power button of the remote by her thumb finger). Remote dominates the foreground with sharp focus. Her left hand is actively gripping the edge of the ripped white paper, as if she is physically tearing her way out of the darkness into the viewer's space. Inside the tear, a cozy living room with a brown sofa is visible. High depth of field, clean linework, cinematic lighting, vibrant colors, immersive 3D-pop-out effect. Style: Illustration." )
# 7C
prompts+=( "Anthropomorphic gangster duck in a 1920s bank robbery. The duck is smoking cigar and pointing his Colt revolver to the viewer. The colt barrel is smoking. Cinematic action scene." )
# 7D
prompts+=( "Sci-fi cinematic close-up, ultra-realistic. A woman's hand holding a futuristic communication device shaped like a rhombus mirror. The device has a glass / half-mirror surface, polished chrome edges, subtle blue neon glow. A monochrome holographic video-call face of a woman is floating ~2 mm above the glass surface, slightly transparent, soft light emission. The caller name \"ANNA\" appears above the hologram in a clean futuristic UI font, white minimal typography. The mirror surface reflects the face of the woman holding the device, visible as a soft realistic reflection aligned with the glass angle. Background: dark interior room, large window behind, futuristic neon city at night, cyberpunk skyline, colorful blurred lights (blue, magenta, cyan), shallow depth of field. Lighting: cinematic low-key lighting, rim light on fingers, soft reflections, realistic glass refraction. Camera: macro / close-up, 85mm lens look, shallow DOF, photorealistic, high detail, sharp focus on device. Style: realistic sci-fi, cyberpunk mood, high-end concept art, ultra-detailed, 8K quality" )

# --- Row 8: places ---
# 8A
prompts+=( "Manhattan bridge with night New York cityscape on the background" )
# 8B
prompts+=( "Neuschwanstein Castle. night lighted" )
# 8C
prompts+=( "loft bedroom with panoramic window" )
# 8D
prompts+=( "Itsukushima Shrine at high tide. Golden hour. telephoto" )

# --- Row 9: text ---
# 9A — model-specific prompt (dynamically built from MODEL_LABEL and MODEL_COMPANY)
prompts+=( "Wooden library card index tray being opened by a female librarian with dark red nail polish. The tray label is \"${MODEL_COMPANY}\". Inside Index cards. Visible card is card with title \"${MODEL_LABEL}\" and 3 small images printed on it (1girl, car, home). Cinematic lighting. Medium field of depth." )
# 9B
prompts+=( "High-resolution three-panel meme recreation, clean modern meme style. TOP PANEL, STRICT TYPOGRAPHY CONSTRAINTS: Two identical wooden house-shaped decorations placed side by side, equal size, perfectly aligned. Each decoration MUST contain text in EXACTLY TWO LINES ONLY: Line 1 (top): \"HO\", Line 2 (bottom): \"ME\". DO NOT spell \"HOME\" horizontally. Reading logic MUST be visually correct: Reading each decoration vertically is \"HOME\" / \"HOME\", Reading across decorations by rows is \"HO HO\" / \"ME ME\". Black bold block letters, rustic wooden roof above each decoration, realistic wood grain, white retail shelf, neutral store lighting, sharp focus. BOTTOM LEFT PANEL — ORIGINAL MEME POSE REQUIRED: Two women seated at a dinner table. Foreground: blonde woman angrily shouting and pointing forward. Behind her: second woman leaning in, holding the shouting woman by placing one hand firmly on her shoulder, expression tense and supportive, as if restraining or backing her up. Clear physical contact is visible and intentional. Dramatic reality-TV lighting and expressions. Bold white Impact-style meme caption with black outline: \"HOME HOME\". BOTTOM RIGHT PANEL: White cat sitting at a table, judgmental and confused expression, mouth slightly open, iconic meme framing. Bold white Impact-style meme caption with black outline: \"HOHO MEME\". Straight panel borders, equal spacing, perfect alignment, ultra-sharp 4K quality, no blur, no pose ambiguity, faithful meme recreation." )
# 9C
prompts+=( "3-panel comic strip set in the DC Universe. Panel 1: Superman stands heroically on a rooftop at sunset, fists on hips, wearing his classic red and blue suit with the \"S\" emblem. Raising one eyebrow with a skeptical but amused expression. Lois Lane stands nearby, wearing a professional reporter outfit (blazer, blouse, pencil skirt), looking confident but slightly confused. Lois touch her lips with a tip of a pen in her hand. Panel 2: Superman looking in the Lois eyes. Superman speech bubble: \"Why did I bring a pencil to the fight?\". Lois Lane and Superman glancing at each other in a moment of silence. Panel 3: Close-up of Lois Lane grinning proudly. He winks and holds up the pencil like a mic drop moment. Lois speech bubble: \"In case you needed to draw some attention!\". Superman facepalms in the background, smiling despite herself. Style: Bright, comic-book illustration reminiscent of DC Comics — bold outlines, vibrant colors, dynamic angles. Include word balloons with clear, readable comic font. Keep the humor lighthearted and on-brand for DC's tone." )
# 9D
prompts+=( "Educational diagram of the Solar System in textbook style, front/orthographic view, all planets labeled and positioned in orbit around the Sun, accurate relative sizes for illustration purposes, labeled clearly with planet names, each planet placed from left to right as Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus, Neptune. Sun: large yellow-orange sphere on the left, labeled 'Sun' above it. Mercury: smallest, gray, closest to Sun, labeled above. Venus: slightly larger, pale yellow, second from Sun, labeled above. Earth: blue-green with white clouds, third from Sun, labeled above. Mars: small red planet, fourth from Sun, labeled above. Jupiter: largest planet, brown-orange stripes, fifth from Sun, labeled above. Saturn: large yellow-gold with wide rings, sixth from Sun, labeled above. Uranus: light blue-green, seventh from Sun, labeled above. Neptune: deep blue, eighth from Sun, labeled above. Orbit paths: subtle thin circular lines behind each planet, evenly spaced, labeled with orbital numbers or distances if possible. Background: dark space with faint stars, subtle grid lines for scale. Text labels: clear, white, easy-to-read font, positioned above each planet. Lighting: neutral and even, minimal shadows, diagrammatic style. Style: realistic planetary textures but simplified for textbook clarity, vector-diagram-like, scientific and educational, no artistic exaggeration, all planets in a single line orbit for clarity." )

# --- Row 10: art / anime ---
# 10A
prompts+=( "abstract art wallpaper. city theme. masterpiece." )
# 10B
prompts+=( "solitary woman figure watching sunset ocean from a cliff. While sailboat leaving. ASCII Art." )
# 10C
prompts+=( "anime,ghibli,1girl,cat,bus,Tokyo, street" )
# 10D
prompts+=( "1970s style woman drinking Coca-Cola. Advertising poster" )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
