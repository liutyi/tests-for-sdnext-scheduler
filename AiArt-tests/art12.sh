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
# Theme: Tiny creatures — macro photography, cute & fragile mood
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+12+-+tiny+creatures
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — The Clockwork Exile
prompts+=( "A tiny rusted robot the size of a thumbnail, slumped inside the hollow cavity of a broken antique pocket watch, gears frozen mid-spin. Chipped bronze paint, hairline scratches on its chassis, fine dust settled in every joint. Macro photography, extreme shallow depth of field, warm amber rim light from a cracked watch face, muted sepia-and-rust color palette. Mood: melancholy, forgotten, fragile." )

# 02 — The Dew-Soaked Fairy
prompts+=( "A pocket-sized fairy asleep inside a folded foxglove petal, wings translucent and beaded with morning dew drops. Soft fine flower fibers pressed against her cheek, pollen dust scattered across her torn linen dress. Macro photography, razor-thin depth of field, cool overcast diffused light from above, desaturated sage-green and pearl palette. Mood: nostalgic, delicate, whimsical." )

# 03 — The Soil Diver
prompts+=( "A tiny bulbous micro-monster, no bigger than a pebble, half-buried in dark moist garden soil, only its wide glassy eyes and two stumpy arms visible above the surface. Clumped dirt particles clinging to its textured rubbery skin, thin root filaments draped across its forehead. Macro photography, ground-level perspective, soft lateral shaft of golden hour light, earthy brown-and-ochre color palette. Mood: curious, tenacious, quietly comic." )

# 04 — The Library Ghost
prompts+=( "A translucent spectral creature no larger than an eraser, perched on the cracked spine of an old hardcover book, pressing one tiny hand against peeling gilded lettering. Yellowed paper fibers, fingerprint smudges on the cover, a cobweb thread catching soft dusty light from an unseen lamp above. Macro photography, soft bokeh background of a blurred bookshelf, warm candlelight tones, muted ivory-and-burgundy palette. Mood: nostalgic, ethereal, melancholy." )

# 05 — The Puddle Mariner
prompts+=( "A minuscule sailor gnome standing on a walnut shell boat, adrift in a rain puddle on cracked asphalt, holding a matchstick mast with a torn paper sail. Rust-stained pavement beneath the water, small air bubbles clinging to the shell hull, a raindrop ring expanding in the foreground. Macro photography, low water-level angle, overcast diffused grey light, cold slate-blue and weathered-white color palette. Mood: solitary, adventurous, bittersweet." )

# --- Gemini 3.1 Flash ---

# 06 — The Pocket Watch Pixie
prompts+=( "A tiny, mechanical pocket pixie with fragile translucent wings, curled up asleep inside the open gears of an antique brass pocket watch. Microscopic scale, fine dust particles floating in the air, delicate scratches on the metal casing, subtle fingerprints on the glass lens. Macro photography, extreme close-up, shallow depth of field, warm amber lighting, nostalgic and whimsical mood, muted gold and sepia tones." )

# 07 — The Thimble Snail-Dragon
prompts+=( "A miniature, cute baby dragon the size of a marble, hiding inside a tarnished silver sewing thimble on a wooden table. Only its wide, curious eyes and a tiny scaly snout are visible. Fine metallic oxidation, fabric lint, microscopic splinters on the weathered wood, macro photography, soft side-lighting, cool desaturated blue and silver palette, fragile and endearing atmosphere." )

# 08 — The Moss-Inhabitant Golem
prompts+=( "A tiny, round stone golem creature, no bigger than a pebble, sitting nestled deep inside a lush bed of green forest moss. Microscopic dew drops clinging to its rough stone skin, fine dirt particles, single strands of spiderweb silk catching the light. Macro photography, sharp focus on the creature, heavily blurred background, soft diffused morning sunlight, natural earthy palette, peaceful and fragile mood." )

