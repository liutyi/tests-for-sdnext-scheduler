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
# Theme: Striped off-centered double exposure — person and city
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+13+-+striped+double+exposure
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — Ghost Frequency
prompts+=( "Off-centered double exposure portrait: a young woman's silhouette drifts to the left third of the frame, dissolving into a dense vertical-stripe pattern — alternating translucent bands of cool dusk cityscape (Tokyo neon reflections, elevated highways) and dark negative space. Her face materializes only where the stripes are widest, the city bleeding through her cheekbones and closed eyes. The right half of the frame is near-empty shadow. Analog film grain, muted teal and amber palette, cinematic 35mm, dreamlike tension between presence and erasure." )

# 02 — Urban Dissolution
prompts+=( "Double exposure editorial photograph: a male figure positioned off-center to the upper right, his form built from horizontal stripe layers — each stripe an aerial shot of a brutalist city at blue hour, intersected with thin black voids. The bottom-left of the image fades into raw white, unanchored. Face dissolves into a grid of windows and rooftops, jacket merging with overpass geometry. Stark, architectural minimalism. Monochromatic with single accent: deep indigo. High contrast, sharp stripe edges, fine art photography aesthetic." )

# 03 — Fractured Self
prompts+=( "Artistic double exposure with irregular diagonal stripe mask: a person's profile (facing left, off-center, cropped asymmetrically) intersected by bold diagonal bands of varying width — inside each band, a different urban fragment: rainy street puddles, fire escape ladders, graffiti walls, blurred subway lights. Bands alternate between city imagery and deep black. Background fades to pale warm grey. The figure feels assembled from city memory. Painterly post-processing, slight halation on light sources, muted desaturated film look with warm shadows." )

# 04 — Light Interval
prompts+=( "Minimalist double exposure: a standing figure rendered in glitching vertical scan-line stripes, pushed far to the right edge of the frame, nearly cropped. Inside each stripe: fragments of a foggy European city at dawn — cobblestones, iron lamp posts, cathedral silhouettes. Stripes vary rhythmically from razor-thin to broad, creating a music-score visual rhythm. The wider stripes glow softly amber, thin ones are black voids. Left two-thirds of frame: empty pale silver. Overall atmosphere: silence, solitude, winter morning. Shot on large format, tonal precision, no saturation." )

# 05 — Chroma Interrupt
prompts+=( "Vibrant double exposure with vertical RGB stripe interference: a dancer mid-motion, upper body only, off-centered to the bottom-left quadrant, overlaid with city traffic light trails in a vertical stripe pattern using cyan, magenta, and yellow bands — color-separated like a misaligned print. The city layer (long-exposure night street photography) bleeds through the figure unevenly: some stripes oversaturate, others drop to near-black. Top-right quadrant: pure white. Avant-garde fashion editorial look, chromatic aberration on edges, controlled chaos, bold graphic impact." )

# --- Gemini 3.1 Pro ---

# 06 — The Noir Silhouette
prompts+=( "A highly artistic, off-centered double exposure. The composition is pushed completely to the right third of the frame, leaving stark negative space on the left. Alternating vertical masking stripes seamlessly slice between two images: a high-contrast black-and-white silhouette of a man in a heavy trench coat, and a glowing amber cityscape of a rainy metropolis at night. Film noir aesthetic, sharp aggressive pencil sketch textures blending into photorealism, cinematic volumetric lighting, masterpiece." )

# 07 — Modern-Ethnic Tapestry
prompts+=( "An elegant, off-centered double exposure portrait of a woman wearing modern-ethnic fashion with intricate traditional embroidery. She is positioned asymmetrically on the left edge. Horizontal fragmented stripes act as a double exposure mask, revealing the sweeping historic skyline of Kyiv at twilight within the alternating bands. Soft glowing neon lighting, high-end editorial photography, delicate charcoal shading, intricate architectural details, ethereal and artistic composition." )

