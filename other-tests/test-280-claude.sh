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
# Source: https://wiki.liutyi.info/pages/viewpage.action?pageId=226197936
# liutyi text2image test v2.80.c — AI-generated draft by Claude Sonnet 4.6
# Structure: 20 rows × 4 columns (A–D, escalating complexity) = 80 prompts
# Queued row-by-row: 1A 1B 1C 1D / 2A 2B … / 20A 20B 20C 20D
# No negative prompts. Covers photo, illustration, art style, surreal/concept.
# ---------------------------------------------------------------------------
prompts=()

# ── Row 01 · Materials & Texture ────────────────────────────────────────────

# 1A
prompts+=( "molten gold splash" )

# 1B
prompts+=( "extreme close-up of cracked dried mud in a desert riverbed, warm afternoon backlight, rich earth textures, shallow depth of field" )

# 1C
prompts+=( "Macro photography of a peacock feather barb cluster, extreme close-up on a single iridescent quill, electric blues and greens shifting with angle, razor-sharp focus on microstructure, pitch black background, studio lighting, ultra-high detail, shallow depth of field" )

# 1D
prompts+=( "Cinematic material study: a massive ancient bronze bell cracked vertically down the center, revealing its interior. The surface is thick with verdigris — greens and blues of centuries-old oxidation layered over reddish bronze that still gleams where patina has worn thin. Condensation droplets cling to the cool metal in early morning light. Lichen colonies grow in protected crevices near the base. The crack itself reveals crystalline metal structure — a dramatic cross-section of history. Low angle, wide-angle lens, sharp foreground detail, atmospheric depth, museum conservation aesthetic, neutral gray diffused lighting, 8k ultra-detail, physically accurate metal rendering." )

# ── Row 02 · Speed & Motion ─────────────────────────────────────────────────

# 2A
prompts+=( "racing cars" )

# 2B
prompts+=( "slow motion photo of a basketball passing through a hoop, water droplets suspended mid-air, dramatic side lighting, gym atmosphere" )

# 2C
prompts+=( "Street photography, a Tokyo cyclist blurred in motion rushing past a crisp still background of a traditional red torii gate. Contrast of old and new, rainy evening, shallow depth of field, 1/30s shutter, long exposure rear curtain sync flash, documentary feel" )

# 2D
prompts+=( "Motorsport photography, dramatic low-angle shot of a Formula 1 car taking a hairpin corner at Monaco, extreme motion blur on wheels and exhaust plume, chassis perfectly sharp at 1/500s. Safety marshal in fluorescent vest frozen mid-gesture in foreground, slightly out of focus. Sun-drenched Mediterranean backdrop: white apartment blocks, luxury yachts in the harbor below, a narrow sliver of turquoise sea between barriers. Ultra-wide lens at ground level, photorealistic, cinematic broadcast quality, dramatic shallow depth of field." )

# ── Row 03 · Aerial / Bird's Eye ────────────────────────────────────────────

# 3A
prompts+=( "aerial view of a beach, overhead, drone" )

# 3B
prompts+=( "bird's eye view of Tokyo Shibuya crossing at rush hour, drone photography, tilt-shift miniature effect, thousands of pedestrians, umbrellas, geometric" )

# 3C
prompts+=( "Aerial drone photograph looking straight down on a traditional Moroccan medina rooftop at golden hour. Geometric maze of terracotta tile rooftops, wind-dried laundry, satellite dishes, narrow street canyons casting long shadows, cats sleeping in warm light patches, two women carrying baskets, photorealistic, stunning top-down composition" )

# 3D
prompts+=( "Helicopter aerial photography, early morning mist, looking down at a sweeping oxbow bend of the Amazon River from 800 meters altitude. Deep serpentine black water cuts through an unbroken emerald carpet of jungle canopy to all horizons. A single dugout canoe with one figure barely visible — a sliver of russet wood against dark water. No roads, no buildings, no civilization except that one boat. Morning evaporation mist rises in hazy columns from the canopy. 600mm telephoto compression, ultra-detailed, National Geographic quality, golden early light, slightly hazy atmosphere." )