# 09 — The Lost Porcelain Axolotl
prompts+=( "A miniature, stylized porcelain axolotl creature peeking out from a crack in a wet, gritty asphalt sidewalk after a rainstorm. Tiny cracks in its glossy white ceramic surface, micro water droplets, stray grains of sand and rough pebble textures. Macro photography, shallow depth of field, reflections in a tiny puddle, cool overcast lighting, fragile and lonely mood." )

# 10 — The Library Bulb Sprite
prompts+=( "A tiny, round fuzzy dust-sprite creature with large glowing eyes, sitting inside a cracked, burnt-out vintage lightbulb on a dusty library shelf. Fine layers of gray dust, microscopic glass fractures, delicate yellowed book page fibers in the background. Macro photography, soft internal cinematic glow from the creature, shallow depth of field, neutral moody palette, nostalgic and cozy atmosphere." )

# --- ChatGPT ---

# 11 — Pocket Watch Sanctuary
prompts+=( "A tiny, delicate clockwork fox curled up inside an antique pocket watch, its metallic body covered in chipped brass plating, micro-scratches, and faint rust along the joints, one glass eye slightly fogged; surrounded by oversized dust particles, fine fibers, and fingerprints on the inner glass, gears towering like industrial pillars around it; the fox gently resting its head on a ticking cog as if seeking warmth; macro photography, extreme close-up, shallow depth of field, soft cinematic lighting with warm golden highlights and deep shadow falloff, muted sepia and charcoal tones, nostalgic and fragile mood." )

# 12 — Dewdrop Fisher
prompts+=( "A tiny amphibian-like creature with translucent skin and faintly glowing veins, sitting on the edge of a massive leaf, fishing into a hanging dewdrop with a strand of spider silk; its skin covered in subtle imperfections like specks of dirt, water droplets, and organic texture variations; the leaf surface detailed with fine veins, pollen dust, and tiny scratches; the dewdrop reflecting a distorted oversized world; macro photography, shallow depth of field, soft cinematic backlighting, cool green and blue palette with gentle highlights, dreamy and melancholic mood." )

# 13 — Forgotten Toy Robot
prompts+=( "A tiny toy robot, half-buried in soil like an ancient relic, with chipped pastel paint, rust creeping along its seams, and dirt packed into its joints; one dim eye flickering faintly; surrounded by towering grains of soil, tangled root fibers, and scattered dust particles; a small sprout growing beside it, leaning toward the robot as if curious; macro photography, shallow depth of field, soft cinematic lighting with diffused sunlight filtering through, earthy browns and faded colors, nostalgic and slightly melancholic atmosphere." )

# 14 — Teacup Ghost Gathering
prompts+=( "Several tiny, semi-transparent ghost-like creatures gathered inside a cracked porcelain teacup, their forms softly glowing, edges imperfect and wavering; the cup surface covered in hairline cracks, stains, fingerprints, and dust; tea residue forming a textured landscape beneath them like a dried lakebed; one ghost reaching out as if telling a story; macro photography, shallow depth of field, soft cinematic side lighting, muted cream and pale blue tones with gentle shadows, whimsical yet fragile and nostalgic mood." )

# 15 — Matchbox Firekeeper
prompts+=( "A tiny fire spirit curled inside an open matchbox, its body made of faint glowing embers and smoke wisps, interacting with a single oversized matchstick; the matchbox interior lined with worn paper textures, scratches, dust, and tiny debris; burn marks and soot stains visible along the edges; the creature gently nurturing a dim spark as if protecting it; macro photography, shallow depth of field, soft cinematic low-key lighting with warm orange glow against deep shadows, moody and intimate atmosphere." )

# --- Grok ---

# 16 — Steampunk robot in soil
prompts+=( "A tiny chipped-paint steampunk robot, no taller than a matchstick, half-buried in rich dark soil with oversized blades of grass towering above, delicate rust spots and dust particles on its brass body, one tiny arm reaching out, macro photography, extremely shallow depth of field, soft cinematic golden-hour lighting, moody earthy color palette, nostalgic and fragile atmosphere, intricate textures, fine soil grains and fibers clinging to its joints." )

