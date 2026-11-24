i#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="HiDream-ai/HiDream-O1-Image"' >&2
  exit 1
fi

# Static: where every prompt in this file comes from (goes into the turbo negative_prompt)
SOURCE_URL="https://huggingface.co/datasets/Qwen/Qwen-Image-Bench"

# ---- HELPERS ---------------------------------------------------------------
urlencode() {
  local LC_ALL=C   # byte-wise, so multibyte characters (curly quotes, CJK) encode as proper UTF-8 percent-escapes
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

# queue_job INDEX PROMPT
# Negative prompt logic (turbo / distilled models):
#   CFG in 0..1 (or GUIDANCESCALE <= 1) -> negative_prompt = <source URL> tag
#   otherwise                            -> negative_prompt is an empty string
queue_job() {
  local index="$1"
  local prompt="$2"
  local task_name
  task_name="$(printf '%04d' "$index") ${prompt:0:16}"

  printf "[QUEUE %04d] %s…\n" "$index" "${prompt:0:120}"

  local neg_prompt=""
  local turbo=0
  if (( $(echo "$CFG >= 0 && $CFG <= 1" | bc -l) )); then turbo=1; fi
  if [[ -n "${GUIDANCESCALE:-}" ]] && (( $(echo "$GUIDANCESCALE <= 1" | bc -l) )); then turbo=1; fi
  if (( turbo )); then
    neg_prompt="<source ${SOURCE_URL}>"
  fi

  local json
  json=$(jq -n \
    --arg  prompt   "$prompt"   \
    --arg  neg      "$neg_prompt" \
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
      prompt:               $prompt,
      negative_prompt:      $neg,
      steps:                $steps,
      cfg_scale:            $cfg,
      cfg_true:             $ag,
      guidance_name:        $gnm,
      guidance_scale:       $gsc,
      width:                $w,
      height:               $h,
      sampler_name:         $sampler,
      seed:                 $seed,
      batch_size:           1,
      n_iter:               1,
      save_images:          true
    }')

  curl -s -X POST "$SCHED?name=$(urlencode "$task_name")" \
    -H "Content-Type: application/json" \
    -d "$json" > /dev/null
}

# ---- PROMPTS ---------------------------------------------------------------
# Theme: Qwen-Image-Bench - English prompt list (prompts_en.json), SHORT version:
#        only the 55 selected prompts of the 1000; job numbers = original numbers
# Source: https://huggingface.co/datasets/Qwen/Qwen-Image-Bench
# Structure: 55 prompts, queued in original order (job N = prompt N of the full list)
# Turbo runs (CFG 0..1): negative_prompt = <source https://huggingface.co/datasets/Qwen/Qwen-Image-Bench>
# ---------------------------------------------------------------------------

queue_job 1 \
  "A disassembled mechanical watch sits on a black workbench. A watchmaker uses tweezers to pick up a gear. A close-up of the tweezers picking up the gear reveals the silver and dark gray tones, the precise structure of the components, and the clear details of the metal edges."

queue_job 8 \
  "Generate a realistic portrait: An Asian woman with long, straight black hair and large eyes sits by a window reading. She has long, curled eyelashes in a baby-curl style, her eyes slightly lowered, and she smiles as she looks at the book. The soft, backlit light filtering through the sheer curtains in the early morning creates dappled patterns. The woman's skin texture is natural, with subtle but not excessive pores, and her gaze is focused. The portrait should realistically depict the relationship between her fingers and the pages, with clear details on her nails. The overall tone is gentle and low-saturation, and the composition is a medium to close-up."

queue_job 12 \
  "Exterior view of a barbershop on a street corner in a Chinese city in the 1980s: old-fashioned rotating lightbox, glass window, handwritten price list (not required to be fully legible), Phoenix brand bicycles parked on the roadside; clothing and architectural details are consistent with the era (bell-bottoms, old-style signboard), and the overall film grain is moderate."

queue_job 16 \
  "Generate a modern Orientalist living room interior design rendering, with the following structural standards: ceiling spotlights, window lighting, and ergonomically designed sofa and coffee table dimensions; light-colored micro-cement flooring; an abstract painting on the wall; a wide-angle composition without exaggerated distortion, straight lines, and correct perspective."

queue_job 17 \
  "Generate a 2D pixel-style RPG town scene screenshot: including a fountain, weapon shop, inn, and three NPCs; the pixel style should be consistent and highly readable; the upper left corner of the screen should have a simple UI: HP 100/100, Gold 250 (the text must be clear)."

queue_job 31 \
  "Three-panel composition: The theme is \"Farewell on a Rainy Night.\" Panel 1: Long shot, neon lights and rain outside the station, the figure occupies less than 10% of the frame height, using leading lines (platform edge) pointing to the exit; Panel 2: Medium shot, the protagonist looks back with an umbrella, the umbrella edge forming a frame composition, with side backlighting outlining the edge; Panel 3: Close-up, the finger releases the ticket, raindrops highlight the edge of the ticket. The overall color scheme is cool blue with neon magenta accents, the rain reflections and shadows are physically accurate; the characters' emotions are restrained yet readable."

queue_job 83 \
  "Simulated Fujifilm X-T30 film color simulation (Classic Chrome). Shooting style: A curly-haired woman reading a magazine outside a street corner coffee shop in the afternoon; the light is soft, and the shadows have a light blue tint. Requirements: Fine film grain texture, skin tone not overly beautified, natural light and shadow levels, and low color saturation without color cast."

queue_job 84 \
  "Simulate the texture of a Leica M6 film camera shot: An elderly man pushes his bicycle across a street corner in an old town, with the morning light creating rim lighting against the backlight. Requirements: Natural film grain, sharp backlight outlines, stable rule of thirds composition, and no AI-repeated textures."

queue_job 87 \
  "Vlog perspective using DJI Osmo Pocket 3 stabilized gimbal: handheld shooting of a pedestrian street at dusk, with the subjective camera moving forward while a person in front turns around and smiles; UI overlay \"REC·00:45\". Requirements: realistic subjective perspective, readable UI text, balanced lighting, and natural image stabilization."

queue_job 89 \
  "Using a DJI Inspire 3 drone with a cinematic lens: Aerial photography of a valley town in the morning mist, with sunlight penetrating the clouds to create volumetric light; a shimmering river in the distance. Requirements: Clear volumetric light layers, realistic perspective, no AI-generated repetitive cloud textures, and accurate village scale."

queue_job 90 \
  "A vintage red Porsche 911, parked at a bend in the Alpine road, has a polished mirror-like finish that clearly reflects the outlines of snow-capped peaks and the trails of flowing clouds. The front wheels are deeply mired in mud, with gravel and withered grass mixed in with the tire treads. The metal trim on the body gleams silver in the cold sunlight. In the distance, majestic glaciers rise, and mountain winds whip up fine snow that sweeps across the hood. Requirements: Wide-angle mid-to-long distance shot, rule of thirds composition, physically accurate reflections and shadows, and no identifiable Porsche logo visible on the car body."

queue_job 94 \
  "On a street corner along the Seine in Paris, a street artist with a sketchboard tucked between his lap quickly sketches facial contours with charcoal pencils, the lines smooth and precise; a tourist sits in a folding chair, collar slightly wrinkled, hands folded on his lap, expression relaxed; in the background, the Eiffel Tower is softly blurred, leaving only the silhouette of its steel trusses, while plane tree leaves cast swaying spots of light in the breeze."

queue_job 95 \
  "In the post-war ruins and rubble, the mechanical dog's four paws tread on broken steel bars, and the hydraulic rods of its joints emit a low-frequency hum; the infrared camera continuously emits a dark red light, and the metal casing is covered with scratches, rust, and bullet holes, while the sensor array on its back rotates slightly; a faint beam of flashlight shines through the cracks in the rubble, pointing to a dusty hand protruding from under a concrete slab."

queue_job 104 \
  "At the crest of the giant wave, surfers leap into the air, water bursting and scattering like a crown, each drop reflecting the sunlight; back muscles and arms are taut, toes gripping the board, palm trees are clearly visible on the distant coastline, and the high-speed shutter freezes the peak moment of speed and power."

queue_job 125 \
  "Realistic dawn fishing: a fisherman casts a net from the bow, the lines fanning out with tension-driven arcs; the sea mirrors sunrise gradients with plausible specular highlights; weathered boat wood shows salt stains and scratches; details remain sharp without “plastic” denoising; lighting direction matches water reflections."

queue_job 135 \
  "Unmelted snow lay on the black car hood, each snowflake retaining its hexagonal crystal outline and branching texture; the paint reflected ambient light to create realistic highlights, and there was a slight melting water film where the snow met the paint but did not destroy its shape; the edges were sharp, the details were rich, and there was no over-sharpening noise."

queue_job 188 \
  "Art design: a triptych illustration on “post-rain reflections”: puddles, glass storefront, and metal elevator doors. Each panel includes a small bilingual label (e.g., “Puddle / 水洼”) with consistent type and whitespace. Require unified palette with varied detail, coherent reflection geometry, accurate text, clean edges, and a premium visual-system feel."

queue_job 206 \
  "Comic: office doorway with a sticky note “Back in 10 十分钟后回来” in readable handwriting; a metal doorplate reads “MEETING ROOM / 会议室” in bilingual hierarchy. The character jogs down the corridor, tie fluttering, anxious face. Require realistic paper fibers, adhesive marks, metal reflections, accurate text, and believable non-exaggerated emotion."

queue_job 215 \
  "Silhouettes of a couple holding hands walking on the beach at sunset, gentle waves lapping at the shore, the sky painted orange-red by the evening glow."

queue_job 234 \
  "Design a resort silk gown in Dunhuang mural palette: colors derived from mineral pigments—ochre, earth red, and lapis lazuli blue. Wide sleeves drape fluidly. Print faithfully reproduces Mogao Cave caisson motifs: honeysuckle scrolls and pearl-roundels, symmetrically arranged with fine linework. Model barefoot at edge of oasis shallow water, soft low-angle morning light, gentle glow highlighting silk sheen against matte skin—evoking Eastern mystique and serene ease."

queue_job 239 \
  "Render a photography exhibition wall: 4 evenly spaced framed B/W photo placeholders on a white wall, captions with bilingual title and numbers. Require plausible glass reflections without blocking content; clear aligned caption text; strong orderly composition."

queue_job 251 \
  "Autumn/winter layered street look: wool overcoat, knitted turtleneck, scarf, leather gloves; backlit on a leaf-strewn street. Require crisp non-repeating wool/knit textures; plausible rim light; warm restrained mood; natural face without AI artifacts."

queue_job 253 \
  "Fabric comparison design page: same dress silhouette shown in satin, velvet, organza, with bilingual labels. Require clear differences in specular/opacity; readable aligned labels; no trademarks."

queue_job 254 \
  "Hair accessory close-up: metal hairpin with pearl chain in a black velvet box. Require realistic cool metal highlights and micro-scratches, natural pearl sheen; shallow DOF but sharp subject; minimal premium ad composition."

queue_job 274 \
  "Card game card art: card name, cost, effect text (bilingual), illustration of glowing mushroom forest. Require consistent frame ornaments; readable text without overflow; detailed illustration without repetitive AI纹理; game-ready."

queue_job 294 \
  "Urban crime film car interior at night: dashboard glow lights half the face, neon streaks outside window. Require clear low-light detail with controlled noise; neon streaks consistent with long exposure; close-up; oppressive mood."

queue_job 318 \
  "An esports player seated in front of a screen, body leaning forward, eyes locked onto the display. Sharp focused gaze with slightly constricted pupils, faint dark circles under the eyes. Large headset pressing down parts of the hair, strands compressed and deformed, highly concentrated facial expression"

queue_job 319 \
  "A ballet dancer standing on one leg in a practice studio, body maintaining balance. Sweat-dampened bun pressed close to the head, stretched neck and collarbone lines clearly visible. Slight tension in facial muscles, gently pressed lips, skin carrying a subtle post-exertion sheen"

queue_job 358 \
  "1980s retro Synthwave style seaside highway, pink-purple gradient sky, palm tree silhouettes, glowing outlines of sports cars, neon consistency throughout the image."

queue_job 381 \
  "On an icy surface, a penguin glides rapidly, body leaning forward close to the ice, flippers spread to the sides for balance, eyes bright and facing ahead, movements smooth and lively"

queue_job 389 \
  "A little girl tightly grips the string of a red balloon with both hands; the string is taut, and her fingers wrap around the knot in a realistic holding posture."

queue_job 400 \
  "A couple shares an umbrella; the man holds the handle with his left hand, the woman rests her right hand lightly on his arm—bodies close."

queue_job 465 \
  "Viewed straight on in the gallery, three paintings of identical size hang horizontally, spacing between them equal to their width, the group centered on the wall, lower edges aligned, the center painting appearing slightly larger due to perspective"

queue_job 520 \
  "Inside a backpack are neatly arranged three textbooks, a pencil case, and a water bottle; the zipper is fully closed, and the outline bulges slightly from the contents."

queue_job 602 \
  "French culture theme, night city photography composition of the Eiffel Tower dominating the frame, illuminated in warm golden lights with the metal lattice structure clearly defined, deep blue near-night sky, foreground cobblestone path and streetlamps creating leading lines, a couple walking side by side with elongated shadows cast by the lamps, distant Seine river surface reflecting scattered highlights, slight haze softening the glow, cinematic night photography, strong warm-cool contrast, crisp detail without harsh sharpening"

queue_job 603 \
  "British culture theme, wide panoramic view of Big Ben and the modern London skyline along the Thames, heavy overcast gray-blue sky lowering the light, clear clock face on the Elizabeth Tower, visible Gothic Revival stone carvings with subtle gold accents, Thames surface with fine ripples reflecting muted daylight, modern glass towers and bridge silhouettes sharply defined across the river, foreground riverside railing and damp stone steps with wet reflections, overall cool palette, solemn documentary look, rich detail with clear atmospheric perspective"

queue_job 610 \
  "Brazilian culture theme, high vantage panorama of Rio de Janeiro with Christ the Redeemer overlooking the city, statue with outstretched arms dominating the foreground, visible weathered stone texture, dense city blocks spreading to the bay, Sugarloaf Mountain and surrounding ridgelines clearly defined, ocean with blue-green gradients and sun glints, tropical clouds building into a dramatic sky, strong afternoon light and cloud shadows creating patches of contrast across the city, realistic landscape photography emphasizing grand scale and atmospheric depth"

queue_job 737 \
  "A romantic film kissing scene storyboard, starting with a distant shot of the couple approaching, shifting to a side close-up of lips touching, and ending with a gentle exchange of eye contact."

queue_job 741 \
  "A key moment in a football match, starting with a wide shot of cheering spectators, followed by a medium shot of players celebrating a goal, ending with a close-up of the vibrating net."

queue_job 747 \
  "Frame-in-frame composition shooting scenery through a window or archway, framing the visual focus while adding depth and layering."

queue_job 760 \
  "Deep in the tropical rainforest, on a large banana leaf, a chameleon's limbs are tightly gripping the leaf edge, and the suckers at the tips of its toes are clearly visible; the pigment on its body gradually changes from yellowish-green to dark green as it is shaded by the back of the leaf, its eyes move independently, its pupils shrink to vertical lines, the veins of the leaf are etched like silver lines, and water droplets on the edge are about to fall, refracting the dappled sunlight in the forest."

queue_job 801 \
  "Outdoor display of rock balancing: multiple stones touch at tiny points yet the center-of-mass line is plausible. A frosted aluminum placard reads “平衡展 Balance Exhibit” with bilingual stacking, large title and smaller description, strong whitespace. Requirements: crisp stone grains and weathering, consistent shadow direction, soft glare on metal without noise, legible undistorted text; mood quiet and meditative."

queue_job 802 \
  "A sagging wooden bookshelf in disrepair: the middle shelf bows under book weight and spines tilt accordingly. A paper label on the side reads “归还处 Returns” in bilingual stacked layout with even spacing and breathable whitespace. Requirements: realistic wood grain cracks, nail holes and dust buildup; visible paper fibers and curling edges; text crisp with no missing strokes; mood gentle, slightly wistful."

queue_job 823 \
  "Create a brand VI extension: front/back business cards; front has a minimal abstract geometric mark placeholder, back has bilingual name/title/phone. Require accurate legible type aligned to a grid; thick cotton paper emboss texture with realistic shadows; no real brand logo."

queue_job 825 \
  "AR UI poster concept: real street scene with overlaid semi-transparent navigation cards/icons (no real brands), bilingual card titles. Require correct UI perspective and occlusion; crisp text; natural lighting integration without “floating” artifacts."

queue_job 830 \
  "Backstage candid: vanity bulbs glowing, stylist pins a cape and tightens a corset. Require accurate hands/contact interaction, realistic fabric tension; correct mirror reflections without face distortion; composition uses mirror-in-mirror secondary framing."

queue_job 845 \
  "A firefighter standing after removing his helmet, face smeared with an irregular mix of soot and sweat. Skin reddened and rough, facial structure clearly defined, eyes resolute and alert"

queue_job 892 \
  "Indian culture theme, exterior close-up composition of the Taj Mahal in soft morning sunlight, symmetrical white marble structure centered, massive onion dome with a gilded finial clearly visible, four slender minarets with stacked balconies and patterned railings, façade inlaid with floral pietra dura and bordered with Arabic calligraphy, deep arches creating strong light and shadow contrast, foreground long axial water channel and reflection pool with a calm surface mirroring the dome silhouette, neatly trimmed parterre flowerbeds and rows of cypress trees on both sides, red sandstone pathway receding into the distance, light mist with subtle dust sparkle, documentary photography look, delicate stone grain and balanced warm-cool tones"

queue_job 913 \
  "City skyline view, same viewpoint outputting three side-by-side comparative frames (480p / 1080p / 4K) labeled with UI bar at bottom; high-rise window grids and rooftop antennas progressively clearer with increasing resolution; sky gradient smooth with no banding; each frame contains a billboard reading 'CITY LIGHTS', glyphs sharpest in 4K, still decipherable but softer in 480p; typographic alignment consistent across all three frames."

queue_job 915 \
  "Andy Warhol Pop Art style celebrity portrait, face composed of red, yellow, blue Ben-Day dots, high-saturation flat color fields overlaid; contours sharply outlined with bold black lines; background of repeating grid pattern; overall emulating 1960s silkscreen printing mechanical aesthetic and chromatic intensity; facial features recognizable, color contrast strong but harmonious; no AI artifact details."

queue_job 939 \
  "Interior of a modern art exhibition hall: A large abstract sculpture stands in the center, three-meter-wide circular viewing corridor surrounding it, wall-mounted display boards at uniform eye-level height. Visitors can view the sculpture's main body from any angle, guidance markings on the floor of the corridor, overall layout clean and orderly."

queue_job 955 \
  "person lies in a bathtub, with rose petals floating on the surface of the water. The camera is close to the water, capturing the shoulders and collarbone."

queue_job 978 \
  "A library lending rule notice in Irkutsk, Siberia: on pale-yellow parchment paper, handwritten Russian states “Книги выдаются на 14 дней. Продление — только по паспорту.” (Books issued for 14 days. Renewal – passport required only.), with Cyrillic letters like “К” and “П” featuring thick downstrokes per Soviet-era school penmanship; punctuation marks correctly placed, no Western symbols; a corner stamp shows a Lake Baikal silhouette, anchoring locale identity"

queue_job 979 \
  "At a Glühwein stall in Munich’s Old Town Christmas market: a wooden sign on red-and-white checkered cloth reads “Glühwein mit Zimt – 4,50 €” in hand-lettering; nouns “Glühwein” and “Zimt” capitalized per German rules, comma used as decimal separator, with thin space before “€” as per European typographic convention; the umlaut “ü” is hand-drawn distinctly, not replaced with “ue”; steam rises from cups showing floating cinnamon sticks and orange slices"

queue_job 992 \
  "A swimmer performs freestyle strokes in the pool: one arm entering the water and extending forward, the other pulling backward through the water, legs executing continuous flutter kicks."

echo "✅ All 55 jobs queued in scheduler"
