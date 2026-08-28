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
# Theme: Red and Gold Noir — selective color pencil illustrations
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+10+-+red+and+gold+noir
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — Gambling den, mahjong table
prompts+=( "Selective color pencil illustration, urban noir style, optimized for ERNIE Image Turbo. A clandestine gambling den at midnight: six tense figures hunched over a mahjong table under low ceiling, cigarette smoke layered thick. Entire scene in deep black graphite pencil — hatched shadows, cross-hatched faces, stippled smoke texture, heavy vignette. Selective color applied to three objects only — no others. Gold (#C9922A), covering 2–3% of image: the ring worn on the dealer's right hand and a single coin glinting on the table edge — tiny, precise, jewel-like accents. Red (#CC2200), covering 8–12% of image: a round paper lantern hanging directly above the table center, casting a faint red halo, and the dealer's narrow silk sash at waist level. All other elements — players, tiles, smoke, walls, chairs — pure black pencil. ERNIE Image Turbo style directive: selective color pencil drawing, noir atmosphere, object-specific color isolation, no color bleed, sharp linework, dramatic top-down rim lighting." )

# 02 — Rainy crime scene, back alley
prompts+=( "Selective color pencil drawing, noir crime scene, ERNIE Image Turbo optimized. Rain-drenched back alley at 3 AM: a chalk outline on cobblestones, a detective crouching in a trench coat, police tape strung between iron fire escapes. Composition executed entirely in black pencil — aggressive hatching, rain-streak linework, deep shadow pools under overhangs. Selective color, two only: gold (#C9922A) at 1–2% image coverage — the detective's badge catch-light at chest level and one brass shell casing beside the drain — nothing else gold. Red (#CC2200) at 10–15% coverage — blood pooling in the grooves between cobblestones, forming dark rivulets toward the drain, and a smear of red on the lower portion of the brick wall. Both colors exist nowhere else in the image. ERNIE Image Turbo style directive: selective color pencil noir, object-specific color isolation, liquid surface red, metallic gold glint, high-contrast graphite hatching, cinematic rain atmosphere." )

# 03 — Theater backstage before curtain
prompts+=( "Selective color pencil illustration, backstage noir, tuned for ERNIE Image Turbo. Narrow backstage dressing room: a female performer at a mirror lit by bare bulbs, costume half-fastened, tension in her posture — someone dangerous is coming. Full composition in black graphite pencil — layered hatching on fabric folds, stippled face in stage-light shadow, dense black costume detail. Selective color precisely: gold (#C9922A) at 3–5% image area — the ornate gilt frame of the dressing mirror, the performer's pendant earring, and thin necklace chain at her collarbone, rendered as precise fine-line gold detail. Red (#CC2200) at 10–14% — the heavy velvet stage curtain visible through the open doorway behind her, folded and rich, and an open lipstick on the dressing table surface. No other color in the image. ERNIE Image Turbo directive: selective color pencil noir, fabric texture red, metallic fine-line gold, object-specific isolation, dramatic vanity lighting, graphite illustration." )

# 04 — Pawnshop window, midnight browsing
prompts+=( "Selective color pencil drawing, object-study noir, ERNIE Image Turbo optimized. Close exterior view of a pawnshop window at midnight: dense arrangement of hocked objects behind rain-misted glass — watches, a saxophone, rings on velvet trays, cameras, pocket watches, a pawned military medal. Entire composition in meticulous black pencil — hatched glass reflections, cross-hatched velvet folds, stippled fog on the window surface. Selective color: gold (#C9922A) at 4–5% image coverage — the face of a wristwatch at center composition, a ring tray's top row of bands, and the bell of the saxophone behind them — each gold element isolated with no color spreading between objects. Red (#CC2200) at 5–8% — the pawnshop neon sign letters 'LOANS' visible reflected in the top of the glass, and a small red ribbon price tag hanging from the watch. Nothing else colored. ERNIE Image Turbo directive: selective color pencil noir, still-life window composition, isolated gold details, neon red reflection, graphite texture, object-specific color, no bleed." )