# ── Row 04 · Four Seasons — Same Scene ──────────────────────────────────────

# 4A
prompts+=( "Nordic forest lake in early spring, birch trees just budding, pale cold morning light" )

# 4B
prompts+=( "Midsummer Nordic lake at golden noon, lush full birch canopy mirrored perfectly in glass-still water, a single red wooden rowing boat, warm idyllic light, photorealistic landscape" )

# 4C
prompts+=( "Nordic forest lake in peak autumn, fiery crimson and gold birch leaves cascading, half fallen on mirror-still dark water. Early morning mist rising from the surface. Overcast sky. Painterly realism, limited warm palette, moody and beautiful, fine art photography." )

# 4D
prompts+=( "Nordic lake in deep winter, blue hour at 3pm in late December, barely any sky light. Ice covers the lake completely, fractured where it meets frozen reeds along the shore. Bare birch trees — silver-white skeletal fingers against a leaden sky dusted with the first light snowfall. A single wooden jetty disappears into the ice. No footprints anywhere. A profound, crushing silence rendered visible. Hyper-realistic landscape photography, extremely muted palette of whites, pale blues and charcoal grey, fine art photography aesthetic, melancholy and beautiful." )

# ── Row 05 · Culinary Art ───────────────────────────────────────────────────

# 5A
prompts+=( "apple" )

# 5B
prompts+=( "overhead flat lay, rustic wooden table, Italian breakfast, espresso, croissant, newspaper, natural morning light" )

# 5C
prompts+=( "Michelin star plating on a matte black slate plate. A single wagyu tartare quenelle topped with Osietra caviar, edible gold leaf, and a precision-cut egg yolk sphere. Microherbs arranged with tweezers. Negative space composition. Dark moody restaurant lighting, food magazine photography, ultra-sharp, 8k." )

# 5D
prompts+=( "Molecular gastronomy at its extreme: a master chef's dish — a transparent olive oil sphere in agar membrane rests atop coffee soil and matcha ash dusted on a cold-smoked matte black ceramic plate. Beside it, a crystallized Campari shard catches light like a gemstone. A pipette of liquid nitrogen has just touched the edge; white vapor clouds curl upward. Behind, slightly out of focus, the chef's gloved hands hold precision tweezers. Dark moody restaurant lighting. One narrow directional spotlight from above creates dramatic chiaroscuro on the dish. Shallow DOF, cinematic composition, ultra-realistic." )

# ── Row 06 · Vintage Eras ───────────────────────────────────────────────────

# 6A
prompts+=( "1920s flapper portrait, sepia" )

# 6B
prompts+=( "1950s American roadside diner, chrome counter stools, milkshakes, black and white analog photograph, heavy film grain, nostalgic" )

# 6C
prompts+=( "Authentic 1970s Kodachrome street photography: a young woman in wide bell-bottom jeans and a patterned blouse walks past a record store with Beatles and Led Zeppelin albums in the window. Film grain, slightly faded warm color shift, 1971, New York City, slice of life documentary." )

# 6D
prompts+=( "Historical simulation: Victorian-era formal portrait in the style of a wet collodion glass plate photograph, circa 1885. A family of four posed in a studio — patriarch standing, mother seated in silk taffeta, two children rigidly upright. Long exposure artifact: eyes wide open, subtle blur on hands. Props: ornate Victorian chair, potted fern, draped backdrop with printed columns. Vignetting at corners, full plate glass texture visible, slight chemical spotting, authentic sepia tones with silver highlights, period-accurate hair and clothing, absolute historical fidelity." )

# ── Row 07 · Weather & Atmosphere ───────────────────────────────────────────

# 7A
prompts+=( "heavy rain on a city café window at night" )

# 7B
prompts+=( "monsoon flooding in a narrow Vietnamese alleyway, locals wading knee-deep, paper lanterns swaying, warm documentary photography, dramatic" )

# 7C
prompts+=( "A massive cumulonimbus supercell thunderstorm over the American Great Plains at dusk. Mammatus clouds hang below the anvil. A distant tornado funnel barely touches ground. Electric orange and purple sky. A lonely grain silo in the foreground for scale. Wide angle, dramatic epic scale, photorealistic storm photography." )

