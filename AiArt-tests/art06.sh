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
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+6+-+Liminal+Space
# Theme: photorealistic liminal spaces — empty, eerie, transitional
# 8 models × 5 prompts = 40 total
# Stripped: --ar flags, inline resolution tags, italic markdown from Kimi entries.
# ---------------------------------------------------------------------------
prompts=()

# ── Claude Sonnet 4.6 ───────────────────────────────────────────────────────

# 01 · The Backrooms Office
prompts+=( "Endless open-plan office at 3 AM, rows of beige cubicles under flickering fluorescent tubes, industrial carpet in faded blue-grey geometric pattern, ceiling tiles with water stains, no windows, emergency exit signs glowing red at the far end of a corridor that extends beyond focus, abandoned coffee cups on desks, photorealistic, Canon EF 24mm f/2.8, shallow depth of field, harsh overhead lighting, desaturated palette." )

# 02 · Motel Exterior Corridor
prompts+=( "Exterior walkway of a 1970s roadside motel at dusk, identical wooden doors painted turquoise, concrete floor with faded yellow stripe, vending machine humming at the far end casting orange glow, empty pool below visible through railing, overcast sky, slight motion blur on hanging light fixture, photorealistic, 35mm film grain, golden hour fading to blue, puddles reflecting neon." )

# 03 · Indoor Public Pool
prompts+=( "Deserted indoor swimming pool, Olympic lane lines floating motionless on still water, aquamarine tiles, white painted brick walls, humid haze slightly blurring the far end, natatorium ceiling with exposed steel beams and skylights showing grey sky, wet footprints on tile deck leading nowhere, no people, photorealistic, wide angle, color temperature 4200K, institutional lighting." )

# 04 · Suburban Grocery Store After Hours
prompts+=( "Empty supermarket aisle at midnight, fluorescent tube lighting reflecting on waxed linoleum floor, fully stocked shelves of cereal boxes in both directions to infinity, no shoppers or staff, PA system speaker visible in ceiling, shopping cart abandoned mid-aisle slightly askew, slight lens flare from overhead light, photorealistic, Sony 16-35mm, sterile color grading, deep vanishing point perspective." )

# 05 · Airport Terminal Transit Zone
prompts+=( "International airport transit corridor at 4 AM, moving walkway running between glass walls overlooking dark tarmac, recessed floor lighting in cool blue, gate signs showing cancelled flights, rows of empty black seating with silver armrests, cleaning trolley parked and unattended, distant aircraft warning lights blinking through windows, photorealistic, long exposure effect, cold white balance, slight reflection on polished floor." )

# ── Gemini ──────────────────────────────────────────────────────────────────

# 06 · The Infinite Hospitality Loop
prompts+=( "A hyper-realistic, wide-angle shot of an empty hotel hallway. Patterned ochre carpets with a repetitive 1970s geometric design. Pale yellow wallpaper and identical dark wood doors stretching into a vanishing point. The lighting is provided by flickering, warm-toned fluorescent ceiling panels creating soft, unnatural shadows. No people, slightly grainy 35mm film aesthetic, eerie and silent atmosphere." )

# 07 · The Midnight Play Zone
prompts+=( "A photorealistic liminal space of a deserted indoor soft-play center at night. Primary-colored plastic tubes, slides, and ball pits under the dim glow of a single emergency exit sign. The textures of the foam padding and plastic mesh are hyper-detailed. Deep shadows in the corners of the room. Cinematic lighting, high contrast, unsettlingly clean, captured on a wide-angle lens." )

# 08 · The Subterranean Transit Hub
prompts+=( "A minimalist, photorealistic image of an empty underground subway platform. Glossy white tiled walls reflecting the harsh, cool-toned LED overhead lights. The floor is polished concrete with a slight damp sheen. No trains, no posters, no trash. A sense of vast, hollow space. Sharp focus, architectural photography style, volumetric lighting, ultra-detailed textures." )

# 09 · The Neon Fog Gas Station
prompts+=( "A photorealistic liminal space of a vintage gas station isolated in a thick, heavy midnight fog. The only light source is the glowing white canopy and a single buzzing neon sign. The surrounding environment is pitch black. Volumetric lighting catching the mist, hyper-realistic asphalt texture with puddles, cinematic bokeh, eerie loneliness." )

# 10 · The Tiled Aquatic Dream
prompts+=( "A hyper-realistic, surreal liminal space of a vast indoor pool room. The walls, floor, and ceiling are covered in small, square white tiles. The water is a bright, glowing turquoise and unnaturally still. No windows, with light seemingly emanating from the water itself. Minimalist composition, sharp lines, Dreamcore aesthetic, shot on Hasselblad, high dynamic range." )

