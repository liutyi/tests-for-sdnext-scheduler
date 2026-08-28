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
# Theme: Amber and Navy — selective color pencil noir illustrations
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+9+-+Amber+and+Navy
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — Rain-soaked alley detective
prompts+=( "Selective color pencil drawing, noir style. A lone detective in a trench coat stands beneath a flickering streetlamp in a rain-soaked alley. Dominant palette: deep charcoal black with dense hatching and cross-hatching pencil strokes. Selective color: the streetlamp glow rendered in neon amber (#FFB347), casting amber wet reflections on cobblestones. The detective's coat collar selectively tinted in dark navy blue (#1A2A4A). All other elements remain in black graphite pencil texture. Atmosphere: moody, high-contrast, cinematic shadow. No color except selective navy and neon amber highlights. Pencil illustration aesthetic, detailed linework." )

# 02 — Jazz club smoke & saxophone
prompts+=( "Selective color pencil illustration, noir aesthetic. A saxophonist performs on a dimly lit jazz club stage, cigarette smoke curling upward. Artwork executed in dense graphite-black pencil hatching with visible paper grain texture. Selective color applied only to: the saxophone surface and bell in neon amber (#FFAA33) with metallic reflective sheen, the smoke wisps rendered in dark navy blue (#0D1B3E). All background figures, brick walls, bar counter remain strict black-and-white pencil drawing. High-contrast noir lighting, expressionistic shadow play, cinematic crop at mid-torso." )

# 03 — Femme fatale window silhouette
prompts+=( "Selective color noir pencil art. A woman in 1940s dress stands backlit by a rain-streaked window, face half in shadow. Rendered entirely in black charcoal pencil with raw cross-hatch texture and deep vignette shadows. Selective color: her lips and the single rose she holds are neon amber (#FF9D2F), luminous against the black. The window frame and curtain edges selectively tinted in dark navy (#162447). No other color present. Strong chiaroscuro contrast, film noir composition, vertical format portrait. Illustrated pencil-drawing style, not photographic." )

# 04 — Midnight rooftop city panorama
prompts+=( "Selective color pencil drawing, noir urban scene. Wide-angle view from a rain-slicked rooftop overlooking a 1940s city skyline at midnight. Art style: detailed architectural pencil hatching in black, with sharp line perspective and textured shadow gradients. Selective color elements: distant neon signs and window lights rendered in neon amber (#FFA724) scattered across the skyline, the water tower silhouette and fire escapes selectively colored in deep navy (#0E1B35). Sky and streets remain pure black pencil with white highlights only. Cinematic, melancholy, vast shadow play. Pencil illustration aesthetic." )

# 05 — Poker table tension close-up
prompts+=( "Selective color noir pencil illustration. Extreme close-up over a poker table: two pairs of hands, cards facedown, a revolver beside a stack of chips, whiskey glass on felt. Full image in black pencil — dense hatching, sharp linework, dramatic top-down lighting creating deep shadows. Selective color: the whiskey in the glass glows neon amber (#FFB020), and the gun barrel and watch face shimmer in dark navy (#1C2B4A). Playing card edges catch a faint amber highlight. Everything else strictly black-and-white pencil texture. Tense, cinematic, crime noir mood." )

# --- Gemini ---

# 06 — The Rainy Street Detective
prompts+=( "A gritty, atmospheric graphite pencil drawing in the noir style. A weary detective in a heavy trench coat and fedora walks alone on a rain-soaked, dark city street at night. The scene is dominated by deep black and grey cross-hatching and shading. The pavement is wet, reflecting the urban landscape. The detective's coat and fedora are heavy graphite, but he wears a subtle, deep navy blue tie. Above him, a single, flickering streetlamp casts a harsh, vibrant neon amber glow onto the wet pavement and the detective's shoulder. A distant, blurred neon sign glows with neon amber light through the texture of the graphite rain. High contrast, sharp detail, traditional pencil texture, film grain, mysterious atmosphere." )

# 07 — The Alley Meeting
prompts+=( "A raw, charcoal and pencil sketch noir scene set in a dark, narrow urban alleyway. Two shadowy figures stand amidst heavy graphite shading and textured brick walls. One figure is silhouetted, handing a small object to another man. The main scene is grayscale, heavy with shadows. A distinct navy blue line traces the collar of one man's coat and the strap of a navy blue satchel he carries. In the background, a distant streetlamp glows with intense, pulsating neon amber, illuminating the gritty textures of the wet alley and the figures' profiles with sharp, neon amber highlights. The tip of a lit cigarette also glows neon amber. Gritty texture, high contrast, cinematic composition." )