# 05 — Harbor dock, smugglers unloading
prompts+=( "Selective color pencil illustration, harbor noir, optimized for ERNIE Image Turbo. Pre-dawn harbor dock: a group of shadowed figures unload unmarked crates from a moored vessel, a heavyset man in an overcoat overseeing — a threat implicit in his stillness. Entire scene in black graphite pencil — hatched water surface with horizontal reflective lines, cross-hatched rope and crane silhouettes, deep shadow under the dock overhang. Selective color, minimal and precise: gold (#C9922A) at 1–2% — a single diagonal lighthouse flash streak crossing the upper dark sky from far right, and the signet ring on the overseer's visible left hand, rendered as a tiny bright point. Red (#CC2200) at 6–10% — the port and starboard running lights of the moored boat at waterline, two small glowing dots, and a distant flare smoke smear at the horizon tinting the far sky edge red. No color exists elsewhere. ERNIE Image Turbo directive: selective color pencil noir, maritime atmosphere, isolated color points, lighthouse streak gold, boat running lights red, dense graphite water texture, cinematic wide composition." )

# --- Gemini 3.1 Flash ---

# 06 — The Exchange at the Red Door
prompts+=( "A traditional, textural graphite pencil drawing with deep charcoal shading, smudges, and heavy cross-hatching. Noir aesthetic. Composition: Medium shot of a man in a fedora and trench coat standing on a rainy sidewalk at night. He is facing a weathered wooden door. Selective Color (Red 10%): The heavy, paneled door is painted a deep, chipped crimson red. Selective Color (Gold 2%): A classic, aged brass door handle and the tiny, glowing end of the detective's cigarette in his hand. ERNIE Optimization: High contrast between the matte black graphite and the intense, sharp selective colors; rich paper texture." )

# 07 — The Office Interrogation
prompts+=( "Gritty charcoal and pencil sketch, dramatic chiaroscuro lighting (Venetian blind shadows), high contrast. Composition: Low angle shot looking across a cluttered detective's desk. A suspect sits under a single, harsh hanging bulb. The scene is dominated by deep black graphite. Selective Color (Red 15%): A rumpled, silk crimson scarf draped over the back of the suspect's chair and a confidential stamp on the file in the foreground. Selective Color (Gold 5%): The detective's gold wedding band resting on the desk and the metal engraving on his badge visible in his wallet." )

# 08 — The Skyline Witness
prompts+=( "Detailed pencil drawing with fine lines and atmospheric blending, capturing a vast, dark urban sprawl. Composition: A female figure (femme fatale) stands in profile on a high balcony, looking over a sprawling city at night. Her coat is rendered in rich, deep graphite blacks. Selective Color (Red 8%): Her vibrant, blood-red lipstick and the brake lights of a single, classic car moving through the dark streets far below. Selective Color (Gold 3%): A delicate, intricate gold necklace resting against her neck and the faint gold trim on her cigarette lighter." )

# 09 — The Threat in the Mirror
prompts+=( "Raw, dynamic charcoal illustration with aggressive pencil lines, smudges, and a sense of movement. Noir thriller mood. Composition: A close-up of a broken rearview mirror reflecting a man's eyes. The main focus is the shattered glass and the heavy shadows. Selective Color (Red 5%): The glowing embers of a lit cigar he holds and a small, narrative trace of fresh blood on a shard of the broken glass. Selective Color (Gold 1%): A tiny, subtle gold initial engraving (e.g., 'R.S.') on the metal frame of the mirror." )

# 10 — The Final Scene (End Credits)
prompts+=( "Sophisticated graphite render with precise detail, resembling a high-end graphic novel illustration. Noir finale. Composition: A wide shot of an abandoned, rain-slicked dockyard at night. A classic coupe is parked under a flickering lamp. The entire scene is heavy graphite greys and blacks. Selective Color (Red 12%): The twin taillights of the classic coupe glowing through the rain and a large, painted red 'X' marking a cargo container in the background. Selective Color (Gold 4%): Sunlight (selective gold) breaking faintly and sharply through the heavy clouds on the very horizon, and decorative gold stitching on a pair of leather gloves left on the wet ground." )