# ── ChatGPT ─────────────────────────────────────────────────────────────────

# 11 · Empty Mall Atrium at Night
prompts+=( "A vast, abandoned shopping mall atrium at night, illuminated only by flickering fluorescent lights. Escalators stand motionless, polished tile floors reflect harsh white lighting. Storefronts are shuttered with outdated signage, faint haze in the air. Ultra-photorealistic style, 35mm lens, deep depth of field, subtle film grain, slightly cold color grading, no people, eerie silence, liminal atmosphere." )

# 12 · Endless Hotel Corridor
prompts+=( "A long, symmetrical hotel hallway stretching infinitely, identical doors on both sides, dim tungsten lighting casting soft shadows on patterned carpet. Walls have slightly outdated decor, faint distortion at the vanishing point. Hyper-realistic photography, cinematic composition, shallow haze, 50mm lens, balanced exposure, warm but unsettling tones, no human presence, quiet uncanny mood." )

# 13 · Suburban Playground at Dawn Fog
prompts+=( "An empty suburban playground at early dawn, surrounded by identical houses barely visible through dense fog. Plastic slides and swings are wet with dew, ground covered in muted rubber tiles. Soft diffused lighting, pastel sky tones, ultra-realistic textures, slight overexposure bloom, 85mm lens, no people, calm yet unsettling liminal stillness." )

# 14 · Underground Parking Garage (Overlit)
prompts+=( "A nearly empty underground parking garage with excessively bright fluorescent lighting, creating harsh reflections on concrete floors. Yellow safety lines and numbered pillars repeat into the distance. Slight green tint, security camera perspective feel, high dynamic range, sharp focus, ultra-photorealistic, wide-angle lens 24mm, no cars or only one distant car, sterile and uncanny atmosphere." )

# 15 · School Classroom Frozen in Time
prompts+=( "An empty classroom with rows of desks perfectly aligned, soft daylight entering through large windows with partially closed blinds. Chalkboard still has faint writing, dust particles visible in light beams. Slightly outdated furniture, muted color palette, hyper-realistic detail, 50mm lens, shallow depth of field, no people, nostalgic yet eerie liminal mood." )

# ── Grok ────────────────────────────────────────────────────────────────────

# 16 · Endless Hotel Corridor
prompts+=( "Photorealistic image of an infinitely long, empty hotel hallway at 3 AM, dim warm yellow wall sconces casting long soft shadows on beige patterned carpet, slightly worn texture, closed wooden doors with gold numbers, one flickering light in the distance, subtle film grain, uncanny atmosphere, liminal space, wide angle lens, cinematic lighting, hyper detailed." )

# 17 · Abandoned Shopping Mall
prompts+=( "Photorealistic empty 1980s shopping mall atrium, dead escalators, polished beige floor tiles reflecting fluorescent ceiling lights, empty storefronts with faded signs, scattered potted plants, distant water fountain still running, cold artificial lighting mixed with soft natural light from skylights, liminal space, eerie silence, hyperrealistic, intricate details." )

# 18 · Deserted Indoor Pool
prompts+=( "Photorealistic liminal indoor swimming pool at twilight, completely empty, still turquoise water reflecting rows of fluorescent tube lights on the ceiling, wet tiled floors, lounge chairs neatly arranged but unoccupied, large windows showing dark blue evening outside, subtle steam in the air, haunting atmosphere, cinematic color grading, ultra detailed, photorealistic." )

# 19 · Office Building Hallway
prompts+=( "Photorealistic long empty corporate office hallway at night, buzzing fluorescent lights, beige walls with subtle texture, gray commercial carpet, rows of identical closed doors, water cooler in the distance, slight motion blur on one flickering light, liminal backrooms aesthetic mixed with realistic office environment, moody atmosphere, hyper detailed, shot on Sony A7R IV." )

# 20 · Foggy Multi-Level Parking Garage
prompts+=( "Photorealistic multi-level parking garage at dawn, completely empty, thick atmospheric fog, yellow concrete pillars and walls, faint overhead lighting barely cutting through the mist, oil stains on the floor, distant exit sign glowing red, concrete textures, cinematic volumetric lighting, unsettling liminal feeling, ultra realistic, intricate details." )

# ── Qwen 3.6 Max ────────────────────────────────────────────────────────────

# 21 · Empty Hotel Corridor
prompts+=( "A photorealistic image of an unoccupied hotel corridor stretching into the distance, lined with identical beige doors and faded geometric carpet. Soft fluorescent ceiling lights cast long, diffused shadows. The air is still with a light haze, dust motes visible in the light beams. 35mm lens, centered perspective, muted earth tones, high-resolution photography, realistic material textures, liminal transitional space." )