# 08 — Neon Geometric Slices
prompts+=( "A creative double exposure composed of sharp diagonal stripes. The alternating diagonal bands mask an off-centered, close-up profile of an intense cyberpunk youth, and a sprawling, hyper-detailed neon cityscape. The subject is framed far to the left with heavy dark space on the right. Vivid holographic magenta and cyan color palette, sharp geometric masking lines, 8k resolution, ray-traced reflections, futuristic aesthetic." )

# 09 — The Ethereal Watercolor
prompts+=( "A dreamy, asymmetrical double exposure. Wavy, organic vertical stripes blend two distinct layers: a soft, pastel watercolor portrait of a contemplative woman looking away, and the dense, towering skyscrapers of New York City emerging through morning fog. The composition is heavily off-centered to the right. Delicate brushstrokes, muted color grading, surreal atmosphere, masterpiece, fine art photography." )

# 10 — Venetian Shadow Play
prompts+=( "A moody, artistic double exposure using heavy, striped shadows from Venetian blinds to create the masking effect. The off-centered composition features a fashion model's face on the far left, intersecting seamlessly with the illuminated, rainy streets of London at night. Deep cinematic shadows, rich volumetric lighting, a blend of photorealism and aggressive charcoal texture in the darker regions, cinematic aspect ratio." )

# --- ChatGPT ---

# 11 — Vertical Strip Fragmentation Portrait
prompts+=( "Double exposure portrait of a contemplative person, off-centered composition (subject placed on far left third), fragmented into vertical stripes of varying widths. Each stripe reveals alternating layers of a dense neon-lit city at night — glowing signage, traffic trails, wet asphalt reflections. Subtle misalignment between stripes creates a glitch-like displacement effect. Soft cinematic lighting on the face, shallow depth of field, high contrast between warm neon reds and cold cyan blues, fine grain, moody atmosphere, ultra-detailed, artistic editorial photography style." )

# 12 — Minimalist Daylight Architectural Overlay
prompts+=( "Off-centered double exposure of a standing figure facing away, positioned on the right edge of the frame, with clean vertical stripe masking. Inside the stripes: bright modern city architecture, glass facades, geometric shadows, sunlight reflections. Outside stripes: soft neutral background with negative space. Stripes partially shifted to create rhythm and asymmetry. Color palette: white, pale concrete, steel blue accents. Minimalist, high-key lighting, crisp details, contemporary art gallery aesthetic." )

# 13 — Motion Blur Urban Pulse
prompts+=( "Dynamic double exposure of a walking figure, heavily off-centered (lower-left corner), body sliced into thin vertical strips. Within strips: long exposure city motion — blurred crowds, streaking headlights, metro movement. Slight horizontal offset between strips creates kinetic energy and visual vibration. Background fades into darkness. Color palette: amber, electric blue, deep black. Cinematic motion blur, high detail, atmospheric haze, modern urban surrealism." )

# 14 — Noir Silhouette with Selective Light Stripes
prompts+=( "High-contrast noir double exposure of a silhouette figure, placed off-center to the right, broken into bold vertical stripe segments. Inside stripes: rainy nighttime city — streetlights, reflections on pavement, faint fog. Outside stripes: deep matte black. Stripes subtly uneven and imperfect for organic feel. Selective color accents: 5–10% muted gold and dim red. Film grain, chiaroscuro lighting, dramatic shadows, fine art noir photography style." )

# 15 — Surreal Elevated City Within Figure
prompts+=( "Artistic double exposure of a seated person, off-centered top-left composition, fragmented into wide and narrow vertical bands. Inside bands: surreal elevated cityscape — floating buildings, impossible perspectives, layered skylines fading into clouds. Slight vertical misregistration between bands adds dreamlike distortion. Soft diffused lighting, pastel and steel tones with subtle glow. Painterly realism mixed with photographic detail, ethereal, poetic, gallery-quality composition." )

# --- Grok ---

# 16 — Neon Nocturne
prompts+=( "A haunting off-centered double exposure of a mysterious woman in a flowing striped coat, her silhouette merging with a vibrant nocturnal cyberpunk cityscape, vertical light streaks and striped glitch patterns blending her figure into glowing skyscrapers and wet reflective streets, one side of the image dominated by deep indigo shadows, the other by electric magenta and cyan neon, cinematic color grading, film grain, moody atmospheric fog, surreal yet elegant, high contrast, masterpiece, 8k." )