# 7D
prompts+=( "White-out blizzard in Antarctica at the geographic South Pole. Wind speed above 80 km/h — the ceremonial pole flags ripping sideways, barely visible through total whiteout. Two researchers in yellow expedition suits are bent nearly horizontal into the wind, roped together for safety, faces completely masked in neoprene. The orange dome of Amundsen-Scott Station is a ghostly smear 200 meters behind them. Photorealistic documentary photography, extreme low temperature palette of white and ice blue, fast-shutter grain, near-darkness, survival scale of humans against environment." )

# ── Row 08 · Wild Animal Portraits ──────────────────────────────────────────

# 8A
prompts+=( "wolf" )

# 8B
prompts+=( "close-up portrait of an old male lion with battle-scarred mane, golden hour backlight, photorealistic, fur detail, intense gaze" )

# 8C
prompts+=( "Snow leopard perched on a high granite ledge in the Himalayas, azure sky altitude, looking down with pale arctic eyes, breath visible in cold air. Extreme telephoto, precise detail on fur rosettes, natural light, barely visible against the rocks, camouflage perfection. National Geographic quality." )

# 8D
prompts+=( "Wildlife photography, Serengeti: a cheetah in full sprint, airborne mid-stride 1.5 meters above the grass, body hyper-extended at maximum acceleration arc. The gazelle is 2 meters ahead, also airborne. Frozen at 1/2000s shutter. Foreground grass perfectly sharp; the cheetah blurs slightly at edges from absolute velocity. Golden savanna mid-morning, acacia tree at left third, distant kopje in haze, zebras scattering at the periphery. National Geographic quality, telephoto compression, dust from the cheetah's last footfall still hanging, extraordinary decisive moment." )

# ── Row 09 · Underwater World ───────────────────────────────────────────────

# 9A
prompts+=( "coral reef, tropical fish, underwater" )

# 9B
prompts+=( "scuba diver silhouette against a shaft of surface sunlight, shark passing below, dramatic underwater photo, blue void" )

# 9C
prompts+=( "Ultra-macro underwater photography: a translucent nudibranch sea slug on black volcanic rock at 18m depth. Its feathery cerata are electric pink and white, a riot of biological color. Perfect clarity, photorealistic, natural sunlight refraction from above, razor-sharp micro-detail, dark surroundings emphasize the subject." )

# 9D
prompts+=( "Cinematic deep ocean, 5,000 meters depth, total natural darkness. A sperm whale descends through absolute blackness, enormous bulk making the ocean feel small. Below it, distantly, the faint bioluminescent glow of a colossal squid — acres of tentacles barely suggested in the murk. The whale's skin shows sucker-scar constellations from past battles. A research submersible's two white beams illuminate the whale from below. Absolute stillness made visible. Ultra-realistic underwater render, scientifically accurate, extreme contrast of tiny lit zones in infinite black, Blue Planet II cinematic quality, overwhelming scale and loneliness." )

# ── Row 10 · Space & Cosmos ─────────────────────────────────────────────────

# 10A
prompts+=( "nebula" )

# 10B
prompts+=( "astronaut floating in space, Earth's curved horizon below, Milky Way behind, photorealistic, silence" )

# 10C
prompts+=( "The surface of Europa, Jupiter's moon: a cryovolcanic eruption venting water-ice geysers 100km high. A NASA robotic probe in foreground for scale. Jupiter filling half the sky, banded with storms. Pitch-black space dotted with stars. Photorealistic space art, physically accurate, awe-inspiring, cinematic." )

# 10D
prompts+=( "Astrophotography composite: the merging of two spiral galaxies, Antennae Galaxies analog, viewed from 2 million light-years above the galactic plane. Two immense spiral structures distorted by gravitational interaction, tidal tails of stars arcing into intergalactic dark. Star-forming regions blazing electric blue along the collision interface. The collision is so slow — hundreds of millions of years in progress — it appears perfectly still. Hubble Space Telescope aesthetic, JWST-era infrared composite, gold and deep teal palette, scientifically accurate drama, incomprehensible vast scale, ultra-high resolution masterpiece." )