# 17 — Pocket fairy in crocus
prompts+=( "A delicate pocket fairy with translucent wings covered in microscopic dew drops, peeking shyly from inside a vibrant purple crocus flower, oversized petals framing her like a cathedral, faint fingerprints on her porcelain-like skin, fine pollen dust floating in the air, macro photography, dreamy shallow depth of field, soft diffused cinematic lighting, whimsical yet melancholic muted pastel palette, highly detailed textures." )

# 18 — Micro-monster in pocket watch
prompts+=( "A melancholic micro-monster resembling a fluffy baby gremlin trapped inside an open antique pocket watch, sitting on the gears, tiny paws pressed against the glass, visible rust and tarnished metal, delicate dust particles and tiny scratches on the crystal, macro photography, ultra shallow depth of field, soft moody cinematic lighting with cool blue tones, nostalgic fragile atmosphere, intricate mechanical textures." )

# 19 — Porcelain kitten in dandelion
prompts+=( "An adorable tiny porcelain kitten figurine come to life, curled up inside a giant dewy dandelion seed head, fragile cracked glaze with fine spiderweb fractures, morning dew drops clinging to its ears and whiskers, oversized white fluff fibers surrounding it, macro photography, creamy shallow depth of field, gentle cinematic side lighting, soft whimsical yet fragile color palette, nostalgic mood, extreme tactile detail." )

# 20 — Glass firefly on teacup
prompts+=( "A minuscule glass-blown firefly with glowing amber belly, resting on the rim of an old forgotten teacup filled with rain water, tiny air bubbles and imperfections in the glass, delicate dust and fingerprint smudges on its surface, oversized rain droplets on the porcelain, macro photography, shallow depth of field with bokeh, soft cinematic overcast lighting, grounded moody teal and warm amber palette, fragile whimsical melancholy." )

# --- Qwen 3.6 Plus ---

# 21 — Mechanical fox in pocket watch
prompts+=( "A pocket-sized mechanical fox crafted from worn brass gears and chipped teal enamel, resting half-buried in damp moss and tarnished silver coins inside a cracked vintage pocket watch. Macro photography captures fine rust creeping along its joints, scattered dust particles, and delicate scratches on its glass eye. Shallow depth of field, soft cinematic lighting casting long, gentle shadows, grounded sepia and mossy green color palette, evoking a nostalgic and fragile mood." )

# 22 — Fairy on sugar cube
prompts+=( "A thumb-sized fairy with translucent, velvet-textured moth wings curled up on a cracked sugar cube beside a chipped porcelain teacup. Macro photography highlights fine hairline fractures in the ceramic, scattered crystalline sugar grains, faint coffee ring stains, and delicate fibers along her wings. Shallow depth of field, soft cinematic lighting with a gentle glow, grounded earthy and muted pastel color palette, creating a whimsical yet melancholy atmosphere." )

# 23 — Bean-shaped monster in book
prompts+=( "A plump, bean-shaped micro-monster with worn velvet fur and mismatched button eyes nestled in the deep crease of an open, antique leather-bound book. Macro photography reveals cracked spine glue, frayed paper fibers, delicate veins of pressed autumn leaves, and a fine layer of archival dust. Shallow depth of field, soft cinematic lighting pooling in the book's margins, grounded desaturated brown and warm amber color palette, evoking a nostalgic and whimsical mood." )

# 24 — Seed sprite in mason jar
prompts+=( "A thumb-high seed sprite clad in overlapping moss leaves and slender twig limbs, pressing tiny hands against the fogged glass of a vintage mason jar lid. Macro photography captures beading condensation droplets, pitted rust along the metal threading, soil smudges on the glass, and microscopic plant hairs on its cloak. Shallow depth of field, soft cinematic lighting diffused through the condensation, moody cool slate and muted olive color palette, conveying a fragile and melancholy mood." )