# 08 — The Femme Fatale in the Club
prompts+=( "A detailed pencil and ink drawing in the dramatic noir style, depicting a mysterious woman seated at a dark table in a smoky nightclub. The image is mostly black and white with heavy cross-hatching defining the shadows, the smoke, and the texture of her dress. She wears a dark gown rendered in deep graphite with accents of deep navy blue on her silk scarf and her gloves. Her gaze is sharp. A specific, intense neon amber glow emanates from a lit cigarette she holds, casting light onto her face. Behind her, a blurry, textured neon sign 'JAZZ' glows with vibrant neon amber light through the atmosphere. The entire composition has the rich, tactile feel of a graphite drawing with sharp, glowing selective color." )

# 09 — The Stakeout Silhouette
prompts+=( "A minimalist, high-contrast noir graphite pencil drawing. A detective's silhouette is framed perfectly against a grimy window in a dark apartment. The detective is a solid block of heavy graphite texture, looking out over a dark cityscape at night. The window frame and the messy room are detailed pencil work. Through the rain-streaked glass, the chaotic, dark city is rendered in graphite, but selective neon amber lights from distant buildings, cars, and signs puncture the darkness, creating glowing trails on the wet glass. The detective wears a dark suit, and a subtle navy blue pen is visible in his pocket. The focus is on the silhouette and the stark, neon amber lights of the urban sprawl. Gritty, moody texture." )

# 10 — The Office Interrogation
prompts+=( "A raw, dramatic noir scene in a cluttered detective's office. A suspect sits under a single, harsh hanging bulb and a weary detective leans across a desk. The scene is heavy with graphite shading, casting deep shadows across their faces and the messy room full of files. The main composition is black and white pencil. Selective color is applied sparingly: the detective's entire worn navy blue tie stands out against the dark suit. The lightbulb overhead casts a sharp, pulsating, vibrant neon amber glow directly onto the file papers and the suspect's hands on the desk, defining the texture of the paper and the tension in the room. Heavy graphite lines, textural shading, suspenseful lighting." )

# --- ChatGPT ---

# 11 — Neon Crosswalk Rain
prompts+=( "cinematic rainy city crosswalk at night, lone pedestrian with umbrella walking through glowing reflections, streetlights and signage emitting neon amber light, deep navy shadows instead of pure black, selective color palette (black, dark navy blue, neon amber), highly detailed pencil drawing, crosshatching and ink linework, textured paper grain, reflections shimmering on wet asphalt, moody noir atmosphere, graphic novel composition, soft fog, dramatic lighting" )

# 12 — Night Bus Interior
prompts+=( "interior of a late-night city bus, passengers sitting in silence, faces partially obscured by shadow, neon amber lights reflecting in windows, outside city blurred in rain, deep navy interior shadows, minimal palette (black, navy blue, neon amber highlights), ultra-detailed graphite and ink drawing, crosshatched shading, cinematic framing, melancholic mood, hand-drawn illustration style, subtle glow effects" )

# 13 — Rooftop Signal Tower
prompts+=( "solitary figure standing near a rooftop antenna tower, cables and structures silhouetted against dark sky, distant city lights glowing neon amber, sky rendered in deep navy tones, strong wind and light rain, minimal palette (black, navy, neon amber), highly detailed pencil sketch with ink outlines, heavy crosshatching, dramatic perspective, noir cyberpunk atmosphere, textured paper, cinematic wide shot" )

# 14 — Alley with Vending Machine
prompts+=( "narrow urban alley, single vending machine glowing neon amber, casting light onto wet pavement, surrounding environment swallowed in deep navy shadows, pipes, cables, and signage barely visible, minimal palette (black, navy blue, neon amber), detailed pencil and ink illustration, crosshatching, high contrast but with subtle gradients, cinematic composition, moody and quiet atmosphere" )

# 15 — Elevated Train Passing
prompts+=( "elevated train passing through dense city at night, windows glowing neon amber, tracks and buildings fading into deep navy darkness, rain streaks visible in air, reflections below, minimal palette (black, navy, neon amber accents), ultra-detailed graphite drawing, strong ink outlines, crosshatched shading, cinematic perspective, dystopian noir mood, graphic novel storyboard style" )

# --- Grok ---