# 17 — Golden Hour Reverie
prompts+=( "Artistic off-centered double exposure portrait of a young man with flowing hair, his transparent striped form dissolving into a golden sunset metropolis, warm amber light piercing through buildings and his body in elegant striped bands of light and shadow, dramatic diagonal composition with negative space on the left, soft bokeh city lights, cinematic volumetric god rays, ethereal and melancholic atmosphere, shot on 35mm film, delicate grain, masterpiece, hyper aesthetic." )

# 18 — Rain-Streaked Melancholy
prompts+=( "Moody cinematic double exposure of a solitary figure in a striped trench coat standing off-center, their body and face beautifully interwoven with a rainy futuristic city at dusk, vertical rain streaks merging with striped light reflections on glass towers, cool teal and deep purple color palette, water droplets suspended in air, emotional and introspective, wet asphalt reflections, fog, anamorphic lens flare, photographic art, ultra-detailed, atmospheric masterpiece." )

# 19 — Surreal Vintage Dream
prompts+=( "Surreal vintage-style off-centered double exposure, a graceful dancer in a flowing striped dress merged with a 1930s art-deco city at twilight, her movement creating striped motion trails that blend into geometric skyscrapers and glowing windows, sepia tones mixed with subtle teal highlights, elegant film grain, off-kilter composition with vast empty dramatic sky on one side, dreamy and nostalgic, analog photography aesthetic, exquisite detail, artistic masterpiece." )

# 20 — Abstract Cosmic Fusion
prompts+=( "Highly artistic abstract double exposure, an androgynous person made of striped light and shadow, dramatically off-centered, their form exploding into a dense futuristic megacity that blends into starry cosmic nebulae, vertical striped interference patterns creating a hypnotic moiré effect between human silhouette and glowing architecture, deep midnight palette with vibrant electric accents, surreal dream logic, intricate details, otherworldly beauty, conceptual fine art photography, ultra premium quality, visionary." )

# --- Qwen 3.6 Plus ---

# 21 — Neon Noir Rhythm
prompts+=( "A cinematic double exposure of a solitary figure in a long coat standing in profile, positioned off-center to the right. Through alternating horizontal translucent stripes, a rain-drenched cyberpunk cityscape bleeds into the silhouette, revealing neon signs, wet asphalt, and distant skyscrapers. The stripes vary in opacity, creating a rhythmic visual pulse. Dramatic chiaroscuro lighting, deep teals and warm amber accents, fine photographic grain, asymmetrical composition with generous negative space on the left. Shot on 35mm lens, high contrast, editorial double exposure technique, photorealistic, museum-quality aesthetic." )

# 22 — Geographic Abstraction
prompts+=( "A contemporary artistic double exposure featuring a minimalist portrait of a person facing slightly downward, placed deliberately off-center toward the bottom-left corner. Diagonal translucent stripes slice across the frame, revealing a geometric bird's-eye view of a sprawling metropolis within the figure's contours. The city grid aligns with the stripe angles, creating optical rhythm. Limited color palette: cool greys, crisp whites, with a single accent of deep crimson. Clean edges mixed with subtle photographic grain, Bauhaus-inspired composition, high-end graphic design aesthetic, precise masking, studio lighting, ultra-detailed rendering." )

# 23 — Watercolor Metropolis
prompts+=( "An ethereal double exposure of a person with eyes gently closed, positioned off-center along the upper-right third of the frame. Soft, irregular wavy stripes act as windows into a sun-drenched coastal city at golden hour, where terracotta rooftops, winding streets, and distant ocean horizons melt into the silhouette. The stripes fade in and out like watercolor washes, creating dreamlike layered transparency. Warm peach, lavender, and dusty gold tones, soft diffused lighting, fine art photography style with subtle painterly texture, asymmetrical balance, poetic composition, gallery print aesthetic." )

