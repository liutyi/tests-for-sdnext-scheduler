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
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+1+-+noir+surreal
# Theme: fusion of surrealism and Sin City-like noir
# 7 models × 5 prompts = 35 total
# Inline resolution tags stripped — handled globally above.
# GLM5 Chinese originals omitted; English translations used.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · The Clockmaker's Rain
prompts+=( "A towering skeletal clockmaker in a trench coat stands motionless in a flooded alley, hundreds of melting pocket watches raining from a starless sky, high-contrast black and white with only the clock faces rendered in bleeding crimson, puddles reflecting an impossible moon, Sin City graphic novel aesthetic, surrealist Dalí influence, ink-sharp shadows." )

# 02 · The Ivory Detective
prompts+=( "A femme fatale made entirely of cracked white porcelain sits at a bar of infinite length disappearing into darkness, cigarette smoke forming the silhouette of a screaming face, monochrome noir palette except for a single burning red rose on the counter, hyperrealistic textures, Frank Miller graphic composition, surreal psychological horror undertone." )

# 03 · Neon Minotaur
prompts+=( "A minotaur in a pinstripe suit leans against a graffiti-covered labyrinth wall under a dying neon sign that reads TRUTH, black and white rain-slicked street, only the neon glow rendered in electric yellow, cigar smoke curling into the shape of a maze, ultra-high-contrast chiaroscuro, Sin City cinematography meets Giorgio de Chirico metaphysical painting." )

# 04 · The Last Carnival
prompts+=( "A desolate noir carnival at 3am — carousel horses frozen mid-scream, a one-eyed fortune teller's tent with a glowing violet crystal ball the only source of light in total darkness, faceless crowds in black silhouette drifting through, ticket stubs falling like snow, hyper-graphic shadow geometry, monochrome with isolated violet accent, surreal dread, Sin City visual language." )