# --- ChatGPT ---

# 11 — Noir Bar Entrance
prompts+=( "noir scene, rainy night outside a dimly lit bar, lone man in trench coat standing under doorway light, cigarette ember glowing red (5-10%), small gold reflections (1-3%) in wet pavement and door handle, deep black shadows dominate 80% of frame, minimal grayscale pencil tones, highly detailed graphite drawing, strong ink outlines, heavy crosshatching, textured paper grain, cinematic composition, selective color only gold and red, high contrast, hard noir aesthetic" )

# 12 — Phone booth silhouette
prompts+=( "classic phone booth in empty street at night, figure inside barely visible, interior light faint, red glow (5-12%) from signage reflecting on glass, tiny gold highlights (1-2%) on raindrops and metal edges, surrounding environment consumed in black ink shadows, minimal graphite shading, ultra-detailed pencil sketch, aggressive crosshatching, noir graphic novel style, cinematic framing, selective color discipline" )

# 13 — Stairwell Descent
prompts+=( "dark concrete stairwell, figure descending into shadow, overhead lamp barely illuminating steps, red accent (5-10%) on warning sign and subtle light spill, very small gold reflections (1-3%) on railings, deep black negative space dominates, high contrast pencil and ink drawing, heavy crosshatching, sharp geometric shadows, gritty noir atmosphere, textured sketch paper, selective color only" )

# 14 — Rainy Car Interior
prompts+=( "interior of car at night, driver seen in silhouette through rain-covered windshield, city lights distorted, red glow (5-15%) from brake lights ahead reflecting across glass, tiny gold highlights (1-2%) in droplets and dashboard details, scene dominated by black ink and minimal graphite, highly detailed pencil illustration, crosshatching, cinematic perspective, tense noir mood, selective color palette" )

# 15 — Fire Escape Shadow
prompts+=( "urban fire escape attached to tall building, figure standing midway between floors, harsh shadows cutting across structure, faint red light (5-10%) from window interior, minimal gold highlights (1-3%) on metal edges catching light, majority of scene in deep black, ultra-high contrast pencil drawing, bold ink lines, heavy crosshatching, graphic noir composition, cinematic vertical framing, selective color only gold and red" )

# --- Grok ---

# 16 — Detective in alley
prompts+=( "Lone detective in fedora and trench coat standing in a dark rainy alley, gun in hand, looking back suspiciously. Noir selective color pencil drawing, dominant heavy black graphite shading and intense cross-hatching, dramatic chiaroscuro lighting. Very sparse selective red (5-15%) only on blood stain and distant neon sign, minimal gold accents (1-5%) on lighter and cigarette glow, deep blacks, moody cinematic atmosphere, intricate pencil texture, high contrast --stylize 750" )

# 17 — Femme fatale in bar
prompts+=( "Seductive femme fatale in a dark bar, red lipstick, elegant black dress, leaning toward the viewer with dangerous eyes, smoke swirling. Selective color pencil illustration for ERNIE Image Turbo, rich dominant black graphite with deep shadows. Selective red (5-15%) strictly on lips and dress detail, minimal gold (1-5%) only on earring and whiskey reflection, strong chiaroscuro, seductive and dangerous noir mood, detailed pencil strokes --stylize 720" )

# 18 — Rain-slicked street, neon sign
prompts+=( "Rain-slicked city street at night, mysterious figure in coat and hat walking under a flickering red neon sign, reflections on wet pavement. Noir selective color pencil drawing, masterful heavy black graphite dominance. Very limited red (5-15%) for the neon sign and its reflections, sparse gold (1-5%) on streetlight halo and window glows, atmospheric fog and rain, cinematic high-contrast composition, intricate pencil texture --stylize 780" )

# 19 — Detective at desk, case file
prompts+=( "Hard-boiled detective at desk in shadowy office, revolver beside open case file, single harsh lamp lighting his face. Selective color pencil sketch, dominant deep black graphite with strong dramatic shadows. Selective red (5-15%) only on blood drop on file and tie detail, minimal gold (1-5%) restricted to lamp filament and badge, tense mysterious atmosphere, ultra-detailed pencil rendering, film noir style --stylize 730" )