# 16 — Detective in rainy alley
prompts+=( "A brooding 1940s noir detective standing in a dark rainy alley at night, wearing a fedora and trench coat, cigarette smoke curling upward, one hand holding a revolver. Selective color pencil drawing, heavy black graphite shading and cross-hatching, dramatic high-contrast chiaroscuro lighting, only selective navy blue for the coat and neon amber glowing from the cigarette tip and distant neon sign, mysterious and cinematic atmosphere, intricate pencil texture, sharp lines, deep blacks --stylize 750" )

# 17 — Femme fatale at bar
prompts+=( "Femme fatale in a dimly lit 1940s bar, elegant black dress with navy accents, leaning against the counter, seductive gaze toward viewer, smoke-filled room, jazz musician silhouette in background. Noir selective color pencil sketch, masterful black graphite tones, deep shadows, only selective navy for her dress and eyes, neon amber highlights on lips, glass, and whiskey reflection, moody cinematic lighting, detailed pencil strokes --stylize 650" )

# 18 — Rain-slicked street, neon sign
prompts+=( "Rain-slicked nocturnal city street in classic film noir style, lone figure in trench coat and hat walking under a flickering neon sign, reflections on wet pavement. Selective color pencil drawing, dominant rich black graphite with heavy shading, selective navy for the night sky and coat, vibrant neon amber for the glowing sign and its reflections, dramatic contrast, atmospheric fog, intricate pencil texture, high detail --stylize 800" )

# 19 — Detective at desk, lamp
prompts+=( "Hard-boiled detective sitting at a wooden desk in a shadowy office, single desk lamp casting harsh light, revolver and scattered case files, blinds casting striped shadows. Noir selective color pencil illustration, deep black graphite dominance, selective navy blue for the suit and shadows, neon amber glow only on the lamp bulb and scattered papers, tense mysterious mood, ultra-detailed pencil rendering, strong chiaroscuro --stylize 700" )

# 20 — Woman under streetlamp
prompts+=( "Beautiful woman in a navy evening gown standing under a streetlamp on a foggy noir street corner at night, dramatic rim lighting, mysterious and dangerous aura. Selective color pencil drawing, masterful black graphite shading with rich texture, only selective navy for the dress and fog, glowing neon amber for the streetlamp and highlights on her face and hair, cinematic composition, high contrast, intricate pencil work --stylize 750" )

# --- Qwen 3.6 Plus ---

# 21 — Rain-Soaked Alley Detective
prompts+=( "A film noir scene rendered as a selective color pencil drawing on textured sketch paper. A lone detective in a trench coat and fedora stands under a flickering streetlamp on a rain-slicked cobblestone alley. The entire composition is meticulously drawn in black graphite and charcoal, with dramatic chiaroscuro lighting and visible crosshatching. Strictly monochrome except for two selective accents: a deep navy blue umbrella puddle reflecting the street, and a glowing neon amber sign in the background casting a warm rim light. High contrast, moody atmosphere, hand-drawn pencil texture, cinematic framing." )

# 22 — Pier & Vintage Sedan
prompts+=( "Selective color pencil illustration of a classic 1940s sedan parked beside a foggy waterfront pier at midnight. Rendered primarily in black and gray graphite with strong noir-inspired shadows, stippling, and directional hatching. A solitary figure leans against the car door, blending into the darkness. Only two colored pencil accents are applied: a rich navy blue overcoat draped over the figure's shoulders, and a neon amber headlight beam cutting through the mist. Textured paper grain, precise pencil lines, isolated color technique, high-contrast noir lighting." )

# 23 — Venetian Blinds Office
prompts+=( "A noir-style interior depicted as a selective color pencil drawing. A cluttered detective's desk under a dim brass lamp, with venetian blinds casting sharp, diagonal shadow stripes across the wall and floor. The artwork is executed entirely in black graphite pencil with heavy shading, smudged gradients, and visible pencil strokes. Selective color accents are strictly limited to: a navy blue case file lying open on the desk, and a neon amber coffee cup catching the lamplight. Dramatic contrast, film noir mood, traditional illustration style, atmospheric depth." )

# 24 — Neon Reflection Puddle
prompts+=( "A moody urban alleyway at night, drawn in a selective color pencil technique. Tall brick buildings loom in heavy black charcoal and graphite, with rain-soaked pavement reflecting dramatic light. A figure walks away into the distance, their long coat rendered in deep navy blue pencil. Above, a flickering neon amber 'OPEN' sign casts a warm, isolated glow that reflects precisely in a single puddle. The rest of the scene remains strictly monochrome. Visible pencil texture, stark noir contrast, cinematic perspective, hand-illustrated selective color style." )