# 25 — Clockwork beetle on puddle
prompts+=( "A miniature clockwork beetle with an iridescent, slightly cracked shell and oxidized copper legs stranded on a smooth pebble at the edge of a shallow rain puddle on weathered asphalt. Macro photography details wet asphalt grit, floating pollen grains clinging to surface tension ripples, fine scratches on the beetle's casing, and tiny water droplets. Shallow depth of field, soft cinematic lighting reflecting off the puddle, grounded muted teal and charcoal color palette, radiating a nostalgic and fragile mood." )

# --- GLM 5.1 ---

# 26 — Clockwork fairy in pocket watch
prompts+=( "A tiny clockwork fairy made of tarnished brass and mica, trapped inside the glass dome of a broken antique pocket watch, intricate scratches on the crystal, microscopic dust particles floating in the air, fine rust blooming on the brass gears, oily fingerprints smudged on the glass, extreme macro photography, shallow depth of field, soft cinematic golden hour lighting seeping through watch cracks, moody sepia and tarnished brass color palette, melancholy and fragile mood." )

# 27 — Micro-monster in walnut shell
prompts+=( "A fluffy, wide-eyed micro-monster the size of a jellybean, peeking out from inside a decaying walnut shell half-buried in damp potting soil, matted fine fur, damp soil clumps clinging to the shell, decaying rough wood grain, glistening dew drops resting on microscopic moss, tiny root fibers tangled around the shell, macro photography, shallow depth of field, soft cinematic overcast lighting, grounded earthy green and brown color palette, whimsical and fragile mood." )

# 28 — Clay gardener on thistle
prompts+=( "A miniature hand-painted clay gardener figurine with a chipped straw hat, leaning against a giant dried-up thistle seed head in an overgrown garden, chipped matte paint exposing bare ceramic, hairline cracks in the glaze, dried fluffy thistle fibers, scattered powdery pollen dust, delicate spider web silk threads, macro photography, shallow depth of field, soft cinematic late afternoon lighting, muted pastel and dusty grey color palette, nostalgic and melancholy mood." )

# 29 — Tin robot in junk drawer
prompts+=( "A tiny retro wind-up tin robot with loose limbs, sitting on a crumpled, faded receipt at the bottom of a dark kitchen junk drawer, flaking lithographed paint, deep rust spots on the metal joints, frayed paper fibers, thick lint and dust bunnies, smudged faded ink, greasy fingerprints on the tin, macro photography, shallow depth of field, soft cinematic single-shaft lighting from a cracked drawer above, moody shadow and warm tungsten color palette, nostalgic and lonely mood." )

# 30 — Glass snail on windowsill
prompts+=( "A translucent, delicate glass snail carrying a tiny porcelain mushroom on its back, sliding across the rough, splintered surface of a sun-bleached wooden windowsill, hairline cracks in the translucent glass shell, microscopic condensation droplets, raised worn wood grain, peeling flaky white paint, fine powdery sawdust, macro photography, shallow depth of field, soft cinematic diffused morning light, cool blue and desaturated white color palette, fragile and whimsical mood." )

# --- Kimi K2.6 Thinking ---

# 31 — The Buried Automaton
prompts+=( "A tiny rusted brass robot with chipped teal paint and exposed clockwork gears, half-buried in dark moist garden soil among decomposing autumn leaves and twigs, macro photography, extreme shallow depth of field, soft golden-hour cinematic backlighting filtering through tree canopy, suspended dust particles catching sunbeams, fine root fibers wrapping around its corroded joints and dented antenna, moody earthy palette of burnt sienna and deep moss green, nostalgic melancholy atmosphere, dew drops clinging to its weathered surface, photorealistic 8k." )

# 32 — The Pocket Fairy
prompts+=( "A delicate pocket fairy with translucent iridescent wings and a threadbare linen dress, peeking out from between the velvety petals of an oversized dew-covered peony flower, macro photography, shallow depth of field, soft diffused cinematic lighting from an overcast sky, visible pollen grains and fine petal fibers, chipped pearl buttons on her dress, faint fingerprints smudging her tiny porcelain face, melancholy whimsical mood, muted blush pink and dried sage palette, fragile and ethereal, hyper-detailed textures." )