# 20 — Woman under streetlamp
prompts+=( "Beautiful dangerous woman standing under streetlamp on foggy noir corner at night, wind blowing her coat, intense gaze. Noir selective color pencil drawing, heavy black graphite shading and texture. Sparse red (5-15%) for lips and dress accent, very minimal gold (1-5%) on necklace and streetlamp warm highlight, dramatic rim lighting, elegant and threatening presence, intricate pencil work, high detail --stylize 760" )

# --- Qwen 3.6 Plus ---

# 21 — The Red Lipstick Clue
prompts+=( "Film noir selective color pencil drawing on textured sketch paper. A close-up of a detective's desk: scattered case files, a smoking ashtray, and a vintage revolver. Rendered entirely in black graphite and charcoal with heavy crosshatching, smudged gradients, and dramatic chiaroscuro lighting. Selective color strictly limited to: 1-5% metallic gold (#D4AF37) as a tiny glint on a wedding ring resting on the desk, and 5-15% deep crimson red (#8B0000) as a single lipstick kiss mark on a confidential letter. Visible pencil strokes, high-contrast noir shadows, hand-illustrated texture. ERNIE Image Turbo optimized: strictly monochrome base, zero other colors permitted." )

# 22 — Rain-Soaked Taxi & Brake Lights
prompts+=( "Urban noir street scene rendered as selective color pencil illustration. A vintage yellow cab (drawn in grayscale) idling at a rainy intersection, driver silhouetted behind fogged glass. Executed in black graphite with directional hatching, stippled rain effects, and deep charcoal shadows. Selective color precisely applied: 1-5% warm gold (#FFD700) as a faint reflection of a distant clock tower on the wet hood, and 5-15% vivid red (#C41E3A) glowing from the taxi's brake lights and reflecting in puddles. Textured paper grain, cinematic framing, stark noir lighting. ERNIE Image Turbo prompt: ONLY gold and red accents at specified ratios, all else pure graphite monochrome." )

# 23 — Jazz Club Backstage Portrait
prompts+=( "Moody noir portrait in selective color pencil style. A jazz singer in a shadowed dressing room, half-face illuminated by a vanity mirror bulb. Drawn in black and gray graphite with meticulous shading, soft smudges for skin tones, and sharp charcoal for costume details. Selective color strictly confined to: 1-5% antique gold (#CFB53B) as the delicate chain of a locket at her collarbone, and 5-15% rich ruby red (#9B111E) as her lipstick and the velvet curtain edge behind her. Visible pencil texture, high-contrast film noir atmosphere, hand-drawn illustration. ERNIE Image Turbo optimized: enforce 1-5% gold, 5-15% red, zero saturation elsewhere." )

# 24 — Alleyway Poker Game
prompts+=( "Gritty noir alley scene as selective color pencil drawing. Three figures huddled around a crate-table playing cards under a single dangling bulb. Rendered in monochrome graphite with heavy shadow blocking, crosshatched clothing textures, and dramatic rim lighting. Selective color accents precisely dosed: 1-5% metallic gold (#E6BE8A) on the face of a single playing card (Ace of Spades emblem), and 5-15% blood red (#8A0303) as a spilled wine stain on the crate and a character's silk tie. Rough sketch paper texture, cinematic noir composition, traditional pencil medium. ERNIE Image Turbo instruction: strictly limit color to gold (1-5%) and red (5-15%), all other areas grayscale only." )

# 25 — Train Station Farewell
prompts+=( "Emotional noir illustration in selective color pencil technique. A lone figure waving goodbye on a foggy platform as a steam train departs. Drawn in black charcoal and graphite with atmospheric perspective, soft smudged fog, and sharp linework for architecture. Selective color applied with surgical precision: 1-5% warm gold (#F5DEB3) as the faint glow of a pocket watch chain in the figure's hand, and 5-15% deep scarlet red (#A52A2A) as the departing train's tail light and a single rose left on the bench. Visible pencil strokes, high-contrast noir mood, hand-illustrated aesthetic. ERNIE Image Turbo optimized: enforce exact color ratios, monochrome graphite base, no additional hues." )