# 25 — Noir Portrait Close-Up
prompts+=( "A close-up film noir portrait executed as a selective color pencil drawing on rough sketch paper. A figure's face emerges from deep shadows, illuminated by harsh side lighting that emphasizes sharp cheekbones and smoky eyes. The entire piece is drawn in black and gray graphite, with meticulous crosshatching and blending. Selective color highlights include a navy blue silk scarf draped around the neck and the neon amber glow of a cigarette ember between the fingers. High contrast, moody atmosphere, traditional pencil medium, isolated color accents, cinematic composition." )

# --- GLM 5.1 ---

# 26 — The Rain-Slicked Alley
prompts+=( "Noir style selective color pencil drawing on textured sketch paper. A solitary detective in a trench coat standing in a rain-drenched alleyway. The entire image is rendered in heavy black graphite and charcoal pencil with visible cross-hatching and rough strokes. Selective color accents only: deep navy blue reflecting in the rain puddles and staining the shadows of the brick walls, and vivid neon amber spilling from a flickering streetlamp, casting long dramatic shadows. No other colors. Cinematic chiaroscuro, gritty pulp fiction aesthetic, highly detailed pencil grain." )

# 27 — The Femme Fatale
prompts+=( "Noir style selective color pencil drawing, intricate line work and scribbled shading. A femme fatale sitting at a dimly lit bar, holding a cocktail glass. The base drawing is pure black colored pencil on off-white paper. Strict selective color palette: her form-fitting dress is rendered in a rich, deep navy blue, and the neon amber glow of a distant sign reflects off the glass and illuminates a wisp of her cigarette smoke. High contrast, moody atmosphere, thick pencil textures, masterpiece draftsmanship." )

# 28 — The Getaway Car
prompts+=( "Noir style selective color pencil drawing, striking use of black shading with stippling and hatching techniques. A vintage 1940s sedan parked on a dark, misty street. The entire scene is drawn in intense black pencil. Selective colors only: a moody navy blue tinting the distant rainy city skyline and the dark metal of the car's fender, contrasted by piercing neon amber headlights cutting through the fog and reflecting on the slick asphalt. Dramatic lighting, tense atmosphere, purely monochromatic except for the navy and amber elements." )

# 29 — The Informant
prompts+=( "Noir style selective color pencil drawing, raw and gritty pencil strokes. A shadowy informant leaning under a wrought-iron fire escape in a dark alley. The composition relies on deep, inky black pencil shading. Strict selective color application: the iron shadows and the informant's jacket are washed in deep navy blue, while the glowing ember of his cigarette and a sliver of light from a cracked doorway are rendered in vibrant neon amber. Pulp noir lighting, textured paper background, sketch-like yet deeply atmospheric." )

# 30 — The Detective's Desk
prompts+=( "Noir style selective color pencil drawing, detailed monochromatic black sketch base with vibrant selective coloring. A cluttered detective's desk featuring a rotary phone, a half-empty whiskey glass, and a revolver. The entire sketch is drawn with heavy black pencil pressure and fine line work. Selective colors: a fedora hat resting on the desk dyed in deep navy blue, and the harsh, warm light from a single desk lamp casting a neon amber glow over the paperwork and the gun. Dramatic shadows, cinematic noir framing, visible pencil grain and cross-hatching." )

# --- Kimi K2.6 Thinking ---

# 31 — The Alley Informant
prompts+=( "Noir selective-color pencil sketch, heavy black graphite shading dominating the composition, a rain-soaked 1940s alleyway at midnight, trench-coated silhouette leaning against wet brick walls, face hidden in deep black shadow, only selective neon amber light from a single flickering streetlamp cuts through the darkness, reflecting in oily puddles as sharp amber pools, distant window glows rendered in muted navy blue, visible pencil stroke texture, rough crosshatching for shadows, hand-drawn grain, cinematic noir atmosphere, high contrast, limited palette of black graphite, neon amber, and midnight navy only" )