# ── Row 11 · Night Urban Architecture ───────────────────────────────────────

# 11A
prompts+=( "Tokyo neon, rain, night" )

# 11B
prompts+=( "Floodlit Colosseum at night, deep blue Roman sky, long exposure, car light trails, tourists as small silhouettes, photorealistic" )

# 11C
prompts+=( "Blade Runner-inspired alleyway, 2am. Every surface plastered with neon Chinese signage, aging air conditioners, dripping pipes. A solitary figure in a yellow raincoat stands at the far end. Rain-slicked ground mirrors everything perfectly. Cinematic low fog, desaturated color except neons, heavy atmosphere, ultra-detailed." )

# 11D
prompts+=( "Wide-angle architectural night photography: a grand historic covered market seen from a drone at 11pm, its vaulted domed roof lit from within — hundreds of stained glass skylights glowing like golden lanterns from above. Surrounding it: a dense city neighborhood of minarets lit in white, honeycombed apartment blocks with warm window glow, cobblestone lanes in amber sodium light. A single tram light-trailed into a glowing orange line bisects the frame. A river is a brushstroke of black mirror in the distance. Long exposure, 15-second shutter, ultra-sharp except light trails, photorealistic." )

# ── Row 12 · Childhood & Wonder ─────────────────────────────────────────────

# 12A
prompts+=( "girl blowing dandelion seeds, golden summer light" )

# 12B
prompts+=( "boy peering through a telescope from a rooftop at night, city lights below, milky way above, expression of wonder, documentary portrait" )

# 12C
prompts+=( "Documentary portrait: a 6-year-old girl in a bright yellow dress stands barefoot in shallow tide pools, completely absorbed in holding a starfish up to the light. Pacific coast, golden afternoon, sun-bleached hair, pure absorbed joy, soft sea air. Natural light, reportage style, emotional authenticity." )

# 12D
prompts+=( "Environmental portrait, social documentary: six children aged 5 to 12 in a vibrant community classroom in Nairobi, Kenya, their faces gathered around a single laptop screen they are seeing for the first time. Expressions: astonishment, delight, pointing fingers, one child with mouth wide open. Equatorial afternoon light streams through a window, curtains moving. The young female teacher watches from behind, smiling. The wall has hand-painted educational murals. Ultra-sharp documentary photograph, warm cinematic color grade, reportage style, no artificiality, genuine human moment." )

# ── Row 13 · Crowds & Social ────────────────────────────────────────────────

# 13A
prompts+=( "busy Istanbul spice market" )

# 13B
prompts+=( "Holi festival crowd in India, explosion of colored powder filling the air, overhead drone shot, vibrant chaos, photorealistic" )

# 13C
prompts+=( "Rock concert crowd from stage perspective looking out at 80,000 people, LED wristbands turning crowd into a sea of synchronized colored light, confetti cannons mid-explosion, enormous video screens, fog and laser grid, raw collective emotional energy, wide angle, cinematic." )

# 13D
prompts+=( "Magnum Photos-style decisive moment street photography: a sudden rainstorm erupts over a Shanghai intersection. A hundred umbrellas flower open simultaneously, creating an instant pop-art sea of color and geometry seen from above. Gaps between umbrellas reveal kaleidoscope wet pavement reflections. One man refuses the rain — face upturned, eyes closed, arms slightly raised, utterly content to be soaked while the world rushes past. Every wet fabric texture, rain impact splash, reflected neon is hyper-sharp. 1/1000s frozen motion, fine grain, masterpiece street image." )

# ── Row 14 · Product & Commercial ───────────────────────────────────────────

# 14A
prompts+=( "perfume bottle, studio" )

# 14B
prompts+=( "minimalist wristwatch product photography, white background, dramatic side studio lighting, perfect sharp shadow" )