# 22 · Deserted Indoor Mall at Twilight
prompts+=( "Photorealistic wide shot of a vacant two-level shopping mall at dusk. Empty storefronts with closed security gates line both floors, connected by a stationary escalator. Cool twilight filters through a large glass skylight, casting soft blue-gray tones across the polished tile floor. Slight atmospheric haze, perfectly still, no people or signage clutter. 24mm lens, natural ambient lighting, realistic reflections, high detail, liminal space atmosphere." )

# 23 · Foggy Underground Parking Structure
prompts+=( "A photorealistic image of an empty underground parking garage at night. Rows of concrete pillars recede into a light ground fog, with overhead fluorescent tubes emitting a cool green-white glow. The asphalt floor shows faint tire marks and shallow puddles reflecting the light. Completely devoid of vehicles or people. 50mm lens, cinematic leading lines, realistic concrete and water textures, muted color grading, liminal mood." )

# 24 · After-Hours School Hallway
prompts+=( "Photorealistic interior of an empty school hallway after hours. Beige linoleum floor reflects warm late-afternoon light streaming through high rectangular windows. Metal lockers line both walls, slightly worn but clean. A single red exit sign glows softly in the distance. No people, bags, or posters. 35mm lens, natural directional lighting, high detail, realistic surface wear, subtle airborne dust, liminal transitional atmosphere." )

# 25 · Vacant Airport Concourse at Night
prompts+=( "A photorealistic wide-angle view of an unoccupied airport terminal concourse at night. Rows of identical metal seating face large glass windows overlooking a dark, unlit tarmac. Cool overhead LED panels create soft reflections on the polished floor. The space is completely vacant, with a quiet, suspended atmosphere. 28mm lens, cinematic composition, realistic glass and metal textures, desaturated tones, liminal space aesthetic." )

# ── GLM5 Turbo ──────────────────────────────────────────────────────────────

# 26 · The Classic 90s Hotel Corridor
prompts+=( "Photorealistic wide-angle shot of an endlessly long, empty hotel corridor. Dated 1990s aesthetic with patterned burgundy carpet and pale yellow textured wallpaper. Rows of identical wooden doors with brass room numbers, slightly ajar. Overhead fluorescent ceiling lights casting a sterile, slightly warm glow with a subtle humming atmosphere. A single glowing red exit sign at the far vanishing point. No people, absolute silence, uncanny liminal space. Shot on 35mm film, Kodak Portra 400, sharp focus, subtle film grain, architectural photography." )

# 27 · The Empty Indoor Pool at Night
prompts+=( "Photorealistic interior of an empty, dimly lit public indoor swimming pool at night. Pale blue ceramic tiles lining the walls, slightly aged with faint calcium stains. The water is perfectly still, acting like a dark mirror reflecting the harsh overhead incandescent lights. A single yellow plastic lane rope floats motionless. White plastic lawn chairs are stacked neatly in the dark background. Eerie, nostalgic, melancholic liminal atmosphere. DSLR photography, f/2.8 aperture, cinematic lighting, no people, hyper-detailed water reflections." )

# 28 · The Abandoned Mall Food Court at Dusk
prompts+=( "Photorealistic wide shot of an abandoned 1990s shopping mall food court at dusk. Dusty high skylights letting in fading, murky golden hour sunlight that creates long shadows on the floor. Rows of empty Formica dining tables and round chairs. Dark, shuttered fast-food kiosks with faded 90s graphic signage. Large potted indoor plants casting silhouettes. Deep shadows, dusty atmospheric haze, profound sense of spatial emptiness and nostalgia. Architectural photography, Fujifilm Superia 400 film stock, highly detailed textures." )

# 29 · The Foggy Airport Skybridge
prompts+=( "Photorealistic image of a completely empty airport terminal moving walkway. Brushed stainless steel panels, gray terrazzo floor with subtle embedded flakes. Large floor-to-ceiling glass windows revealing a thick, impenetrable morning fog outside, completely obscuring the tarmac and planes. The black rubber handrails and metal grooves of the motionless walkway are highly detailed. Cold, blue-tinted fluorescent overhead lighting. Eerie, transitional, liminal mood. Ultra-realistic, shot on Sony A7R IV, pristine clarity, vast scale." )

# 30 · The Brutalist Stairwell
prompts+=( "Photorealistic downward perspective looking down a cold, empty concrete brutalist stairwell. Pale gray concrete walls with subtle scuff marks and a layer of fine dust. A single harsh fluorescent tube light buzzes on the ceiling, casting sharp, high-contrast shadows against the geometric angles of the steps. A small, grimy window on a mid-landing lets in a sliver of bleak, overcast daylight. Unsettling, sterile, disorienting liminal aesthetic. 24mm wide-angle lens, high dynamic range, hyper-detailed concrete textures." )