# 05 · The City That Breathes
prompts+=( "An aerial view of a noir city whose streets are the veins of a giant sleeping human body visible just beneath the asphalt, skyscrapers growing from rib bones, black and white with only arterial roads glowing deep arterial red, rain falling upward, one lit window in every building shaped like an eye, Magritte-influenced surrealism fused with Frank Miller Sin City composition, cinematic and unsettling." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Red Thread of Fate
prompts+=( "A hyper-stylized noir scene in the style of Frank Miller. A detective in a rain-drenched trench coat stands before a shattered mirror. Inside the mirror, his reflection is a skeleton holding a vibrant, photorealistic red rose. A single glowing red thread connects the skeleton's hand to the real detective's heart. Deep blacks, stark white highlights, heavy grain, dramatic rim lighting, surreal symbolism." )

# 07 · The Electric Smoke
prompts+=( "A femme fatale leans against a brick wall in a dark alley, rendered in high-contrast black and white graphic novel style. As she exhales cigarette smoke, the smoke transforms into a detailed, glowing neon blue cobra coiling around her. Only her lips are a deep, matte crimson. Sharp shadows, wet pavement reflections, cinematic noir atmosphere, minimalist color splash." )

# 08 · The Clockwork Shadow
prompts+=( "A man in a sharp suit walks down a lonely city street at night under a single flickering streetlamp. His shadow on the wall behind him is not a shadow, but an intricate, glowing gold clockwork mechanism with moving gears and cogs visible through the silhouette. Stark noir lighting, heavy ink textures, surreal shadowplay, Sin City aesthetic, 8k resolution." )

# 09 · Ink-Bleed Angel
prompts+=( "A surreal noir masterpiece. A woman sits on a skyscraper ledge overlooking a dark, stylized city. Her wings are made of liquid black ink that drips upward toward the moon like smoke. Her eyes are a piercing, supernatural glowing cyan. Extremely high contrast, dramatic chiaroscuro, graphic novel illustration style, moody and ethereal." )

# 10 · The Painted Escape
prompts+=( "A vintage 1940s car drives through a torrential downpour in a pitch-black city. The windshield wipers are clearing away the black and white world to reveal a vibrant, colorful tropical sunset on the glass where the rain is wiped away. Surrealist noir, high contrast, ink-heavy backgrounds, isolated color window, cinematic depth." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Rain of Memory Fragments
prompts+=( "A noir city street at night in heavy rain, high-contrast black-and-white with selective crimson accents, a lone detective in a trench coat standing under a flickering streetlamp, but instead of rain, fragmented photographs and memories fall from the sky, shards dissolving mid-air, wet pavement reflecting distorted faces, surreal atmosphere, sharp shadows, graphic novel style inspired by Sin City, cinematic framing." )

# 12 · The Woman Made of Smoke
prompts+=( "A mysterious femme fatale in a dark alley, her body partially dissolving into swirling cigarette smoke that forms ghostly faces around her, monochrome black-and-white palette with only her lips in deep red, harsh rim lighting, exaggerated noir shadows, surreal transformation, glossy wet textures, high-fashion noir editorial, ultra-detailed." )

# 13 · Infinite Staircase Interrogation
prompts+=( "A surreal interrogation room where the floor breaks into an impossible Escher-like staircase descending into darkness, two silhouetted figures facing each other across a metal table, stark overhead light casting long shadows, grayscale with a single neon green light flicker, perspective distortion, psychological tension, Sin City-style ink contrast, minimalist yet surreal." )

# 14 · City Inside the Mind
prompts+=( "A close-up noir portrait of a man, his head partially open revealing a miniature black-and-white cityscape inside, tiny cars moving and neon signs glowing in selective colors (red and yellow), rain falling both outside and inside his mind, double exposure effect, strong chiaroscuro lighting, surreal narrative symbolism, graphic novel realism." )

# 15 · The Gun That Grows Roses
prompts+=( "A stylized noir scene of a hand holding a revolver, but instead of bullets, dark roses grow out of the barrel, petals falling in slow motion, black-and-white palette with deep red petals as the only color, dramatic lighting, sharp shadows, symbolic surrealism, high contrast like Sin City, hyper-detailed textures, cinematic composition." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Surreal Noir Detective
prompts+=( "A surreal Sin City noir scene, a grim detective with a fedora standing on a melting clock tower overlooking a rain-soaked futuristic city, giant floating eyes watching from the stormy sky, heavy black and white high-contrast ink style with selective red on blood-stained lips and glowing cigarette, dramatic volumetric shadows, pouring rain, impossible architecture, ultra-detailed, cinematic masterpiece, Frank Miller meets Salvador Dalí." )

# 17 · Femme Fatale in Dream Void
prompts+=( "Stunning surreal noir portrait of a dangerous femme fatale with porcelain skin and piercing eyes, wearing a sleek black dress, standing in an endless black void filled with floating broken mirrors reflecting alternate versions of herself, heavy Sin City black-and-white contrast with striking red lipstick and red high heels, dramatic rim lighting, smoke swirling into ghostly figures, mysterious and seductive mood, masterpiece." )

# 18 · Melting Metropolis
prompts+=( "Surreal noir cityscape inspired by Sin City, skyscrapers melting like wax into a dark ocean of ink, flying vintage cars and giant shadowy figures walking between buildings, heavy rain, a lonely man in trench coat smoking on a tilted rooftop, extreme black and white contrast with one splash of glowing neon blue, dark atmospheric lighting, intricate details, dystopian surrealism, cinematic masterpiece." )

# 19 · The Last Kiss
prompts+=( "Intensely dramatic surreal noir scene: a couple sharing a final passionate kiss on a rain-drenched rooftop while the city behind them disintegrates into floating geometric fragments and hourglasses, high-contrast Sin City black and white style with vivid red on lips and blood on shirt, strong shadows, moody lighting, emotional and haunting atmosphere, ultra-detailed, artistic masterpiece." )

# 20 · Shadow Carnival
prompts+=( "Surreal noir carnival at midnight, twisted carnival tents and rides floating in a stormy black sky, clowns with elongated limbs and hollow eyes, a mysterious woman in a sparkling black dress holding a glowing umbrella, extreme Sin City high-contrast shadows and inky blacks with selective crimson and gold accents, pouring rain, dreamlike yet menacing mood, highly detailed, dark whimsical surrealism, cinematic." )

# ── Qwen 3.6+ ───────────────────────────────────────────────────────────────

# 21 · The Melting Detective
prompts+=( "A surreal noir scene in stark black and white with a single crimson rose accent: a trench-coated detective walks down a rain-slicked alley, but his shadow detaches and melts into a pool of liquid ink that flows upward against gravity. Neon signs flicker with distorted, impossible text. High-contrast chiaroscuro lighting, Frank Miller-style hard ink shadows, surreal Escher-like architecture in the background, cigarette smoke curling into phantom faces, cinematic Dutch angle, graphic novel aesthetic with dreamlike distortion." )

# 22 · Femme Fatale in the Fractured Mirror
prompts+=( "A Sin City-inspired portrait of a mysterious woman in a fedora, her face partially reflected in a shattered mirror — but each shard shows a different surreal version of her: one with moth wings, one with clockwork eyes, one dissolving into starlight. Stark black-and-white palette with selective electric blue highlights on her lips. Dramatic side lighting casting razor-sharp shadows, film noir composition with surrealist symbolism, ink-wash textures, smoke and velvet atmosphere, ultra-stylized graphic art." )

# 23 · City of Floating Silhouettes
prompts+=( "A surreal noir cityscape at midnight: skyscrapers tilt at impossible angles, their windows glowing like floating eyes. Silhouetted figures in fedoras walk on vertical walls and upside-down streets, defying gravity. Rain falls upward in streaks of silver against pure black skies. High-contrast monochrome with a single golden pocket watch glowing in the foreground. Sin City graphic novel style blended with Magritte-inspired surrealism, dramatic perspective lines, ink-splatter textures, moody and mysterious." )

# 24 · The Cigarette Smoke Prophecy
prompts+=( "A close-up noir portrait: a lone figure exhales cigarette smoke that transforms mid-air into surreal visions — a floating key, a weeping angel, a clock with no hands — all rendered in wispy grayscale. Stark rim lighting creates a halo effect against deep black background. Sin City-style heavy ink outlines and crosshatching, but with dreamlike fluid transitions. Selective color: the ember of the cigarette glows intense orange. Macro focus on eyes reflecting impossible cityscapes, psychological and poetic mood." )

# 25 · Alleyway to the Subconscious
prompts+=( "A surreal noir alley that bends into a spiral: wet cobblestones reflect not the sky, but a starless void filled with floating vintage telephones and broken pocket watches. A lone streetlamp casts a pool of light where a fedora rests on nothing — its wearer invisible. Stark black-and-white with a single emerald-green neon sign buzzing in the distance. Frank Miller meets Dalí: hard-edged ink shadows, graphic novel linework, impossible perspective, melancholic and enigmatic atmosphere, ultra-stylized composition." )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · The Dissolving Femme Fatale
prompts+=( "Sin City style high-contrast black and white photography. A femme fatale in a vintage trench coat stands in a rainy alley, lighting a cigarette. Her lower body is dissipating, turning into countless floating playing cards and ticking pocket watch fragments. Strong chiaroscuro, extreme black silhouettes colliding with glaring white light. The only color in the frame is her bright red lips and the falling heart playing cards. Gritty film grain, surreal film noir aesthetic, masterful composition." )

# 27 · The Escaping Shadows
prompts+=( "Surreal film noir style. Wet asphalt reflecting harsh overhead light. The main subjects are silhouettes of men in fedoras, but their shadows are completely detached from their bodies, crawling up inclined, Dali-esque melting walls like independent creatures. Pure black, white, and gray tones, with only a touch of eerie neon green. Extreme light and shadow cutting, oppressive yet psychedelic sin city atmosphere, 8k resolution." )

# 28 · The Impossible Reflection
prompts+=( "Classic film noir detective figure, wearing a soaked khaki trench coat, looking down at his reflection in a puddle. Surreal reversal: the reflection in the puddle is not him, but an inverted alien deep-sea world, where giant glowing void tentacles swim. Strong Sin City-style hardboiled lighting, large areas of pure black, the only bright color is a sickly yellow streetlamp in the background. Cinematic lens, perfect blend of suspense and absurdity." )

# 29 · The Anti-Gravity Bar
prompts+=( "Dimly lit underground jazz bar, swirling with thick hand-rolled cigarette smoke. At the bar, a weathered gangster is pouring whiskey, but the liquid defies gravity, flowing upwards and solidifying in mid-air into a constantly rotating surreal geometric nebula. High-contrast black and white texture, the only color in the picture is the cold electric blue light emitted by the whiskey. A collision of hardboiled detective fiction atmosphere and Magritte-style dreamscape, highly visually impactful." )

# 30 · Escher's Chase
prompts+=( "Tribute to Escher's surreal endless stairs. A lone film noir protagonist, wearing a fedora and holding a revolver, sprinting on impossible, infinitely looping stairs. Surrounded by sideways torrential rain, the raindrops sharp as silver needles, illuminated by hard light sources. Extremely pure black and white contrast, absolutely no extra color, a fusion of extreme geometric illusion and the fatalistic escape theme of film noir. Gritty texture, a masterpiece of art full of absurdity and despair." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · The Drowning Witness
prompts+=( "A woman in a 1940s trench coat standing in a rain-lashed alley, her shadow on the brick wall detaching and crawling away like a living ink stain. Only her crimson lipstick bleeds color into the monochrome world. Extreme chiaroscuro, hard noir lighting, wet asphalt reflections, surreal shadow autonomy, Sin City graphic novel aesthetic, high contrast, film grain, moody and unsettling." )

# 32 · The Clockwork Suicide
prompts+=( "A man in a pinstripe suit sitting on a fire escape, his head opened like a music box to reveal a miniature city skyline rotating inside — tiny cars with headlights streaming through his thoughts. Deep blacks, stark whites, a single amber glow from a distant streetlamp. Noir atmosphere, surreal anatomical architecture, graphic novel inking style, melancholic and hypnotic." )

# 33 · The Femme Fatale's Garden
prompts+=( "A silhouetted woman in a backlit doorway, her cigarette smoke curling into solid black roses that bloom and wilt in mid-air. Rain falls upward around her. Pure monochrome except for the burning orange ember. Extreme high contrast, hard shadows, wet noir streets, surreal botanical manifestations, Frank Miller inspired, cinematic composition, fatalistic elegance." )

# 34 · The Memory Dealer
prompts+=( "A trench-coated figure in a fog-shrouded pawn shop, trading glowing orbs of light — each containing a frozen scene from someone else's life — across a counter stained with fingerprints. Deep shadows swallow the background. Only the orbs emit soft halos in an otherwise black-and-white world. Noir mystery, surreal commerce of consciousness, stark lighting, grainy texture, existential dread." )

# 35 · The Last Raincoat
prompts+=( "A detective stands at a crime scene where the chalk outline of the victim has filled with rising floodwater, and dead fish swim in circles where a body should be. His face is half-lit by a swinging bare bulb. Torrential rain, deep blacks, piercing whites, surreal forensic dreamscape, urban decay, graphic novel panel composition, hopeless and hypnotic atmosphere." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