# 14C
prompts+=( "Commercial photography: luxury handcrafted olive oil in a tall blown green glass bottle, outdoor Mediterranean setting on a weathered olive wood board, fresh olives scattered nearby, rosemary sprig accent, soft Tuscan afternoon sunlight, bokeh of olive grove in background, food magazine quality, cinematic warmth." )

# 14D
prompts+=( "Ultra high-end product advertisement: handcrafted men's Oxford shoes, museum-calf dark burgundy leather, hand-welted sole visible at 45° angle. Shot on dark Cipollino marble surface. Three carefully placed strobes — two warm side lights creating leather burnish highlights, one cool backlight rimming the silhouette. Reflection in marble is sharp and precise. Background, slightly out of focus: a gentleman's library — book spines, a crystal decanter, a chess board. 150mm lens, medium format aesthetic, no retouching artifacts, color grade from 1960s luxury print advertisement — warm shadows, creamy highlights." )

# ── Row 15 · Retro Poster & Graphic Art ─────────────────────────────────────

# 15A
prompts+=( "vintage travel poster, Paris, 1930s" )

# 15B
prompts+=( "Soviet constructivism propaganda poster, worker figure, bold red and black, pure geometric shapes, Cyrillic typography, 1925 style, stark" )

# 15C
prompts+=( "1960s psychedelic concert poster for a fictional band \"The Crystal Foxes\", swirling rainbow Art Nouveau typography, electric pink background, hand-lettered Wes Wilson / Fillmore Auditorium aesthetic, peacock feather motif border, black light poster effect, richly decorative." )

# 15D
prompts+=( "Art Deco ocean liner travel poster, circa 1932. \"RMS LEVIATHAN — SOUTHAMPTON TO NEW YORK — 5 DAYS\". Ship in pure geometric silhouette — massive stepped profile in midnight blue against a gradient sky of turquoise to gold. Waves abstracted into chevron patterns. Typography: Futura Bold all-caps, gold leaf color, strict geometric hierarchy with line rules and borders. Corner ornaments: stylized compass roses. Two vertical coral color bands flank the composition. Aged paper texture, slight browning at edges, letterpress printing imperfections, absolutely authentic period aesthetic." )

# ── Row 16 · Fantasy & Mythology ────────────────────────────────────────────

# 16A
prompts+=( "dragon" )

# 16B
prompts+=( "phoenix rising from flames, dramatic, fiery feathers exploding outward, dark background, digital illustration" )

# 16C
prompts+=( "Ancient Japanese sea dragon Ryūjin emerging from a night ocean — enormous coiled serpentine body, scales iridescent as abalone, massive antlered head roaring, surrounded by waterspout towers and bioluminescent foam, full moon behind. Dramatic ukiyo-e inspired composition but hyper-detailed modern digital art." )

# 16D
prompts+=( "Epic illustration: the goddess Athena descends from storm clouds over the burning walls of Troy at dusk, full war regalia — golden aegis shield bearing the Gorgon's face, owl-feather crested helm, spear blazing with divine white fire. Below her, armies of Trojans and Achaeans are frozen in awe, tiny as ants. Her form is as tall as the city walls. Achilles on horseback in the foreground, shining Hephaestean armor, looks up in horror. Style: monumental classical oil painting of the Delacroix/Turner school executed with modern concept art precision. Ultra-detailed, epic scale." )

# ── Row 17 · Surreal & Impossible ───────────────────────────────────────────

# 17A
prompts+=( "upside-down city reflected in a single raindrop" )

# 17B
prompts+=( "a library inside a cross-section of a human skull, miniature books on bone shelves, bioluminescent moss growing in eye sockets, macro photography, hyperrealistic" )

# 17C
prompts+=( "A perfectly ordinary breakfast scene: a man reads his newspaper at a kitchen table. Every object casts its shadow in a completely different direction. Coffee flows upward out of the cup. The clock on the wall has hour marks but no hands. Hyperrealistic rendering — no surreal stylization, just wrong physics depicted completely normally." )