# 32 — The Jazz Club Saxophonist
prompts+=( "Selective color pencil drawing in noir style, black charcoal and graphite base filling 80% of the frame, a lone saxophone player on a smoky stage, body and background sketched in deep black pencil strokes with visible paper texture, only the saxophone bell and spotlight rendered in glowing neon amber, wisps of cigarette smoke picked out in faint navy blue hatching, the audience swallowed in pitch black negative space, dramatic chiaroscuro lighting, rough sketch lines, smudged graphite shadows, hand-drawn aesthetic, limited to black, electric amber, and dark navy accents" )

# 33 — The Venetian Blind Interrogation
prompts+=( "Noir pencil illustration with selective color, stark black graphite rendering of a dim interrogation room, venetian blinds casting prison-bar shadows across the scene in harsh black strokes, a figure sitting under a single hanging bulb, the bulb's filament and light pool drawn in piercing neon amber, the subject's eyes reflected with tiny navy blue highlights, dust motes floating in the amber light beam sketched with fine navy pencil lines, heavy impasto-like graphite texture, rough tooth of the paper visible, 1950s detective aesthetic, monochrome black base with only amber and navy as permitted colors" )

# 34 — The Midnight Train Platform
prompts+=( "Selective-color noir sketch, black pencil and ink wash creating a vast empty train station at 3 AM, architecture and fog rendered in dense black graphite with aggressive shading, a single departing train visible only by its windows glowing in warm neon amber, platform edge safety lines drawn in crisp navy blue, a solitary woman's silhouette in the distance with her cigarette tip as a tiny amber ember, wet concrete reflections showing navy-blue ghost echoes of the amber lights, visible sketch construction lines, rough hatching technique, hand-drawn grain, melancholic noir mood, strictly limited palette: black, neon amber, navy" )

# 35 — The Private Eye's Desk
prompts+=( "Noir graphite pencil drawing with selective color accents, overhead view of a cluttered 1940s detective desk, 90% pure black pencil shading and crosshatching creating deep shadows, only three elements in color: a half-empty whiskey glass catching amber neon sign light from the window in glowing gold-amber, a case file stamped 'CONFIDENTIAL' with navy blue ink, and the cherry tip of a cigarette in an ashtray burning neon amber, everything else consumed by black graphite darkness including the sleeping city outside, visible pencil strokes, sketchy unfinished edges, paper texture, film noir lighting, palette restricted to charcoal black, neon amber, and stamp-navy only" )

# --- Deepseek ---

# 36 — The Docks at Midnight
prompts+=( "A noir style selective color pencil drawing. Predominantly black pencil shading with deep navy tones in the rain-soaked sky and wet dock planks. Selective neon amber highlights on a single streetlamp's glow and its reflection on the water. A trench-coated detective's silhouette stands under the lamp, holding a collar up. Soft pencil texture, high contrast, moody atmosphere, limited to black, navy, and neon amber." )

# 37 — The Jazz Club Interior
prompts+=( "Selective color pencil drawing in noir style. Black pencil defines the crowded club, piano, and seated figures. Navy fills the shadows in the corners and the smoke-filled air. Neon amber illuminates only the trumpet of a solo player on stage, the rim of a cocktail glass, and a woman's cigarette tip. Rough pencil strokes, dramatic chiaroscuro, color palette restricted to black, navy, and neon amber." )

# 38 — The Neon Crosswalk
prompts+=( "Noir selective color pencil illustration. Black pencil for the wet city street, towering skyscrapers, and a lone figure crossing. Navy is used for the dark reflections on the asphalt and a distant police car. Neon amber as the key selective color, drawing a glowing crosswalk signal, the horizontal bars of a pedestrian sign, and thin window lines in a skyscraper. Heavy black outlines, subtle blending, limited palette: black, navy, neon amber." )

# 39 — The Private Eye's Office
prompts+=( "selective color pencil drawing, noir style. Mostly black pencil for the desk, venetian blinds casting stripes, and a fedora on a stand. Navy in the deep shadows under the desk and outside the window. Neon amber selectively on a desk lamp's bulb, the tip of a lit match, and the glowing dial of a wall clock. Dry pencil texture, high contrast, moody, colors only black, navy, and neon amber." )

# 40 — The Train Platform at 3 AM
prompts+=( "Noir style selective color pencil drawing. Black pencil dominant for the empty platform, iron pillars, and a lone suitcase. Navy for the steam rising from a waiting locomotive and the distant tunnel. Neon amber as the accent color on a single signal light, the headlamp of the train, and a pocket watch dangling from a gloved hand. Rough paper texture, atmospheric perspective, color palette limited exclusively to black, navy, and neon amber." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