# --- GLM 5.1 ---

# 26 — The Crime Scene
prompts+=( "Noir style selective color pencil drawing, heavy black charcoal and graphite cross-hatching on textured paper. A detective crouching in a pitch-black alleyway examining a chalk outline. Vast majority of the image is pure black pencil shading. Strict selective color ratio: 5-15% vivid red applied only to fresh blood spatters trailing away into the dark, and a tiny, rare 1-5% metallic gold applied only to the glint of a single dropped bullet casing catching a distant streetlight. No other colors. Gritty, high contrast, visible pencil strokes." )

# 27 — The Double-Cross
prompts+=( "Noir style selective color pencil drawing, rough sketch lines and deep black stippling. Close-up of a femme fatale leaning across a dimly lit bar table, whispering a threat. The entire scene is drawn in dark black pencil. Strict selective color ratio: 5-15% striking red applied only to her lipstick and the cherry of her cigarette, and a micro 1-5% bright gold applied only to a small, dangling gold earring catching the ambient light. No other colors. Intense cinematic chiaroscuro, pulp fiction aesthetic." )

# 28 — The Getaway
prompts+=( "Noir style selective color pencil drawing, aggressive black shading with rough scribbled textures. A vintage sedan peeling out on a dark, rain-slicked street. Drawn entirely in heavy black pencil. Strict selective color ratio: 5-15% crimson red applied only to the glowing tail lights of the car and the reflection of a red neon sign in the wet asphalt, contrasted by a minuscule 1-5% shimmering gold applied only to the driver's gold watch catching the dashboard light. High tension, dynamic angle, gritty urban atmosphere." )

# 29 — The Corrupt Deal
prompts+=( "Noir style selective color pencil drawing, fine line work with heavy black shadows. Two men in trench coats standing under a rusted fire escape, exchanging an envelope. Base is pure black pencil. Strict selective color ratio: 5-15% deep red applied only to the red silk lining of the open envelope and a distant red siren glow on the brick wall, and exactly 1-5% metallic gold applied solely to a gold pen clipped inside the envelope. Moody, claustrophobic, dramatic lighting, sketch-like execution." )

# 30 — The Sniper's View
prompts+=( "Noir style selective color pencil drawing, intense black graphite pressure. View looking down the scope of a rifle from a dark, shadowy loft window. The room and the rifle are entirely deep black pencil shading. Strict selective color ratio: 5-15% bright red applied only to the laser sight dot on the target below and the red crosshairs of the scope, and a tiny 1-5% polished gold applied only to the gold trigger of the rifle. Tense, suspenseful, sharp focus on the color accents, textured paper background." )

# --- Kimi K2.6 Thinking ---

# 31 — The Stopped Watch
prompts+=( "Noir graphite pencil illustration, 90% dense black charcoal and graphite covering the frame, a dim crime scene apartment viewed from above, the victim's outline suggested by negative space on hardwood floor, a spreading blood pool rendered in deep crimson red occupying 8% of the composition, a broken gold pocket watch stopped at midnight lying nearby, its face and chain catching faint light in metallic gold comprising only 2% of the image, police tape and window blinds drawn in rough black crosshatching, everything else swallowed in pitch black shadow, visible paper tooth, hand-drawn grain, smudged graphite texture, selective palette: black dominant, crimson red 5-15%, antique gold 1-5%" )

# 32 — The Back Booth
prompts+=( "Noir pencil sketch, overwhelming black graphite shadows, smoky jazz lounge interior, a singer in a rear booth wearing a flowing red satin dress that occupies 10% of the frame as the single vibrant element in a sea of charcoal, her cigarette holder with a thin gold band gleaming at 3%, table lamp casting everything else into deep black void, her lips touched with faint scarlet, whiskey glasses left as gray negative space, visible pencil strokes, rough sketch construction lines, grainy paper texture, selective color strictly limited: 90% black graphite, ruby-to-crimson red 5-15%, warm metallic gold 1-5%" )