# 33 — The Clockwork Prisoner
prompts+=( "A micro-monster no bigger than a thumb with fuzzy blue-green fur matted with household dust, curled asleep inside a vintage brass pocket watch with cracked glass and tarnished silver hands, macro photography, extreme close-up, shallow depth of field, warm tungsten cinematic lighting casting long shadows across intricate clock gears, visible rust flakes and oil residue on the brass casing, fine scratches on the glass catching light, pocket lint fibers floating in the stale air, nostalgic lonely atmosphere, sepia and midnight blue palette." )

# 34 — The Forgotten Fox
prompts+=( "A tiny ceramic fox figurine with crazed glaze and chipped gold leaf ears, abandoned in a patch of wild clover with morning frost melting on its surface, macro photography, shallow depth of field, soft overcast cinematic lighting, individual clover hairs and soil grains in razor-sharp foreground focus, delicate spider silk strands bridging between its paws, dust settled deep into crack lines, tiny fingerprints of a child preserved in the glaze, wistful melancholy mood, desaturated emerald and aged cream palette, hyper-detailed 8k." )

# 35 — The Paper Voyage
prompts+=( "A miniature boat folded from yellowed handwritten letter paper, sailing in a rainwater puddle on weathered oak wood, carrying a tiny knitted mouse with one missing button eye and unraveling wool whiskers, macro photography, extreme shallow depth of field, soft rainy window cinematic lighting, water droplets magnifying wood grain and paper fibers, faded ink bleeding from the boat hull into the water, dust motes suspended above the rippling surface, nostalgic bittersweet atmosphere, muted amber and slate gray palette, fragile and whimsical, photorealistic." )

# --- Deepseek ---

# 36 — Fairy in soil
prompts+=( "A tiny pocket fairy with frayed linen wings, half-buried in damp, dark soil beside a rusted sewing needle. Chipped paint on a fallen acorn cap, fine root fibers wrapped around her ankle, and a single dew drop on her forehead. Macro photography, shallow depth of field, soft cinematic lighting with muted olive and bronze tones. Mood: nostalgic and fragile." )

# 37 — Porcelain robot in pocket watch
prompts+=( "A miniature porcelain robot missing one eye, peeking out from inside an antique pocket watch with a cracked glass face. Dust particles floating in the air, tarnished brass gears, faint fingerprints on the watch case. Macro photography, shallow depth of field, warm volumetric light filtering through a dusty window, moody sepia and faded gold palette. Mood: whimsical and melancholy." )

# 38 — Woolly monster in matchbox
prompts+=( "A tiny woolly micro-monster with mismatched button eyes, trapped inside a discarded matchbox lined with shredded newspaper. Scuffed cardboard edges, burnt matchstick remnants, fine lint fibers clinging to its fur. Macro photography, shallow depth of field, soft side-lighting with cold blue and warm amber contrast, cinematic grain. Mood: lonely and tender." )

# 39 — Glass snail on rotting wood
prompts+=( "A translucent snail-like creature with a glass-bubble shell, resting on a wet, mossy pocket-watch chain half-sunken into a rotting wooden windowsill. Dew drops beading on the shell, chipped white paint flakes, microscopic rust spots on the chain links. Macro photography, shallow depth of field, diffused overcast lighting, muted teal and earthy brown palette. Mood: fragile and wistful." )

# 40 — Sugar bee in teacup
prompts+=( "A tiny sugar-spun bee with crystallized legs, clinging upside-down to the inner rim of a chipped teacup. Dried tea leaf fragments, a single human hair coiled nearby, faint dust motes suspended in still air. Macro photography, shallow depth of field, soft golden-hour backlighting through lace curtains, warm ochre and dusty rose tones. Mood: bittersweet and delicate." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