# 24 — Architectural Alignment
prompts+=( "A striking double exposure portrait of a sharply dressed individual leaning against a concrete wall, placed off-center to the left. Bold vertical stripes reveal a towering modern cityscape within their form — glass facades, steel beams, and intersecting pedestrian bridges align perfectly with the stripe rhythm. High-contrast black and white with a single muted copper highlight on the subject's shoulder. Architectural precision meets human silhouette, dramatic sidelighting, long shadows, graphic negative space on the right, contemporary editorial style, photorealistic double exposure with intentional off-axis composition, 4K detail." )

# 25 — Urban Motion Trails
prompts+=( "A dynamic double exposure capturing a figure mid-stride, positioned off-center toward the bottom-right. Curved, sweeping stripes flow across the composition, acting as luminous channels that reveal a long-exposure cityscape: streaks of taillights, glowing subway windows, and blurred skyscraper silhouettes blend seamlessly into the subject's moving form. The stripes mimic motion trails, creating a sense of rhythm and urban pulse. Cool cyan and magenta color grading, subtle lens flare, cinematic depth of field, contemporary digital art meets fine art photography, asymmetric framing with intentional visual tension, high-resolution rendering." )

# --- GLM 5.1 ---

# 26 — Cyberpunk Neon Slicing
prompts+=( "Artistic double exposure portrait of a young woman in profile, positioned off-center to the left third of the frame, seamlessly blended with a futuristic neon-lit cityscape. The entire composition is fragmented by rhythmic, alternating vertical stripes, where some stripes reveal the glowing magenta and cyan skyscrapers and flying cars, and others reveal the translucent contours of her face. Cinematic lighting, high contrast, translucent overlapping layers, cyberpunk aesthetic, graphic novel style, masterpiece." )

# 27 — Golden Hour Diagonal Fractures
prompts+=( "Aesthetic off-centered double exposure featuring a contemplative man looking downward, placed on the right side of the frame, overlaid with a sprawling vintage European city at golden hour. The image is visually sliced by wide, diagonal, semi-transparent stripes, blending the warm sunlit architecture, terracotta roofs, and cobblestone streets into his silhouette. Ethereal atmosphere, amber and teal color grading, nostalgic film photography aesthetic, soft film grain, poetic and artistic." )

# 28 — Bauhaus Monochrome Horizontals
prompts+=( "Minimalist and artistic double exposure blending a female silhouette and a dense modern metropolis. The subject is off-centered, shifted towards the bottom right. The visual is fractured by stark, horizontal rectangular stripes of varying widths, where alternating bands show the textured concrete skyline and the smooth portrait. Monochromatic, dramatic chiaroscuro, Bauhaus geometric aesthetic, sharp lines, atmospheric smoke, high fashion editorial style." )

# 29 — Surreal Pastel Ribbons
prompts+=( "Surreal and dreamy double exposure artwork of a dancer mid-pose, positioned off-center to the upper left, merged with a fantasy city of glass towers and floating islands. The composition is divided by soft, uneven vertical stripes that ripple across the frame like ribbons, interlacing the pastel pink, lavender, and mint green cityscapes with her translucent form. Ethereal lighting, soft bokeh, watercolor and digital art hybrid, delicate, mesmerizing, beautiful composition." )

# 30 — Noir Film Strip Split
prompts+=( "Cinematic double exposure portrait of a rugged figure wearing a trench coat and fedora, placed off-center to the left, superimposed over a rain-slicked 1940s noir city street. The image is split by a stark, off-center vertical stripe of negative space, acting like a film strip separation, isolating yet blending the glowing streetlamps and dark alleys with the subject's silhouette. Deep shadows, heavy film grain, silver halide aesthetic, moody, atmospheric, vintage detective noir." )

# --- Kimi K2.6 Thinking ---

# 31 — Noir Cinematic
prompts+=( "Double exposure portrait, off-centered composition, a woman's profile silhouetted against rain-soaked neon city streets, bold diagonal black and white stripes cutting across the frame, high contrast chiaroscuro lighting, film noir aesthetic, grainy analog texture, cinematic mood, the city lights leak through her hair like fragmented memories, asymmetric framing, 35mm film look, deep shadows, moody atmosphere." )