# 33 — The Dropped Pen
prompts+=( "Selective-color noir pencil drawing, endless office corridor at 3 AM rendered in dense black graphite and ink, doors on either side consumed by pitch black shadow, a single red EXIT sign at the far end bleeding crimson light across 6% of the frame, a dropped gold fountain pen on the industrial carpet reflecting that sign in pale metallic gold occupying 2%, fluorescent hum suggested with faint pencil texture, rough hatching, smudged charcoal, hand-drawn grain, melancholic corporate noir, palette: black 90%, neon crimson red 5-15%, champagne gold 1-5%" )

# 34 — The Receding Sedan
prompts+=( "Noir pencil illustration, aerial view of rain-soaked freeway at 3 AM, black graphite rendering of wet asphalt and storm dominating the composition, twin red tail lights of a departing sedan glowing in the lower third occupying 7% of the frame, their reflection stretched across rain-slicked concrete in faint red smears, a single distant gold streetlamp rendered in pale amber-gold at 2% providing the only other color point, everything else consumed by charcoal darkness and motion blur suggested with rough pencil strokes, selective color: black base, brake-light red 5-15%, sodium gold 1-5%" )

# 35 — The Vanity
prompts+=( "Noir graphite sketch, backstage dressing room with mirror surrounded by dead black velvet curtains drawn in heavy impasto-like charcoal, a single red rose in a glass vase on the vanity occupying 5% of the frame, its petals the richest blood-red in the composition, a gold lipstick tube cap gleaming beside it at 2%, the mirror reflecting only black void, powder and makeup suggested in gray pencil, light bulb above rendered as negative space, visible sketch lines, theatrical melancholy, strictly limited palette: 90% black, rose-to-blood red 5-15%, pale champagne gold 1-5%" )

# --- Deepseek ---

# 36 — The Last Bet
prompts+=( "Noir selective color pencil drawing, ERNIE Turbo style. Black pencil dominates: a gambler's hand resting on a stained poker table, a spent matchstick, heavy blinds casting shadows across a fedora. Red (5-15%): the gambler's cracked lip, a chip edge, a distant exit sign glow. Gold (1-5%): a single wedding ring on the table, and the tiny number on a die. Gritty cross-hatching, moody, near-monochrome except those two accents." )

# 37 — Lipstick on a Cigarette
prompts+=( "Noir pencil illustration, selective color. Black: a femme fatale's profile, cigarette smoke curling up, venetian blind stripes on the wall. Red (5-15%): her nail polish, the cigarette tip's cherry glow, a smear on a whiskey glass rim. Gold (1-5%): a thin necklace chain and the reflection in her eye. Rough paper texture, charcoal edges, low key lighting, ERNIE Turbo fidelity." )

# 38 — Blood on the Dashboard
prompts+=( "Selective color noir pencil drawing. Black: a crashed car interior, shattered windshield, a slumped driver's trench coat. Red (5-15%): blood trickling from the driver's hand onto the dashboard, and a broken tail light outside. Gold (1-5%): a St. Christopher medal dangling from the rearview mirror, and the key still in the ignition. Heavy shadows, dramatic side light, ERNIE Turbo grain." )

# 39 — The Velvet Rope Exit
prompts+=( "Noir pencil, selective color. Black: a nightclub back alley, a man in a suit leaning against a brick wall, a bouncer's silhouette. Red (5-15%): the velvet rope's color, the man's tie, and a neon 'EXIT' sign bleed. Gold (1-5%): a cufflink, the glint of a zippo lighter flame. Gritty, rain-wet pavement suggested in black pencil, very limited color splash, ERNIE Turbo style." )

# 40 — Phone Booth Letter
prompts+=( "Selective color noir pencil drawing. Black: a phone booth, a detective reading a note, coiled cord, street lamp silhouette. Red (5-15%): the lipstick-kiss seal on the envelope, and a nearby stoplight's red glow. Gold (1-5%): the detective's watch face and the tiny 'OUT OF ORDER' plaque on the phone. Vertical composition, deep blacks, harsh shadows, ERNIE Turbo optimized for pencil texture." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