# 17D
prompts+=( "Hyperrealistic impossible photograph: a glass terrarium, 30cm wide, sitting on a kitchen counter. Inside it, impossibly, is a complete 1:800,000 scale model of New York City — full Manhattan skyline lit from within, Central Park as a dark rectangle, rivers like dark ink, hair-thin bridges. The Empire State Building is 3.5 centimeters tall. The terrarium glass is slightly misty from the \"city\" below. A woman's hand reaches in through an open panel, one finger extended, about to touch what might be the Bronx. Perfectly sharp studio lighting, no compositing artifacts, utterly convincing." )

# ── Row 18 · Skilled Hands at Work ──────────────────────────────────────────

# 18A
prompts+=( "potter's hands shaping clay" )

# 18B
prompts+=( "chef hands, precision knife work, julienne carrots, professional kitchen, motion blur on the blade edge" )

# 18C
prompts+=( "Concert violinist's left hand pressing strings during a live performance, extreme close-up, vibrato motion blur on fingertips, dramatic stage spotlights from the side, rosin dust particles visible in the beam, dark concert hall audience bokeh behind, ultra-sharp on strings and fingers." )

# 18D
prompts+=( "Medical micro-surgery, extreme macro: two surgeons' gloved hands operating on a human eye — retinal reattachment. A 23-gauge micro-surgical forceps 0.3mm from the retinal surface. The operating microscope light illuminates in a clinical white ovoid beam. Around the bright zone: a second pair of hands with a fiber light, the surgical drape, the anesthesiologist's hand to the left. Ultra-sharp micro-photography, clinical lighting, high drama of precision, scale of instruments against the eye creates vertigo." )

# ── Row 19 · Light Source Studies ───────────────────────────────────────────

# 19A
prompts+=( "candlelight portrait" )

# 19B
prompts+=( "a single lantern hanging in a dark misty forest, long exposure, fog, profound mysterious atmosphere" )

# 19C
prompts+=( "Bioluminescent bay at midnight: a kayaker paddles through glowing teal-green dinoflagellate water, each paddle stroke igniting swirling constellations of light beneath the surface. The Milky Way arches overhead perfectly mirrored in the still dark portions of the bay. 30-second long exposure, Vieques Puerto Rico atmosphere, magical and real." )

# 19D
prompts+=( "Fine art light study: the Pantheon in Rome, interior, midsummer noon at the exact moment the oculus beam is perfectly circular on the floor — a 9-meter column of pure sunlight cutting from the opening through two thousand years of dust to the ancient travertine. The round shaft contains visible floating particulates and the faintest suggestion of faces — pilgrims who have stood in this beam through centuries. The surrounding dome recedes into sculptural shadow. A single tourist, small as a figurine, stands in the beam. 5-second long exposure, transcendent, architectural photography masterpiece." )

# ── Row 20 · Art Styles — Same Scene ────────────────────────────────────────

# 20A
prompts+=( "old lighthouse, rocky cliff, violent storm, crashing waves. Japanese woodblock print, Hokusai style" )

# 20B
prompts+=( "An old lighthouse on a rocky promontory in a raging storm, enormous crashing waves, midnight sky riven with lightning. Style: Golden Age Dutch maritime oil painting — Rembrandt-era dramatic chiaroscuro, brooding Baroque palette of ochre, umber and black, thick impasto texture implied, historically accurate 17th-century painting." )

# 20C
prompts+=( "Same scene: old lighthouse, rocky coast, violent storm, massive waves. Style: Art Nouveau illustration poster, Alphonse Mucha-influenced. The storm transformed into decorative swirling organic lines and patterns, lighthouse integrated into a border of stylized sea-foam and kelp tendrils. Muted sage, gold and terracotta palette, circa 1900." )

# 20D
prompts+=( "A ruined lighthouse on a storm-lashed volcanic rock peninsula, colossal Atlantic waves, sky torn with horizontal rain and lightning. Rendered as a detailed traditional watercolor: loose wet-on-wet technique in sky and sea, tighter brushwork on lighthouse stonework. Palette: Payne's grey, burnt sienna, raw umber, cobalt blue, restrained Naples yellow at the lightning source. Visible Fabriano paper texture, brushmarks readable, water pooling at the bottom where the paper buckled slightly. Authentic traditional medium, master English watercolor school." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