# ── Kimi K2.6 thinking ──────────────────────────────────────────────────────

# 31 · The Empty Office Corridor
prompts+=( "Photorealistic empty office corridor at 3 AM, fluorescent lights flickering, beige carpet with coffee stains, endless identical doors, unsettling silence, liminal space aesthetic, hyper-detailed." )

# 32 · The Backrooms Pool
prompts+=( "Photorealistic backrooms swimming pool, yellowed institutional tiles, murky chlorinated water, buzzing fluorescent lights, damp concrete walls, unsettling nostalgia, hyper-detailed water reflections, liminal horror aesthetic." )

# 33 · The Empty Parking Garage
prompts+=( "Photorealistic empty underground parking garage at night, concrete pillars repeating endlessly, single flickering overhead light, oil stains on floor, distant exit sign glowing red, liminal space dread, hyper-detailed concrete textures." )

# 34 · The School Hallway at Night
prompts+=( "Photorealistic empty school hallway at night, lockers stretching to vanishing point, bulletin boards with outdated announcements, overhead fluorescent lights, waxed linoleum floor reflecting light, liminal nostalgia, hyper-detailed institutional details." )

# 35 · The Hotel Corridor
prompts+=( "Photorealistic endless hotel corridor, patterned carpet with geometric 1980s design, brass wall sconces with warm light, numbered doors repeating, ice machine glow at far end, liminal hospitality dread, hyper-detailed fabric textures." )

# ── Deepseek ────────────────────────────────────────────────────────────────

# 36 · Abandoned 90s Mall Corridor
prompts+=( "Photorealistic image of an empty, late-1990s shopping mall corridor at night. Dirty white floor tiles with faded geometric patterns, low acoustic ceiling tiles stained by water leaks. Fluorescent tube lights flickering with a faint greenish hue, casting harsh shadows. Shuttered storefronts with dusty, half-peeled decals. A single broken escalator leading to a dark upper floor. Air vents blowing a faint mist. Dead-end hallway with a fire exit sign glowing red. Hyper-detailed, shallow depth of field, cinematic lighting, liminal atmosphere, eerie stillness." )

# 37 · Fluorescent Office Labyrinth
prompts+=( "Ultra-realistic wide-angle shot of an endless corporate office corridor with beige cubicle walls and grey carpet tiles. Overhead fluorescent panels placed irregularly, creating pools of harsh white light and deep shadows. Identical meeting rooms on both sides with glass walls, showing empty chairs and whiteboards with smudged dry-erase marks. A single turned-over swivel chair in the middle distance. No windows, no exits visible. Subtle chromatic aberration, slight vignette, dust particles floating in the light beams. Liminal space, unsettling repetition, claustrophobic yet vast." )

# 38 · Forgotten Indoor Swimming Pool
prompts+=( "Photorealistic image of an abandoned indoor swimming pool at dawn. Murky, motionless water reflecting the cracked tile walls. Mosaic tiles missing in patches, revealing dark, damp concrete. Staggered ceiling with exposed pipes and broken skylights, through which pale milky light falls unevenly. Lifeguard chair tipped over into the shallow end. Metal railings rusted, with calcium deposits. A faint haze of chlorine and mold hanging in the air. No people, complete silence implied. High dynamic range, texture-rich, liminal melancholy." )

# 39 · Subway Platform After Midnight
prompts+=( "Hyper-detailed photorealistic scene of an under-construction subway station platform. Bare concrete walls with orange plastic netting hanging loose. A single digital departure board displaying scrambled text and DELAYED in red. Dusty yellow safety line on the platform edge. Endless tunnel stretching into absolute blackness, with only two dim emergency lights revealing scattered construction tools — a hard hat, a coffee cup, a rolled blueprint. Slight rust on the steel columns. Mist from tunnel ventilation visible. Liminal transition space, oppressive emptiness, low-angle perspective." )

# 40 · Vintage Arcade Transition Room
prompts+=( "Photorealistic image of a narrow, windowless hallway connecting two sections of a closed-down 1980s arcade. Peeling pastel wallpaper with neon geometric patterns. Faded red carpet with black star sprinkles, stained by decades of spilled soda. A single coin-operated machine with a dead monitor leaning against the wall. Wall-mounted telephones with dial tones absent. Fluorescent blacklight strips illuminating unnoticed handprints on the walls. At the far end, a half-open door revealing only another identical hallway. Soft focus, warm to cool color gradient, dust motes suspended in air, liminal nostalgia, uncanny stillness." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"