# 32 — Ethereal Pastel Surrealism
prompts+=( "Dreamy double exposure, off-centered to the left, soft-focus portrait of a young man overlaid with pastel-colored city architecture, vertical translucent stripes in blush pink and pale mint drifting across the image, golden hour light bleeding through skyscrapers, ethereal haze, surrealist art style, delicate light leaks, soft bokeh, romantic melancholy, asymmetrical balance, fine art photography aesthetic, painterly textures." )

# 33 — Cyberpunk Glitch
prompts+=( "Striking double exposure, subject positioned off-center following rule of thirds, cyberpunk cityscape merging with a woman's face, horizontal digital stripes in electric blue and magenta slicing through the composition, holographic light trails, rainy rooftop reflections embedded in her features, futuristic neon aesthetic, glitch art undertones, high-tech dystopian mood, sharp geometric contrast, vibrant saturated colors, cinematic cyber-noir." )

# 34 — Vintage Analog Memory
prompts+=( "Artistic double exposure, intentionally off-centered, aged film aesthetic, side-profile of an elderly man fused with 1970s brutalist city towers, warm sepia and amber stripes radiating from the corner like sun flare, dust scratches and film grain texture, nostalgic melancholy, soft vignette, asymmetric vintage postcard composition, memory-like fading edges, documentary photography style, timeless emotional resonance." )

# 35 — Abstract Geometric Minimalism
prompts+=( "Avant-garde double exposure, subject placed far off-center, stark black and white, portrait of a dancer overlaid with abstract architectural city lines, bold rhythmic stripes intersecting at oblique angles, negative space emphasis, minimalist composition, Bauhaus influence, sharp shadows, geometric precision, monochrome palette with single accent of gold, contemporary fine art, gallery-quality aesthetic, elegant asymmetry, architectural deconstruction." )

# --- Deepseek ---

# 36 — Melancholy Commuter – Vertical Light Stripes
prompts+=( "Off-centered double exposure portrait of a person walking right, dissolving into a nocturnal cityscape. Vertical neon stripes (pink and cyan) cut across the right third of the image, breaking the figure into fragmented light bands. City skyline visible inside the person's silhouette. Muted teal and cold grey background. Shallow depth of field, grainy film texture. Cinematic, lonely atmosphere." )

# 37 — The Waiting One – Horizontal Shadow Stripes
prompts+=( "Artistic double exposure, off-centered to the lower left. A person sitting on a bench, torso dissolving into a sprawling city grid at dusk. Horizontal striped occlusion like venetian blind shadows falling across the upper half. Warm amber and rust orange city lights contrast with cool indigo skin tones. Slight motion blur, reflective wet pavement texture. Dreamlike, Edward Hopper mood." )

# 38 — Architecture of Memory – Cracked Stripes
prompts+=( "Off-centered double exposure — person's profile on the far right, facing left. Inside the silhouette: a dense, layered city of bridges and old apartment blocks. Three bold, uneven vertical stripes like torn film negatives run through the center, each stripe showing a different time of day (dawn, noon, night). Matte painting aesthetic, muted earth tones with one electric blue accent stripe. Surreal, poetic decay." )

# 39 — Rain Codes – Diagonal Data Stripes
prompts+=( "Off-centered double exposure of a person looking down, holding an umbrella. The city inside them is a rain-soaked Chinatown at night — lanterns, steam vents, neon reflections. Diagonal stripes of light like laser barcode or rain streaks cut from top-left to bottom-right, revealing only fragments of the person and city. High contrast black and white except for single red lantern glow. Aesthetic: cyberpunk haiku." )

# 40 — Still Life with Skyline – Negative Space Stripes
prompts+=( "Minimalist off-centered double exposure — person's head and shoulders positioned at bottom-left corner. The negative space above and right is filled with a compressed city skyline inside the figure. Three thick horizontal stripes of empty white or pale paper texture interrupt the composition like erased bands. Faint pencil-sketch lines and watercolor bleed. Artistic, gallery print aesthetic. Very high key, almost monochrome with one soft ochre touch." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
