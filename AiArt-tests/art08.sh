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
# Refactored & Expanded to 100 tasks total
# Theme: Charcoal + selective neon amber pencil noir illustration series
# Structure: SUBJECT, ACTION, ENVIRONMENT, STYLE
# ---------------------------------------------------------------------------
prompts=()

# 01
prompts+=( "SUBJECT: An A-shaped blackboard sign with handwritten text: '@liutyi' (top line), '500 followers' (underlined), and 'Thank you!' above a bright amber heart. A café storefront named 'CivitAi' with a hexagonal 'C' logo is faintly visible in the background.
ACTION: Figures walking on the street appear as blurred, transparent black charcoal silhouettes mimicking a long exposure photographic effect; passing bicycles leave dynamic light trails.
ENVIRONMENT: A rainy Italian city cobblestone street at night. Square composition, low-angle perspective.
STYLE: Film noir illustration combining deep charcoal blocks with sharp pencil sketch lines. Monochromatic base with selective neon amber highlights on the heart, text lines, and light trails. High-fidelity paper grain texture." )

# 02
prompts+=( "SUBJECT: Silhouette of a woman wearing a long winter coat.
ACTION: The woman walks away from the viewer down a wet sidewalk.
ENVIRONMENT: Rainy autumn New York City street at night. A vintage fire hydrant stands in the foreground; volumetric steam rises from grates; dead maple leaves fall through the air.
STYLE: Charcoal and neon amber pencil noir illustration. Deep monochrome blacks and ink washes with striking selective color accents on the falling leaves, steam edges, and wet pavement reflections. Gritty sketch textures." )

# 03
prompts+=( "SUBJECT: Silhouette of a woman in a tattered trench coat whose hem dissolves into writhing, shadowy tendrils. A rusted fire hydrant, shattered glass bottles, and a discarded creepy porcelain doll in the foreground. Distorted faces peer from background windows.
ACTION: The woman walks away down a cracked, bleeding sidewalk. Volumetric steam twists into screaming spectral faces and reaching skeletal hands.
ENVIRONMENT: Haunted, decaying autumn night in New York City. Cinematic low-angle framing, deep depth of field, claustrophobic atmosphere.
STYLE: Eldritch horror noir illustration. Gritty textured charcoal drawing with sharp, aggressive pencil sketch lines. Dominated by deep monochrome blacks, heavy ink washes, and ash grays. Selective color accent: sickening, vibrant neon amber light reflecting intensely off a pool of dark, blood-like liquid on the pavement, illuminating steam-claws and falling leaves." )

# 04
prompts+=( "SUBJECT: Silhouette of a woman, a vintage cast-iron fire hydrant with delicate metallic texture, and scattered wet maple leaves.
ACTION: The woman walks towards the foreground through thick, voluminous steam rising from street sewer grates.
ENVIRONMENT: Rainy autumn night in New York City. Square-framed, film-noir cinematic composition, low-angle perspective.
STYLE: Richly textured charcoal drawing with sharp pencil sketch details. Main palette consists of deep monochrome black, ink washes, and dark gray. Extreme selective coloring: vibrant neon amber light strongly reflecting on wet pavement, outlining contours of fluttering leaves, and casting a mesmerizing halo on the rising steam. Subtle paper grain." )

# 05
prompts+=( "SUBJECT: Silhouette of a woman and a vintage cast-iron fire hydrant.
ACTION: The woman approaches through thick steam toward the viewer. Scattered, wet maple leaves swirl in the air.
ENVIRONMENT: Rainy autumn night in New York City. Cinematic low-angle framing, deep depth of field, atmospheric perspective.
STYLE: Noir illustration with textured charcoal drawing and sharp pencil sketch details. Dominated by deep monochrome blacks, ink washes, and dark grays. Selective amber accent: vibrant neon amber light reflecting intensely on the wet pavement, catching edges of falling leaves and rising steam." )

# 06
prompts+=( "SUBJECT: Silhouette of a woman in a coat and a vintage cast-iron fire hydrant.
ACTION: The woman walks away through the scene. Thick volumetric steam rises from a street grate; wet falling maple leaves swirl.
ENVIRONMENT: Rainy autumn night in New York City. Cinematic framing, low-angle shot, deep depth of field, atmospheric perspective.
STYLE: Noir illustration with textured charcoal drawing and sharp pencil sketch details. Dominated by deep monochrome blacks, ink washes, and dark grays. Striking selective color accent: vibrant neon amber light reflecting intensely on the wet pavement, bleeding edge of the coat, catching the edges of falling leaves and rising steam." )

# 07
prompts+=( "SUBJECT: Silhouette of a woman in a coat walking toward the viewer.
ACTION: The woman moves along a wet sidewalk. Fire hydrant, rising steam, and falling leaves add to the mood.
ENVIRONMENT: Rainy autumn New York street at night, viewed as a POV from inside a New York taxi cab looking out.
STYLE: Charcoal and neon amber pencil illustration. Heavy black charcoal blocks for environmental structures, with selective neon amber color accents on reflections, steam, and highlights. Gritty hand-drawn texture." )

# 08
prompts+=( "SUBJECT: A woman leaning forward against a taxi window, one hand gripping the door frame; a vague silhouette of a passenger is visible inside through the rain-streaked glass. A fire hydrant stands behind her, mirrored in a puddle.
ACTION: The woman stands on a wet sidewalk while thick steam rises from a cylindrical steam vent around her legs, dissolving her lower silhouette.
ENVIRONMENT: Wet outdoor New York street at night. Square proportion, cinematic close-up composition.
STYLE: Hand-drawn illustration combining charcoal blocks and neon amber pencil strokes. Monochromatic black, white, and gray charcoal base. Selective neon amber accents: taxi interior ceiling light illuminating faces, raindrops shimmering on the woman's eyelashes, wet metal top of the fire hydrant, and the steam column radiating a dazzling amber halo under a streetlamp. Aggressive diagonal pencil hatching for rain streaks, layered charcoal smudges, rough paper texture." )

# 09
prompts+=( "SUBJECT: Silhouette of a woman outside on a wet sidewalk gripping a taxi door frame, leaning toward the glass; a seated passenger silhouette inside the cab. A fire hydrant stands behind her, mirrored in a gutter puddle. Sidewalk steam cylinders emit thick vapor around her legs.
ACTION: The two silhouettes face each other across the rain-streaked rear window frame.
ENVIRONMENT: Rainy New York City street at night, viewed from inside a taxi cab looking out. Cinematic close framing.
STYLE: Noir illustration with aggressive diagonal pencil hatching for rain streaks. Heavy charcoal blocks define glass, asphalt, and dark building facades with layered smudges for shadow depth. Monochrome charcoal base with selective amber accents: taxi interior dome light illuminating faces, raindrops on eyelashes, wet metal crown of the fire hydrant, and a steam column glowing under a streetlamp. High-fidelity pencil texture." )

# 10
prompts+=( "SUBJECT: A lone figure with an upturned collar standing on a Gothic bridge overlooking a dark river. A single vintage streetlamp.
ACTION: The figure stands still, gazing down, as its shadow stretches out into the dark waters.
ENVIRONMENT: Dark city river at midnight. Extreme low-angle framing, cinematic fog lighting, claustrophobic atmosphere.
STYLE: Noir graphic novel cover art. Heavy jet-black charcoal blocks for the bridge cables and city skyline. Sharp aggressive pencil strokes, ink-heavy shadows, and high-fidelity pencil texture. Selective neon amber pencil highlights on the streetlamp, its long reflection on the water surface, and the figure's collar." )

# 11
prompts+=( "SUBJECT: A narrow city alley after rain with tall brick walls, staggered metal fire escapes, large dark trash cans in a corner, a neon sign reading 'OPEN', and a pair of glowing cat eyes in deep shadows.
ACTION: The perspective looks up between the buildings; the cat eyes gaze eerily ahead from the dark corner.
ENVIRONMENT: Narrow urban alleyway after rain. Square composition, extreme low-angle shot, cinematic backlighting.
STYLE: Graphic novel film noir visual style. Drawn with high-fidelity charcoal and pencil textures. Pure black, white, and gray base with heavy ink-like shadows and sharp aggressive pencil strokes. Vibrant amber pencil highlights on the 'OPEN' neon sign, its reflection on the wet puddled ground, and the cat's eyes. Granular charcoal powder paper texture." )

# 12
prompts+=( "SUBJECT: A narrow alleyway with brick walls, dumpsters, fire escapes, a flickering neon sign reading 'OPEN', and a cat's eyes in the shadows.
ACTION: The scene captures the wet urban environment after rain with heavy ambient tension.
ENVIRONMENT: Post-rain urban alleyway at night. Low angle looking up at fire escapes, tense moody atmosphere, cinematic backlighting.
STYLE: Graphic novel panel composition, film noir aesthetic. Heavy dark charcoal blocks for brick walls and dumpsters. Sharp aggressive pencil strokes and ink-heavy shadow style. Selective vibrant amber pencil highlights on the 'OPEN' sign, its wet pavement reflection, and the cat's eyes. High-fidelity pencil texture." )

# 13
prompts+=( "SUBJECT: A lone figure silhouette waiting on a subway platform beside a tunnel mouth, glowing train windows, a single overhead platform light, and a large puddle on the tracks.
ACTION: The figure waits silently as a train approaches at midnight.
ENVIRONMENT: Rain-soaked subway platform at midnight. Cinematic low angle from the track level, lonely moody atmosphere, cinematic volumetric lighting.
STYLE: Film noir comic art. Heavy jet-black charcoal blocks for the tunnel mouth and platform architecture. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights on the glowing train windows, overhead light, and its long reflection in the puddle." )

# 14
prompts+=( "SUBJECT: A solitary human silhouette standing silently on a platform with weathered walls and a station sign reading 'TRACK 4'. Glowing train windows and a solitary overhead light.
ACTION: The figure waits next to a deep tunnel entrance under the dim overhead lamp.
ENVIRONMENT: Rain-washed subway platform at midnight. 1:1 square composition, cinematic low-angle shot from train track height, extremely somber and lonely atmosphere.
STYLE: Hand-drawn illustration with charcoal and colored pencil textures. Thick, jet-black charcoal strokes and dark, inky shadows on rough paper. Aggressive, sharp, dense pencil lines. Selective neon amber pencil highlights on the train's windows, the overhead light, its long bright reflection in a puddle beside the tracks, and the 'TRACK 4' text outline, creating a cinematic volumetric lighting effect." )

# 15
prompts+=( "SUBJECT: A detective's office at 3 a.m. with a heavy wooden desk, stacks of scattered case files, a vintage metal desk lamp, an ashtray with a burning cigarette casting wisps of smoke, and a revolver flat on the desk.
ACTION: External light projects sharp shadows of horizontal and oblique venetian blinds across the walls and furniture.
ENVIRONMENT: Late-night detective office. Square composition, low-angle shot, viewed as if peering through the gaps in the blinds in the foreground. Somber, heavy, and suspenseful film noir atmosphere.
STYLE: Hand-drawn sketch illustration with cinematic contrast. Large areas rendered with thick, deep charcoal black blocks and ink-like shadows. Sharp, aggressive, intricate pencil lines intertwining with rough charcoal strokes on sketch paper. Selective bright amber pencil marks highlight the desk lamp glow, the amber-edged smoke wisps, and the sharp amber reflection on the revolver's cylindrical barrel." )

# 16
prompts+=( "SUBJECT: A solitary saxophonist with his head tilted back, immersed in his performance on a dimly lit stage. Architectural background and audience silhouettes are obscured by deep black shadows. Thick haze and ethereal smoke permeate the air.
ACTION: A single spotlight shines from above, forming a sharp cone-shaped beam that envelops the musician.
ENVIRONMENT: Underground jazz club at night. Square composition, low-angle shot looking up from the audience, cinematic edge lighting, tense emotional atmosphere.
STYLE: Graphic novel noir aesthetic with high-fidelity graphite textures and heavy ink shadows. Thick, dark charcoal blocks of color. Sharp, bold, highly expressive pencil strokes. Selective neon amber pencil highlights precisely delineate the metallic sheen and mechanical structure of the brass saxophone, the edge trajectory of the spotlight cone, and the reflection on the rim of a whiskey glass on a blurred foreground table." )

# 17
prompts+=( "SUBJECT: Silhouette of a woman in a coat on a wet sidewalk with her hand on a taxi door, leaning in to speak; a passenger silhouette inside the cab. A fire hydrant stands behind her, mirrored in gutter water. Steam rises from sidewalk cylinders around her legs.
ACTION: The woman interacts with the passenger across a rain-streaked taxi window frame.
ENVIRONMENT: New York City street in heavy rain at night, viewed from inside the taxi looking out the rear window. Intimate romantic-noir atmosphere, cinematic interior-exterior contrast lighting.
STYLE: Film noir sketch illustration. Heavy dark charcoal blocks for the rain-streaked glass, wet street, and surrounding buildings. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the taxi's interior dome light catching their faces, the woman's raindrop-covered eyelashes, the fire hydrant's wet metal top, and the steam glowing from the streetlamp above." )

# 18
prompts+=( "SUBJECT: Silhouette of a woman pausing mid-step, looking back over her shoulder; a man's silhouette stands on the opposite curb with a hand half-raised in goodbye. A fire hydrant anchors the left foreground. A taxi rushes between them. Steam billows from subway cylinders.
ACTION: The taxi moves past in a blur of black as the couple shares a parting glance at midnight across the avenue.
ENVIRONMENT: Wide New York crosswalk at midnight. Street-level framing, bittersweet romantic atmosphere, cinematic motion-blur lighting.
STYLE: Film noir comic panel. Heavy dark charcoal blocks for the avenue, surrounding skyscrapers, and the blurring taxi. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the taxi's brake lights, the woman's eye glint, the fire hydrant's side nozzle, and the steam catching the avenue's single working streetlamp." )

# 19
prompts+=( "SUBJECT: Silhouette of a couple dancing mid-step (man's coat flaring, woman's heel lifted against a brick wall). Dumpsters, fire escapes, a fire hydrant spraying a thin mist, and a taxi waiting at the alley mouth. Steam drifts across the scene.
ACTION: The couple dances in a secluded urban passage at night amidst rising steam.
ENVIRONMENT: Rain-slicked New York alley at night. Low-angle framing, romantic-noir atmosphere, cinematic backlighting.
STYLE: Graphic novel illustration. Heavy jet-black charcoal blocks for dumpsters, fire escapes, and the idling taxi silhouette. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the couple's interlocked hands, the taxi's illuminated rooftop sign, the fire hydrant's brass cap, and the steam backlit by a distant streetlamp." )

# 20
prompts+=( "SUBJECT: Two walking silhouettes bumping into each other with coats flaring and outlines nearly touching. A parked taxi at the curb, and a fire hydrant standing sentinel on the corner swallowed by shadow. Steam rises from a cylinder vent.
ACTION: The couple locks eyes as they collide near the steaming vent on the rainy street corner.
ENVIRONMENT: New York street corner at night. Romantic moody atmosphere, cinematic volumetric lighting, heavy architectural depth.
STYLE: Film noir pencil sketch. Heavy dark charcoal blocks for the surrounding architecture and wet asphalt. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the rising steam from the cylinders, the taxi's roof light, the fire hydrant's top valve, and the single streetlamp catching their locked gaze." )

# 21
prompts+=( "SUBJECT: Silhouette of a romantic couple walking, a fire hydrant, steam cylinders, and a taxi.
ACTION: The couple walks along a classic urban sidewalk at night.
ENVIRONMENT: Rainy New York City street at night. Melancholic, cinematic framing.
STYLE: Pencil drawings with a selective color scheme. Base composed of rough charcoal black blocks and deep graphite shading. Striking selective neon amber color accents highlighting the fire hydrant top, taxi roof light, and glowing street steam. High-contrast noir texture." )

# 22
prompts+=( "SUBJECT: Silhouette of a romantic couple, a fire hydrant, steam, and a taxi.
ACTION: The figures move through a moody urban setting in the dead of night.
ENVIRONMENT: New York City street at night. Minimalist, evocative film noir staging.
STYLE: Pencil drawings featuring a dual palette of selective neon amber and charcoal black. Heavy charcoal smudging for shadows and sharp pencil hatching for atmospheric details. High contrast, gritty texture." )

# 23
prompts+=( "SUBJECT: A Con Edison steam cylinder with a ribbed surface glistening with running rain, its base surrounded by scattered wet leaves plastered to the puddled pavement. A yellow cab is half-visible through the storm. A lone figure in a long coat stands silhouetted.
ACTION: The steam plume bends sideways violently in a cold wet wind, losing its vertical authority for the first time in five seasons, as the figure leans into the gale.
ENVIRONMENT: Manhattan sidewalk at rainy autumn dusk. Cinematic storyboard panel, diagonal wind-driven composition, elegiac end-of-year noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette locked strictly to jet black and neon amber. Directional crosshatching follows the wind angle on the steam, rain, and coat. Heavy ink outlines on the cylinder silhouette, softening to loose strokes on windblown steam edges. Textured paper grain with subtle film grain. Amber reflections fracture across rain-disturbed puddles into broken tessera patterns." )

# 24
prompts+=( "SUBJECT: An orange Con Edison steam cylinder centered on puddle-covered pavement. A yellow cab ghosts through the background. A lone figure without an umbrella stands perfectly still. Sidewalk tree leaves are barely suggested as fine filigree at the frame's upper edge.
ACTION: Steam mixes gently with light warm rain, creating a soft, diffused halo rather than a hard column, capturing the seasonal ambiguity of vapor and rainfall made inseparable.
ENVIRONMENT: Manhattan sidewalk on the first warm rainy night of spring. Cinematic storyboard panel, intimate mid-shot composition, quietly melancholic spring noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette strictly limited to jet black and neon amber. Dense diagonal hatching renders rain dissolving into soft steam texture above cylinder height. Contrasting line weights differentiate hard rain strokes from soft steam cross-contours. Deliberate ink outlines on textured paper grain with subtle film grain. Long amber cab reflection stretches across the flooded gutter; leaves catch amber backlight." )

# 25
prompts+=( "SUBJECT: An orange Con Edison steam cylinder standing alone on a glazed black-ice sidewalk. A yellow cab and a lone figure in an overcoat gripping a lamp post for balance. No snow is present.
ACTION: The steam column rises perfectly vertical, sharp-edged and dense with no diffusion in windless frozen air, while the yellow cab fishtails slightly on the ice at the intersection edge, caught in a single frozen moment.
ENVIRONMENT: Empty Manhattan avenue at 5 a.m. in dry sub-zero cold. Cinematic storyboard panel, wide low-angle composition emphasizing the ice mirror foreground, crystalline frozen noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette locked to jet black and neon amber. Crosshatching shifts from rough on the coat and cab to obsessively fine on the ice reflections. Precise ink outlines on textured paper grain with subtle film grain. Black ice renders every amber reflection as a perfect mirror shard across the entire foreground; the vertical steam column acts as a geometric counterpoint to the diagonal slip of the cab." )

# 26
prompts+=( "SUBJECT: An orange Con Edison steam chimney erupting from center pavement, its base half-buried in a pushed snow bank. A yellow cab crawling past with tire track patterns in fresh snow. A lone figure wrapped in a heavy coat and scarf.
ACTION: The steam plume explodes upward with maximum winter force, instantly shredding into snowflakes to create an indistinguishable collision of steam and blizzard. The figure's breath adds a small personal plume at shoulder height as their scarf whips sideways.
ENVIRONMENT: Midtown Manhattan sidewalk in heavy snowfall. Cinematic storyboard panel, vertical monumental composition centered on the cylinder tower, brutal winter noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette strictly jet black and neon amber. Dense crosshatching captures snow accumulation and steam turbulence, while fresh snowfall is stippled in fine ink dots merging with steam wisps. Bold ink outlines on the cylinder and coat silhouette, set against a textured paper grain with subtle film grain under an absolute jet-black winter sky. The amber cab roof light provides the sole point of warmth." )

# 27
prompts+=( "SUBJECT: An orange Con Edison steam cylinder rising dead-center from a manhole, flanked by a fire hydrant and an overflowing trash can in the foreground. A yellow cab stopped at the curb with its engine running. A lone figure in short sleeves with hands in pockets.
ACTION: Steam pours upward and spreads flat against hot humid air rather than rising, with heat suppressing the plume into a low spreading halo. The cab adds its own exhaust to the haze.
ENVIRONMENT: Manhattan sidewalk in an oppressive midsummer night. Cinematic storyboard panel, low wide-angle composition with the cylinder dominating the center foreground, sweltering airless noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette locked to jet black and neon amber only. Ribbed cardboard column rendered in neon amber against absolute jet black. Fine crosshatching differentiates steam texture from humid haze, with sharp ink outlines on the cylinder ribs and cab roofline. Textured paper grain, subtle film grain, and amber reflections pooling in heat-cracked asphalt seams." )

# 28
prompts+=( "SUBJECT: A line of yellow cabs trailing exhaust vapor and steam grate clouds. A figure hailing a cab from the curb with an arm raised mid-gesture. An overhead traffic signal hangs in a jet black sky.
ACTION: Light snowfall merges with rising steam, creating an unbroken fog corridor down the block. Snowflakes dissolve into steam above street level.
ENVIRONMENT: Wide uptown avenue at night. Cinematic storyboard panel, grand avenue composition with a long receding avenue forming a one-point perspective spine, frozen noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette strictly jet black and neon amber. Varied crosshatching distinguishes snow from steam and exhaust vapor. Precise ink outlines on textured paper grain with subtle film grain. No warmth except for the neon amber traffic signal and taxi highlights; everything else is absolute black and gray pencil texture." )

# 29
prompts+=( "SUBJECT: A corner grocery store (Bodega) with an awning and a hand-drawn sign, a taxi parked side-by-side over a sewer grille emitting thick steam, and two dark figures (one ducking inside the glass door, one emerging clutching a paper bag).
ACTION: The figures move past the entrance; thick steam drifts upwards and brushes past the edge of the bodega awning while the taxi's hazard lights flash.
ENVIRONMENT: Manhattan street corner at 1 a.m. Cinematic storyboard panel, 1:1 square format, shallow diagonal perspective from across the intersection, raw cinematic noir atmosphere.
STYLE: Highly detailed pencil sketch in a graphic novel style. Color palette strictly limited to pure black and neon amber. Hand-drawn sign stands out against a neon amber backlight displaying 'DELI & GROCERY' and 'OPEN 24 HOURS'. Wet asphalt reflects a strong amber glow, and the taxi's roof light shatters into mottled reflections on the rain-soaked sidewalk. Dense, intricate cross-hatching on brick facades and taxi panels; strong ink outlines, rough papery texture, and subtle film grain." )

# 30
prompts+=( "SUBJECT: A lone yellow cab crossing the bridge deck, the bridge's robust cable-stayed structure extending diagonally upwards, and massive stone towers looming as a dark mass behind river fog. No pedestrians.
ACTION: The cab travels across the bridge, half its body swallowed by dense river fog rising from between the cables, its headlights piercing the mist.
ENVIRONMENT: Lower approach to the Brooklyn Bridge at pre-dawn. Cinematic storyboard panel, asymmetric wide composition, desolate and suspenseful film noir atmosphere conveying urban loneliness.
STYLE: Highly detailed hand-drawn pencil illustration in a graphic novel style. Strict duotone of pitch black and neon amber. Cab headlights throw twin neon amber cones forward through the vapor. Stone masonry and cables covered in incredibly fine crosshatching, with deliberate ink outlines. Rough paper texture and subtle film grain; the dense fog completely obliterates mid-ground details." )

# 31
prompts+=( "SUBJECT: A yellow cab double-parked over a street grate, a bodega awning with hand-lettered signage, and two figures (one ducking through a glass door, one exiting clutching a paper bag).
ACTION: Thick steam rises from the grate directly beneath the cab's front wheel and wisps past the awning edge while hazard lights flash.
ENVIRONMENT: Manhattan street corner at 1 a.m. Cinematic storyboard panel, shallow diagonal perspective from across the intersection, intimate corner composition, gritty corner-store noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette locked exclusively to jet black and neon amber. Tight crosshatching on brick facades and cab door panels with strong ink outlines. Textured paper grain with subtle film grain; cab hazards and roof light reflections fracture across the rain-slicked sidewalk against an amber backlight." )

# 32
prompts+=( "SUBJECT: A lone yellow cab on the bridge deck, massive stone towers, and sweeping suspension cables. No pedestrians.
ACTION: The cab crosses the bridge while being partially consumed by river fog rising between the cables; its headlights pierce the vapor.
ENVIRONMENT: Lower approach to the Brooklyn Bridge at pre-dawn. Cinematic storyboard panel, asymmetric wide composition, desolate noir atmosphere of absolute urban solitude.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette strictly jet black and neon amber. Suspension cables vanish into a jet-black fog above, while headlights throw twin neon amber cones forward. Fine crosshatching on cable textures and stone masonry with deliberate ink outlines. Textured paper grain and subtle film grain; fog erases all mid-ground details beyond the cab as diagonal cables act as dramatic perspective anchors." )

# 33
prompts+=( "SUBJECT: Four yellow cabs positioned bumper-to-bumper, multiple steam vents between vehicles, a vibrating manhole cover in the foreground, and a lone figure in a trench coat.
ACTION: The figure threads between frozen traffic while steam vents erupt, creating a low fog river along the gutter.
ENVIRONMENT: Midtown Manhattan gridlock at midnight. Cinematic storyboard panel, deep tunnel composition with a strong one-point perspective pulling into darkness, suffocating gridlock noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Palette locked strictly to jet black and neon amber. Heavy crosshatching on cab rooflines and steam textures with bold ink outlines. Textured paper grain and subtle film grain; taxi roof lights and distant traffic signals rendered as neon amber points dissolving into a jet-black atmosphere that layers the mid-ground into near-silhouette." )

# 34
prompts+=( "SUBJECT: A yellow cab idling at a red light, a curbside grate surging with steam, a crosswalk countdown sign, and distant marquee lettering. A driver's silhouette is visible through the windshield.
ACTION: Steam surges from the grate, completely swallowing the cab's rear wheels and diffusing light upward.
ENVIRONMENT: Times Square at the dead of night between billboard cycles. Cinematic storyboard panel, centered axial composition compressed by vertical skyscraper canyon walls, oppressive noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Jet black and neon amber only, with no other colors permitted. The steam column is backlit into a vibrant neon amber against an absolute jet-black sky. Dense crosshatching on the cab bodywork and asphalt with crisp ink outlines. Textured paper grain and subtle film grain." )

# 35
prompts+=( "SUBJECT: A laundromat with a fogged plate-glass window, a lone figure seated inside as a soft silhouette, a pedestrian outside pressing a palm to the glass, and wet brick walls with puddles.
ACTION: Condensation streaks run down the window as the interior light glows through the vapor toward the rainy exterior.
ENVIRONMENT: Rain-soaked urban side street at 2 a.m. Cinematic storyboard panel, split foreground-background composition with a tender noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Minimal color palette of charcoal black, graphite gray, and amber-yellow highlights. Fine crosshatching and deliberate ink outlines on a textured paper grain with subtle film grain. Shallow depth of field implied through line weight contrast; condensation renders breaking interior details into abstraction as puddles reflect the warm amber-yellow glow." )

# 36
prompts+=( "SUBJECT: A massive iron railway bridge spanning a dark river, factory chimneys belching thick black smoke, a distant city skyline, and a lone worker in heavy overalls leaning against a rusty railing.
ACTION: The worker silently gazes downstream while smoke and haze swallow the distant skyline.
ENVIRONMENT: Heavy industrial film noir setting at night. Square composition, wide panoramic view utilizing dramatic horizontal depth lines, oppressive and retro atmosphere.
STYLE: Hand-drawn, graphic novel-style storyboard panel. Minimalist palette dominated by charcoal black and steel gray, accented with dark copper/amber highlights. Highly detailed pencil drawing techniques using dense cross-shading lines and clear ink outlines. Surface features a distinct rough paper texture and subtle film grain; diffused smoke blurs the mid-ground while faint amber traffic lights reflect on the black water." )

# 37
prompts+=( "SUBJECT: Stone bridges, a lone cyclist pushing a bicycle, moored canal boats in silhouette, and a single lamp post.
ACTION: Dense ground fog erases the waterline and swallows the lower half of the stone bridges as the cyclist crosses.
ENVIRONMENT: Urban canal district at pre-dawn. Cinematic storyboard panel, asymmetric composition with receding bridge arches acting as perspective anchors, melancholic noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Minimal color palette of charcoal black, cool graphite, and ice-blue/amber highlights. Fine crosshatching and precise ink outlines on a textured paper grain with subtle film grain. Fog density is graduated from foreground to background, and the lamp post casts a weak cone of light into layered vapor." )

# 38
prompts+=( "SUBJECT: An iron railway bridge over a dark river, factory smokestacks exhaling thick plumes, a distant city silhouette, and a solitary worker leaning on a rusted railing.
ACTION: The worker gazes downstream as smoke haze swallows the background.
ENVIRONMENT: Industrial urban center at night. Cinematic storyboard panel, wide panoramic composition with dramatic horizontal depth lines, heavy industrial noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Minimal color palette of charcoal black, steel gray, and dull copper/amber highlights. Fine crosshatching and crisp ink outlines on textured paper grain with subtle film grain. Diffuse smoke blurs the mid-ground while amber signal lights reflect on the black water surface below." )

# 39
prompts+=( "SUBJECT: A narrow back-alley food stall with a weathered counter, boiling vats, a lone chef, a single customer hunched on a wooden stool, paper lanterns, and Chinese/Korean signage.
ACTION: Steam erupts from the boiling vats behind the counter, forming curling strands that shroud the chef and signage.
ENVIRONMENT: Narrow back alley at night. Cinematic storyboard panel, centered composition with converging perspective lines pulling the eye to the stall opening, intimate noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Minimal color palette of deep charcoal, slate gray, and pale gold/amber highlights. Fine crosshatching and clean ink outlines on textured paper grain with subtle film grain. Paper lanterns and windows are blurred by condensation." )

# 40
prompts+=( "SUBJECT: Iron subway grates beneath an overpass, cracked concrete and rusted drain covers in the foreground, sodium arc lamps, and a solitary figure in a long coat.
ACTION: Steam billows from the subway grates, enveloping the figure as they pause mid-step.
ENVIRONMENT: Winter midnight downtown. Cinematic storyboard panel, balanced composition with strong vertical lines, claustrophobic noir atmosphere.
STYLE: Highly detailed pencil drawing in a graphic novel style. Minimal color palette of jet black, ash gray, and burnt sienna/amber accents. Dense crosshatching and bold ink outlines on textured paper grain with subtle film grain. Dense steam diffuses light from sodium arc lamps, casting vibrant amber halos through the rising mist." )

# 41
prompts+=( "SUBJECT: A figure standing in headlight beams with a grinning teeth expression and a bloodstained coat, twisted trees, and a car dashboard.
ACTION: The driver's headlights pass straight through the figure's torso, leaving a gaping hole where organs should be, as rain falls straight through the empty coat.
ENVIRONMENT: Desolate country road at midnight in heavy rain. Driver's low-angle POV through the windshield, isolating moody atmosphere.
STYLE: Ghost horror noir art. Heavy jet-black charcoal blocks for twisted trees, the dashboard, and a road vanishing into the void. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights headlight halos, the grinning teeth, a distant road reflector, and the permanent bloodstain. Cinematic headlight glare lighting." )

# 42
prompts+=( "SUBJECT: A small child-shaped silhouette sitting in a corner, a rusted crib, a collapsed rocking horse, peeling wallpaper, a cracked mobile spinning overhead, and a half-burned candle dripping wax.
ACTION: The child silhouette sits without casting a shadow, its head tilted at a broken angle, fingers tracing patterns in the dust.
ENVIRONMENT: Long-abandoned nursery in a tenement building. Low angle near the floorboards, uncanny moody atmosphere.
STYLE: Ghost horror noir art. Heavy dark charcoal blocks for the peeling wallpaper, crib, and rocking horse. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the candle, the child's hollow eye sockets, the spinning mobile, and the dust-trail patterns that glow faintly before fading. Cinematic corner-shadow lighting." )

# 43
prompts+=( "SUBJECT: A silent procession of submerged, pale, featureless figures wearing bloated, drifting clothes, concrete pillars, rusted rebar, a submerged streetlamp, and an oil-slick surface.
ACTION: The figures walk through waist-deep black water toward the viewer beneath surface ripples.
ENVIRONMENT: Flooded underpass beneath a highway at night. Water-level perspective, suffocating moody atmosphere.
STYLE: Ghost horror noir art. Heavy jet-black charcoal blocks for concrete pillars, the dark water surface, and rusted rebar. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights disturbed water rings, the buzzing submerged streetlamp, a glinting wristwatch on an outstretched arm, and the oil-slick rainbow. Cinematic underwater-surface lighting." )

# 44
prompts+=( "SUBJECT: A gaunt woman in a tattered Victorian gown with sunken cheekbones and an unhinged, slack jaw, rotting walls, collapsed ceiling beams, empty frames, and a single chandelier crystal spinning overhead.
ACTION: The woman crawls down a grand staircase upside-down with limbs bent at unnatural angles, as dust motes dance in a shaft of light.
ENVIRONMENT: Derelict gallery at midnight. Low angle looking up the grand staircase, oppressive moody atmosphere.
STYLE: Ghost horror noir art. Heavy dark charcoal blocks for rotting walls, beams, and empty frames. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights her cheekbones, the swinging chandelier crystal, cobwebs clinging to her hair, and dust motes in the shaft of dead light. Cinematic single-source overhead lighting." )

# 45
prompts+=( "SUBJECT: A translucent signalman silhouette in a soaked overcoat, a platform canopy, iron columns, a train tunnel mouth, a warning flare on the track, and a lantern burning with cold light.
ACTION: The signalman stands at the platform edge, his body passing through the railing as steam rises from his semi-transparent form.
ENVIRONMENT: Fog-shrouded railway platform at 3 AM. Low angle on the tracks, desolate moody atmosphere.
STYLE: Ghost horror noir art. Heavy jet-black charcoal blocks for the canopy, columns, and tunnel mouth. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the lantern glow, his hollow eye sockets, the warning flare, and the rising steam. Cinematic volumetric fog lighting." )

# 46
prompts+=( "SUBJECT: A woman wearing large-framed aviator sunglasses, and a man approaching from behind holding a crowbar tightly with his arm raised high. A distorted neon sign in the distance reflects 'MOTEL'.
ACTION: The sunglasses lenses capture the chilling reflection of the attacker frozen mid-swing, while a single tear slides down the woman's left cheek.
ENVIRONMENT: Unfathomable dark alleyway at night. Tight close-up frontal perspective, oppressive composition, imminent dread atmosphere.
STYLE: Horror noir graphic novel illustration. Large areas of heavy, rough, jet-black charcoal ink obscure facial details and hair, merging with the background. Heavy ink shadows and high-fidelity sharp, aggressive pencil textures. Selective neon amber pencil highlights sharp refracted glints on the lens surface, the distorted 'MOTEL' neon sign reflection, the cold metallic arc of the crowbar tip, and the glistening tear. Cinematic bottom lighting projected from below." )

# 47
prompts+=( "SUBJECT: A woman wearing aviator sunglasses, and a man holding a crowbar approaching from behind with his arm raised. A distant neon sign is present in the reflection.
ACTION: The reflective lenses display the frozen image of the stalker mid-swing while a single tear falls.
ENVIRONMENT: Dark alley at night. Tight close-up frontal view of her face, imminent dread atmosphere.
STYLE: Graphic novel horror noir, 'evil in the mirror' theme. Heavy jet-black charcoal blocks for her face, hair, and the alley background. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the lens glint, the distorted neon sign reflection, the crowbar's metal arc, and the tear. Cinematic underlighting." )

# 48
prompts+=( "SUBJECT: A smartphone with a black screen, a hand gripping it, a bedroom doorway, a tall silhouette standing in the doorway, and a blinking notification LED.
ACTION: The screen acts as a crude mirror, catching a sliver of ambient light to reveal the tall figure behind the viewer as a doorknob slowly turns.
ENVIRONMENT: Absolute darkness in a bedroom. First-person view of the phone, paranoiac moody atmosphere.
STYLE: Graphic novel horror noir, 'evil in the mirror' theme. Heavy dark charcoal blocks for the bedroom and hand. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the phone's edge glow, the figure's wide white eyes, the blinking notification LED, and the reflected turning doorknob. Cinematic screen-lighting." )

# 49
prompts+=( "SUBJECT: A Victorian vanity mirror with dusty glass, a four-poster bed, heavy curtains, ornate wallpaper, a single dying candle, a straight razor on the vanity, and a grinning face with too many teeth.
ACTION: The mirror's reflection shows an empty room, except for the terrifying grinning face overlaying the viewer's shoulder.
ENVIRONMENT: Dark bedroom at night. Low angle across the vanity glass, gothic moody atmosphere.
STYLE: Graphic novel horror noir, 'evil in the mirror' theme. Heavy jet-black charcoal blocks for the bed, curtains, and wallpaper. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the antique mirror frame, the dying candle, the creature's wet grin, and the glint of the straight razor. Cinematic candlelight." )

# 50
prompts+=( "SUBJECT: A cracked wall mirror, tiled walls, a shower curtain, a sink basin, a dripping faucet, and a shadow figure with elongated, skeletal fingers.
ACTION: The mirror reflection shows the figure standing directly behind the viewer, reaching over their shoulder as steam condenses on the glass.
ENVIRONMENT: Steam-filled bathroom at midnight. First-person perspective facing the mirror, claustrophobic moody atmosphere.
STYLE: Graphic novel horror noir, 'evil in the mirror' theme. Heavy dark charcoal blocks for walls, curtain, and basin. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the jagged crack in the glass, the figure's hollow eyes, the dripping faucet, and the condensing steam. Cinematic single-source lighting." )

# 51
prompts+=( "SUBJECT: An off-centered wide rectangular rearview mirror, a car dashboard, a woman passenger with dilated pupils, a sinister man holding a knife in the backseat, and a rain-streaked windshield.
ACTION: The rearview mirror reflects the woman's wide-open eyes filled with terror on the left, while the man's cold gaze emerges from deep shadows behind her as he grips his weapon. Outside vehicle lights blur into hazy bokeh.
ENVIRONMENT: Cinematic noir car interior at night. First-person perspective from the driver's seat, suffocating moody atmosphere, shallow depth of field.
STYLE: Graphic novel horror noir. Heavy jet-black charcoal blocks swallow the dashboard, headrests, and interior trim. Palette is strictly jet black and neon amber. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the knife blade and distant blurred vehicle lights against the pitch black. Cinematic high-contrast lighting." )

# 52
prompts+=( "SUBJECT: The exterior of a butcher shop with a half-open doorway, a glass window shrouded in thick fog with messy handprints pressed against it from the inside, an amber neon sign reading 'OPEN', a huge hanging metal hook, and rough paving stones.
ACTION: Thick fog filters light through the handprints, and the hanging hook looms in the interior darkness.
ENVIRONMENT: Deserted street at 3 AM. Low-angle perspective looking up from the sidewalk, dark and unsettling graphic novel style, deathly still atmosphere.
STYLE: Film noir illustration. Heavy, deep black charcoal blocks and bold shadows construct the shop interior and street buildings. High-fidelity, rough pencil textures and sharp, aggressive strokes. Selective amber pencil highlights are used with extreme restraint to illuminate the handprints on the fogged glass, the 'OPEN' neon sign, and the sharp curved edge of the hanging metal hook under dim interior lighting." )

# 53
prompts+=( "SUBJECT: An abandoned cathedral nave, vaulted ceiling, pillars, an inverted crucifix, a toppled candelabra with melted wax, and robed figures standing in the aisles.
ACTION: The robed figures stand completely motionless while the inverted crucifix hangs prominently from the ceiling.
ENVIRONMENT: Abandoned cathedral at night. Low angle at the altar looking out at the pews, ritualistic dread atmosphere.
STYLE: Occult horror noir. Heavy jet-black charcoal blocks for the vaulted ceiling, pillars, and figures. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the inverted crucifix, the melted wax, and the hollow eye sockets of the nearest robed figure. Cinematic single-source lighting from below." )

# 54
prompts+=( "SUBJECT: A spiraling concrete stairwell descending into darkness, a failing emergency light, wet handprints on the railing, and a distant crawling entity.
ACTION: The stairwell twists endlessly downward as something crawls upward, reflected faintly in the moisture on the walls.
ENVIRONMENT: Concrete stairwell shaft. Low angle looking down the center void, vertiginous dread atmosphere.
STYLE: Cosmic horror noir. Heavy jet-black charcoal blocks for the endless repeating stairs and walls. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the failing emergency light, the wet handprints, and the distant reflection of the crawling creature. Cinematic volumetric lighting." )

# 55
prompts+=( "SUBJECT: A taxi driver silhouette, an interior rearview mirror reflecting the driver's eyes, a clawed hand gripping a passenger seat headrest, and rain-streaked windows.
ACTION: The clawed hand grips the headrest tightly from behind in the enclosed space of the backseat.
ENVIRONMENT: Interior of a rain-streaked taxi at midnight. Low angle from the backseat floor, claustrophobic moody atmosphere.
STYLE: Psychological horror noir. Heavy dark charcoal blocks for the driver's silhouette and car interior. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the rearview mirror, the reflected eyes, and the single clawed hand under dim dashboard lighting." )

# 56
prompts+=( "SUBJECT: A dead-end alley with a towering brick wall, dumpsters, fire escapes, a flickering bulb, a spreading pool of liquid, and a jagged crack in the masonry.
ACTION: The jagged crack splits open in a shape that disturbingly resembles a human mouth with wet teeth.
ENVIRONMENT: Dead-end urban alley at night. Low angle looking up at the towering brick wall, suffocating atmosphere.
STYLE: Graphic novel horror noir. Heavy jet-black charcoal blocks for dumpsters, fire escapes, and the wall itself. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective neon amber pencil highlights the single flickering bulb, the spreading dark pool, and the wet teeth inside the brick crack. Cinematic underlighting." )

# 57
prompts+=( "SUBJECT: A solitary figure silhouette wearing a coat with an upturned collar, a Gothic bridge with massive cables, a vintage-style streetlamp, and a staggered city skyline.
ACTION: The figure stands on the bridge, gazing down at the deep, dark river below as the lamp's halo pierces the mist.
ENVIRONMENT: Misty river at night. Extremely low, upward-looking perspective, profound melancholy and lonely atmosphere.
STYLE: Graphic novel cover illustration in a film noir aesthetic. Rich in high-fidelity pencil drawing texture with sharp, aggressive, bold strokes and heavy, ink-like shadows. Massive cables and skyline are entirely rendered with thick, pure black charcoal blocks. Selective neon amber pencil highlights illuminate the streetlamp, its long reflection on the dark water, and precisely outline the edge of the coat collar to separate the figure from the shadows." )

# 58
prompts+=( "SUBJECT: A noir detective office, venetian blinds, office furniture, walls, a desk lamp, a cigarette with rising smoke, and a revolver barrel.
ACTION: Venetian blinds cast sharp, striped chiaroscuro shadows horizontally across the room, walls, and furniture.
ENVIRONMENT: Detective office at 3 AM. Low-angle composition, moody and suspenseful atmosphere.
STYLE: Film noir sketch illustration. Heavy dark charcoal blocks for furniture and walls. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Selective vibrant amber pencil highlights the desk lamp glow, the wisps of smoke rising from the cigarette, and the sharp glint of the revolver barrel." )

# 59
prompts+=( "SUBJECT: A lone saxophone player on a dim stage, an underground club architectural background, crowd silhouettes, a brass saxophone, a single spotlight cone, and a whiskey glass on a nearby table.
ACTION: The musician performs under a single spotlight beam while thick smoke drifts through the room.
ENVIRONMENT: Underground jazz club at night. Low angle in the audience, moody smoke atmosphere.
STYLE: Graphic novel noir aesthetic. Heavy jet-black charcoal blocks swallow the room architecture and crowd silhouettes. Sharp aggressive pencil strokes, ink-heavy shadow style, and high-fidelity graphite texture. Selective neon amber pencil highlights the brass saxophone, the spotlight cone trajectory, and the rim of the whiskey glass on the blurred foreground table. Cinematic rim lighting." )

# 60
prompts+=( "SUBJECT: A Caucasian woman with short red hair in silhouette, a gigantic hand with dark red pearl nail polish, a large translucent yellow plastic lightning bolt symbol, and a moody city skyline through a tall window with blinds.
ACTION: The gigantic hand reaches aggressively toward the viewer, fingers thickened by extreme foreshortening, tightly gripping the lightning bolt symbol which emits a dazzling, piercing yellow light from within. Sharp blinds cast dramatic striped shadows across her body as she gazes forward with a blurred profile and slightly parted lips.
ENVIRONMENT: Interior room facing a high window at night. Low, forward-thrusting perspective, compact, tense composition, surreal and urgent atmosphere.
STYLE: Stylized noir graphic novel illustration with a Sin City aesthetic. Minimal color palette of charcoal black, graphite gray, and warm amber/vibrant yellow highlights. High contrast chiaroscuro casting the hand in deep shadow while light penetrates finger details. Aggressive ink shading with almost pure black and white tones, minimal midtones, sharp edges, and a deep dark gray textured backdrop with subtle noise." )

# 61
prompts+=( "SUBJECT: A Caucasian woman with short red hair in silhouette, a gigantic hand with dark red pearl nail polish, a large translucent yellow plastic lightning bolt symbol, and a moody city skyline through a tall window with blinds.
ACTION: The gigantic hand reaches aggressively toward the viewer, fingers thickened by extreme foreshortening, tightly gripping the lightning bolt symbol which emits a dazzling, piercing yellow light from within. Sharp blinds cast dramatic striped shadows across her body as she gazes forward with a blurred profile and slightly parted lips.
ENVIRONMENT: Interior room facing a high window at night. Low, forward-thrusting perspective, compact, tense composition, surreal and urgent atmosphere.
STYLE: Stylized noir graphic novel illustration with a Sin City aesthetic. Minimal color palette of charcoal black, graphite gray, and warm amber/vibrant yellow highlights. High contrast chiaroscuro casting the hand in deep shadow while light penetrates finger details. Aggressive ink shading with almost pure black and white tones, minimal midtones, sharp edges, and a deep dark gray textured backdrop with subtle noise." )

# 62
prompts+=( "SUBJECT: A street food stall with a glowing sign, a small group of people, bowls of ramen, and a narrow alley.
ACTION: The people eat ramen under the sign while steam rises dramatically and rain falls around them.
ENVIRONMENT: Narrow urban alleyway at night. Cinematic framing, hand-drawn comic panel style, cozy yet noir atmosphere.
STYLE: Detailed pencil illustration with a minimal palette of black, gray, and amber glow. Crosshatching and sharp ink linework on a textured paper surface. Strong light contrast between the warm glowing stall and the dark, heavy charcoal surroundings." )

# 63
prompts+=( "SUBJECT: An underground metro station, an arriving train with glowing headlights, commuters standing perfectly still, wet floors, and station signage in Japanese.
ACTION: The train arrives through thick mist, casting reflections on the wet platform floor.
ENVIRONMENT: Underground metro station at night. Symmetrical composition, cinematic perspective, quiet dystopian mood.
STYLE: Graphic novel illustration style. Limited palette of monochrome graphite and warm amber lighting. Highly detailed pencil and ink drawing with crosshatched shadows on a textured sketchbook paper grain." )

# 64
prompts+=( "SUBJECT: A solitary figure sitting on a rooftop edge, a dense futuristic city with endless windows, and distant skyscrapers fading into fog.
ACTION: The figure sits silently overlooking the sprawling cityscape during a light rain.
ENVIRONMENT: Moody rooftop scene at night. Cinematic framing, dramatic depth and scale, melancholic atmosphere.
STYLE: Noir graphic novel aesthetic. Minimal color scheme of black, gray, and warm yellow-orange/amber accents. Ultra-detailed graphite sketch featuring heavy crosshatching and ink wash shading with visible paper texture. Endless windows glow like amber points in the absolute darkness." )

# 65
prompts+=( "SUBJECT: A vintage tram, an empty intersection, a lone pedestrian with an umbrella, glowing streetlights, wet asphalt, and Japanese signage.
ACTION: The tram crosses the intersection while the pedestrian is captured mid-stride through soft fog and rain.
ENVIRONMENT: Rainy night city. Cinematic storyboard panel, balanced composition with strong perspective lines, moody noir atmosphere.
STYLE: Graphic novel style hand-drawn illustration. Minimal color palette of charcoal black, graphite gray, and warm amber highlights. Highly detailed pencil drawing with crosshatching and precise ink outlines on a textured paper grain with subtle film grain. Streetlights reflect warmly on the wet asphalt." )

# 66
prompts+=( "SUBJECT: A cozy coffee shop window, condensation on glass, a silhouette of a person reading by the window, a rainy street, and heavy rain outside.
ACTION: The viewer looks from the cold rainy street into the coffee shop window, capturing the intimate moment.
ENVIRONMENT: Rainy city street corner at night. Close framing on the window glass, intimate urban moment.
STYLE: Charcoal and pastel art style with sketchy lines and detailed shading. Strong contrast between the cold blue/charcoal rainy exterior and the warm amber/golden interior light radiating through the condensation. Rough paper background." )

# 67
prompts+=( "SUBJECT: A busy city intersection, blurred background traffic, a lone taxi cab driving towards the viewer, a warm orange/amber taxi light on top, and heavy rain droplets.
ACTION: The taxi drives forward through a severe downpour toward the foreground.
ENVIRONMENT: Busy urban intersection during a downpour at night. Cinematic framing, gritty urban feel.
STYLE: Textured graphite sketch on a rough paper texture background. High contrast, monochromatic palette with a single warm amber color focus on the taxi light and its immediate wet pavement reflections. Heavy sketchy strokes and dense graphite texture." )

# 68
prompts+=( "SUBJECT: A jazz musician playing a saxophone, a warm golden/amber spotlight, a rainy street corner, and dark towering skyscrapers looming in the background.
ACTION: The musician performs on the corner as rain streaks fall through the spotlight beam.
ENVIRONMENT: Moody city street corner at night. Loose artistic pencil lines, emotional and atmospheric city nightlife scene.
STYLE: Noir style sketch with high contrast. Dominated by heavy charcoal blocks for the skyscrapers and wet asphalt reflections. Accentuated by a single warm golden spotlight and its glint off the brass instrument." )

# 69
prompts+=( "SUBJECT: A small dumpling steamer cart, a weathered counter, a warm orange lantern, thick white steam, dark concrete walls, and puddles on the ground.
ACTION: Thick white steam rises and swirls dramatically from the cart as rain falls in a narrow passageway.
ENVIRONMENT: Narrow urban alleyway at night. Close framing, cozy yet gritty city life vibe.
STYLE: Rough ink and wash style with heavy sketchy strokes. Monochromatic gray and deep charcoal background with vibrant warm amber accents from the cart's lantern illuminating the rain and reflecting in puddles. Rough textured paper." )

# 70
prompts+=( "SUBJECT: A dark subway entrance, a lone figure wearing a bright yellow/amber raincoat, a moody city street, and heavy falling rain.
ACTION: The figure stands still at the entrance while wet pavement reflects the distant subway lights.
ENVIRONMENT: Moody city street at night during a rainstorm. High contrast, cinematic atmosphere of urban solitude.
STYLE: Sketchy charcoal and pencil drawing with detailed texture. Rough hatching lines create heavy dark blocks for the surroundings, generating an extreme contrast against the bright yellow-amber raincoat and its reflections." )

# 71
prompts+=( "SUBJECT: A massive concrete viaduct traversing a dense urban landscape, sleek cars with headlights and taillights, slanting raindrops, towering skyscrapers with intricate pipes and windows, an underground passageway with bridge piers, and tiny figures in long overcoats with umbrellas.
ACTION: The cars drive through the rain across the viaduct, casting long shadows, while the tiny figures hurry through the dark passageway below as a thick fog shrouds the city.
ENVIRONMENT: Dystopian, film-noir-esque cityscape. Square-format, cinematic wide-angle lens showcasing grand spatial depth, lonely atmosphere.
STYLE: Ultra-detailed pencil sketch-style illustration for a graphic novel. Cool, dark tone of graphite gray and black constructed from highly expressive ink outlines and finely detailed cross-hatching. Extremely restrained color palette with warm amber highlights in the car headlights, road reflections, and scattered building windows, creating comic book narrative tension on rough paper texture." )

# 72
prompts+=( "SUBJECT: Massive black skyscrapers with sparse glowing windows, a lone foreground silhouette standing on a rooftop edge, and lightning streaks.
ACTION: Rain falls diagonally across the skyline while lightning briefly outlines the giant structures.
ENVIRONMENT: Stylized dystopian skyline at night. Cinematic wide shot, extreme contrast, Sin City inspired aesthetic.
STYLE: Graphic novel illustration with an almost entirely black composition. Bold graphic shapes and heavy ink shading with minimal detail in the shadows. Selective amber highlights define the sparse glowing windows and minor metallic edges." )

# 73
prompts+=( "SUBJECT: A dark interrogation room, a single overhead lamp, a seated figure, an interrogator standing in shadow, and bare concrete walls.
ACTION: The overhead lamp casts a harsh circular light directly on the seated figure, leaving faces barely visible and background walls swallowed by shadow.
ENVIRONMENT: Enclosed interrogation room. Minimalist composition, oppressive and tense mood.
STYLE: Heavy ink illustration in a graphic novel noir style. Strong chiaroscuro lighting with sharp shadows and high contrast. Minimal palette of deep charcoal blacks and a faint, warm amber light radiating from the vintage lamp bulb." )

# 74
prompts+=( "SUBJECT: Two silhouettes facing off in the rain, frozen raindrops, a bright gun muzzle flash, deep black shadows, and distant windows.
ACTION: One figure fires a gun, creating a bright muzzle flash that illuminates the frozen raindrops mid-air during a dynamic confrontation.
ENVIRONMENT: Rainy urban street at night. Comic panel style, cinematic perspective, dramatic tension.
STYLE: Dynamic noir action scene with extreme contrast and minimal grayscale. Bold inking and gritty hand-drawn texture. Dominated by deep black shadows with selective amber highlights in distant windows and on wet surface reflections caught by the muzzle flash." )

# 75
prompts+=( "SUBJECT: A woman silhouette, a tall window, sharp venetian blinds, a moody city skyline, and distant city lights.
ACTION: The woman stands by the tall window looking out; the blinds cast sharp, striped chiaroscuro shadows across her body while her face remains partially obscured by a strong backlight.
ENVIRONMENT: High-rise interior room at night. Graphic novel composition, moody atmosphere, Sin City aesthetic.
STYLE: Stylized noir scene with extreme contrast. Almost pure black and white with minimal amber city glow filtering through the glass. Aggressive ink shading, dramatic lighting with minimal midtones, sharp edges, and heavy shadows." )

# 76
prompts+=( "SUBJECT: A lone figure in a trench coat, a narrow rain-soaked alley, a cigarette ember, and deep black shadows.
ACTION: The figure stands completely still with their face hidden in shadow, puffing on a cigarette as a rim light catches their outline.
ENVIRONMENT: Narrow rain-soaked alleyway at night. Cinematic framing, gritty texture, hard noir atmosphere.
STYLE: High contrast noir illustration inspired by hard noir comics. Extreme black shadows swallow most details. Bold inked lines and heavy chiaroscuro with rough brush strokes. Minimal palette of pure black, off-white, and sharp amber highlights from the glowing cigarette ember and wet pavement reflections." )

# 77
prompts+=( "SUBJECT: An elevated highway cutting through a dense city, cars leaving long reflections, underpass shadows with pedestrians, and towering buildings with scattered windows.
ACTION: Cars travel along the highway through rain and fog while pedestrians move through the deep shadows below.
ENVIRONMENT: Dense urban grid at night. Cinematic wide shot, graphic novel storyboard composition, dystopian noir mood.
STYLE: Ultra-detailed pencil sketch on rough paper texture. Palette consists of dark graphite tones and heavy charcoal blocks with warm amber highlights in the vehicle lights, wet road reflections, and building windows. Crosshatched shading and crisp ink outlines." )

# 78
prompts+=( "SUBJECT: A cluttered interior of a cybernetic repair shop, a single workbench covered in wires and mechanical parts, and a vintage desk lamp.
ACTION: The lamp illuminates a small workspace while the rest of the room fades into deep obscurity.
ENVIRONMENT: Enclosed cybernetic workshop at night. Tight framing, moody and atmospheric setting.
STYLE: Technical pencil drawing style with precision linework for the tech components. Soft smudging for dark umber and graphite shadows. Features a pool of warm ochre/amber light as the singular color focus against deep charcoal blocks." )

# 79
prompts+=( "SUBJECT: A massive concrete overpass, a small ramen kiosk, a glowing sign, fine smoke, and falling rain.
ACTION: The ramen kiosk glows brightly against the massive structures as fine steam rises into the rain.
ENVIRONMENT: Moody street scene under an overpass at night. Sharp architectural angles, graphic novel aesthetic.
STYLE: Detailed pencil illustration with an 8k resolution pencil grain and gritty texture. Selective color palette features a sharp safety orange/amber pencil light contrasting against the oppressive deep ink-black shadows of the bridge structure, with fine smoke-grey pencil lines representing steam." )

# 80
prompts+=( "SUBJECT: A weary passenger inside a futuristic subway car, a wide window, a blurred city, and a handheld electronic terminal.
ACTION: The passenger sits exhausted while the charcoal-black city streaks past the window in a motion blur.
ENVIRONMENT: Interior of a moving subway car at night. Cinematic framing, heavy vignettes, noir atmosphere.
STYLE: High-contrast pencil drawing featuring meticulous graphite grey cross-hatching. A soft, pale amber glow emanates from the handheld terminal screen, casting localized highlights. Gritty pencil texture on rough paper grain." )

# 81
prompts+=( "SUBJECT: A blurry figure holding a single umbrella, towering skyscrapers, large puddles in the foreground, and dense pouring rain.
ACTION: The figure stands still in the center of the street under a downpour while puddles reflect the ambient glow.
ENVIRONMENT: Rainy city street scene at night. Extremely low-angle shot creating a strong sense of visual oppression, 1:1 square format.
STYLE: Charcoal and pencil hand-drawn illustration in a film noir style. Background skyscrapers are formed by heavy, deep black charcoal blocks completely blending into heavy, inky shadows. Sharp and aggressive brushstrokes with visible paper friction texture. Selective vibrant amber pencil highlights the umbrella and its bright reflection in the foreground puddles." )

# 82
prompts+=( "SUBJECT: A mysterious figure holding an umbrella, silhouettes of towering skyscrapers on either side, a puddle on wet ground, and dense raindrops.
ACTION: The figure stands silhouetted in the center of a gloomy street while diagonal, messy rain sweeps across the entire space.
ENVIRONMENT: Rainy city street scene at night. 1:1 square composition, extremely low-angle perspective creating strong visual oppression, deep and oppressive atmosphere.
STYLE: Cinematic noir hand-drawn illustration. Heavy, deep black and dark gray charcoal blocks define the skyscrapers, outlined with sharp, rough, and aggressive pencil strokes showcasing a high-fidelity rough paper texture. Selective vibrant amber pencil highlights the umbrella and its highly saturated reflection in the puddle, making it the absolute visual focus." )

# 83
prompts+=( "SUBJECT: Silhouettes of skyscrapers, a single umbrella, a wet road, and a puddle reflection.
ACTION: Rain falls over an empty street as a lone figure stands under an umbrella.
ENVIRONMENT: Cinematic noir street scene in the rain at night. Low-angle framing, moody atmosphere.
STYLE: Hand-drawn pencil illustration with heavy, dark charcoal blocks for the buildings. Sharp, aggressive pencil strokes, ink-heavy shadow style, and high-fidelity pencil texture. Cinematic lighting with selective use of a vibrant amber pencil to highlight the single umbrella and its puddle reflection." )

# 84
prompts+=( "SUBJECT: A vintage vinyl record player on a cluttered mahogany desk, glowing vacuum tubes of an old amplifier, a half-empty glass of amber whiskey, and wisps of cigarette smoke.
ACTION: The black vinyl record spins continuously under the glowing needle, catching sharp reflections from the vacuum tubes.
ENVIRONMENT: A smoky, dark private investigator's office at 2 AM. Close-up framing on the turntable.
STYLE: Film noir charcoal illustration. Heavy ink washes create deep shadows across the desk and office background. Sharp pencil lines define the intricate metallic parts of the record player arm. Selective neon amber pencil highlights the intense glow of the vacuum tubes, the liquor in the glass, and the spiraling grooves on the spinning vinyl. Rough paper texture." )

# 85
prompts+=( "SUBJECT: A vintage telephone booth with iron frames and glass panes, a heavy black rotary telephone off the hook, a dangling cord, and thick rolling fog.
ACTION: The telephone receiver dangles limply from its cord, swaying slightly in the night breeze inside an empty plaza.
ENVIRONMENT: A deserted city square engulfed in thick mist at 3 AM. Cinematic wide shot, low-angle perspective.
STYLE: Graphic novel noir panel. Massive dark charcoal blocks outline the cobblestone floor and surrounding architecture, disappearing into an inky black void. Sharp, aggressive pencil hatching depicts the dense fog layers. Striking selective color accent: a single vibrant neon amber light from inside the phone booth illuminates the glass panes, the dangling receiver, and casts a long, glowing halo into the surrounding mist." )

# 86
prompts+=( "SUBJECT: An exhausted boxer leaning back against the frayed ropes of an empty ring, worn leather boxing gloves, and glistening beads of sweat.
ACTION: The boxer rests in complete silence under a single overhead light beam, head lowered in defeat.
ENVIRONMENT: A dark, abandoned boxing gym at midnight. Cinematic mid-shot, low-angle composition creating a heavy, gritty atmosphere.
STYLE: Textured graphite sketch with heavy ink shadows. The background bleeds into deep charcoal black blocks. Bold, raw pencil cross-hatching defines the muscle contours and rope textures. Selective neon amber pencil highlights the single spotlight beam trajectory, the sweat drops reflecting light, and the worn edges of the leather gloves. Papery texture with subtle noise." )

# 87
prompts+=( "SUBJECT: A vintage mechanical typewriter, a sheet of paper with half-written text, a single burning wooden matchstick, and creeping shadows.
ACTION: The matchstick burns down on the edge of the desk, casting a fleeting flare across the metal type keys and the paper sheet.
ENVIRONMENT: A writer's dark study in the dead of night. Macro close-up perspective focusing on the keys and matchstick.
STYLE: Hard noir comic illustration style. Heavy black ink shading swallows the desk corners and background. Aggressive, fine pencil linework maps out the individual alphabet keys and paper grain. Selective vibrant neon amber pencil highlights the dancing flame of the match, the glowing amber ember, and the warm reflection washing over the typewritten letters." )

# 88
prompts+=( "SUBJECT: A towering stone lighthouse on a jagged cliff edge, massive crashing ocean waves, thick coastal fog, and a lone silhouette watching from the balcony.
ACTION: The lighthouse lamp casts a monumental sweeping beam through the driving sea spray and dense night fog.
ENVIRONMENT: A desolate coastal cliffside during a midnight storm. Cinematic low-angle wide shot, grand spatial depth.
STYLE: Heavy charcoal and pencil illustration. Intense jet-black charcoal blocks render the rugged cliffs and chaotic ocean waves. Sharp, aggressive diagonal pencil lines depict the heavy rain and sea spray. Selective neon amber pencil highlights the concentrated cone of the lighthouse beam piercing the fog, the foam lines of the waves, and the railing of the tower. Rough paper grain with high visual tension." )

# 89
prompts+=( "SUBJECT: A retro-futuristic arcade cabinet with a dead black screen, a joystick, a glowing coin slot, and a lone teenager silhouette with a hood.
ACTION: The teenager stands motionless in front of the unlit screen, hand resting on the control panel in a dark corridor.
ENVIRONMENT: A narrow, abandoned arcade alleyway at night. Symmetrical composition, moody dystopian atmosphere.
STYLE: Graphic novel noir aesthetic. Dominated by deep monochrome blacks and graphite gray washes that completely obscure the surrounding machines. Sharp pencil sketch lines map out the industrial wires and geometric edges. Selective neon amber pencil highlights the coin slot glow, the edges of the joystick, and the faint rim light on the teenager's hood. Textured paper grain." )

# 90
prompts+=( "SUBJECT: A massive circular vintage bank vault door, intricate interlocking iron gears, heavy locking bolts, and a thick security laser beam cutting through airborne dust motes.
ACTION: The vault door sits cracked open just a few inches, revealing a dark interior as a single light beam cuts across the heavy mechanism.
ENVIRONMENT: A subterranean bank vault corridor at midnight. Extreme low-angle framing, claustrophobic and suspenseful mood.
STYLE: Detailed technical pencil drawing mixed with film noir ink shading. Heavy charcoal blocks shape the solid steel walls. Meticulous graphite cross-hatching defines the complex gear teeth. Selective vibrant neon amber pencil highlights the security beam, the glinting edges of the heavy bolts, and the illuminated dust motes swirling in the air. Rough paper texture." )

# 91
prompts+=( "SUBJECT: An empty theater stage, heavy velvet curtains in deep shadow, a vintage microphone stand, a single overhead spotlight, and floating dust motes.
ACTION: The microphone stands completely solitary under a sharp cone of light, capturing an absolute sense of desolation after the performance.
ENVIRONMENT: A grand abandoned theater auditorium at midnight. Center axial composition, wide cinematic perspective.
STYLE: Noir style sketch illustration. Massive jet-black charcoal blocks swallow the stage floor and the sweeping curtains. Expressive, sharp pencil linework structures the microphone stand and mechanical joints. Selective neon amber pencil highlights the spotlight cone trajectory, the metallic mesh of the microphone head, and the shimmering dust motes suspended in the light beam. Rich paper grain." )

# 92
prompts+=( "SUBJECT: A Victorian botanical greenhouse, shattered glass panels, overgrown dark tropical ferns, twisted vines, and a single glowing firefly.
ACTION: The lone firefly pulses with light in the center of the frame, illuminating the sharp edges of the broken glass and nearby leaves.
ENVIRONMENT: An abandoned greenhouse at night under a pitch-black sky. Low-angle close-up framing, surreal and uncanny atmosphere.
STYLE: Charcoal and pencil horror noir illustration. Heavy ink washes and deep gray charcoal strokes create dense, tangled shadows among the plants. Sharp pencil hatching defines the cracks in the glass panels. Selective neon amber pencil highlights the firefly's vibrant pulse, its immediate halo on the ferns, and the glinting edges of the shattered glass. Rough papery texture." )

# 93
prompts+=( "SUBJECT: A lonely figure silhouette sitting on a weathered wooden piling, a massive cargo ship silhouette looming in the background, a single warning beacon, and rippling water.
ACTION: The figure sits perfectly still gazing out into the black harbor as the ship's warning light blinks.
ENVIRONMENT: A quiet harbor dock at 4 AM. Cinematic wide shot, strong horizontal lines, melancholic noir atmosphere.
STYLE: Hard noir graphic novel panel. Heavy dark charcoal blocks construct the dock platform and the imposing ship hull. Fine graphite shading maps out the calm water surface. Selective neon amber pencil highlights the ship's single warning beacon and its long, fractured, rippling reflection stretching across the black water to the foreground. Textured paper grain." )

# 94
prompts+=( "SUBJECT: A classic tailor's workshop, a fabric mannequin draped in a sharp trench coat, heavy iron tailor's scissors, spools of thread, and a tall window.
ACTION: The scissors sit flat on a wooden work table, catching a sharp ray of light filtering through the window from a distant streetlamp.
ENVIRONMENT: A silent tailor's shop at 2 AM. Close-up, low-angle composition, mysterious and quiet narrative atmosphere.
STYLE: Highly detailed pencil sketch with film noir shading. Deep charcoal blocks wrap the workshop corners and the mannequin's background silhouette. Intricate cross-hatching defines the texture of the trench coat fabric. Selective vibrant neon amber pencil highlights the sharp metallic edges of the scissors, a single spool of amber thread, and the faint rim light outlining the coat. Rough sketch paper background." )

# 95
prompts+=( "SUBJECT: The interior of a medieval clock tower, massive interlocking gear wheels, a heavy pendulum, and Roman numerals on a translucent clock face.
ACTION: The giant gear wheels stand frozen in the dark, backlit by an external urban glow through the clock face at midnight.
ENVIRONMENT: Inside a clock tower chamber. Vertiginous low-angle perspective looking up into the mechanism, tense and oppressive mood.
STYLE: Technical noir illustration. Pure black charcoal blocks form the heavy iron frames and deep shadows of the tower interior. Sharp, aggressive pencil linework details the individual gear teeth and rivets. Selective neon amber pencil highlights the backlit Roman numerals, the glowing edges of the giant hands, and the light bleeding around the pendulum rod. Granular charcoal paper texture." )

# 96
prompts+=( "SUBJECT: A desolate gas station on an empty highway, a vintage fuel pump with a cracked analog display, a hanging rubber hose, and a flickering neon sign reading 'GAS'.
ACTION: The neon sign flickers erratically, casting intermittent illumination over the rusted pump and the wet asphalt.
ENVIRONMENT: A lonely highway gas station during a midnight downpour. Cinematic wide shot, low-angle framing, desolate noir atmosphere.
STYLE: Hand-drawn pencil and charcoal storyboard panel. Deep ink-heavy shadows swallow the highway horizon and the station canopy. Diagonal, sharp pencil strokes depict the heavy slanting rain. Selective neon amber pencil highlights the 'GAS' text on the flickering sign, its bright reflection pooling in the wet pavement puddles, and the cracked numbers on the pump display. Subtle film grain with rough paper grain." )

# 97
prompts+=( "SUBJECT: An ancient library or apothecary, towering wooden bookshelves stretching into shadow, an old scholar silhouette, an open ancient grimoire, and glowing text runes.
ACTION: The scholar turns a page as the handwritten script on the ancient parchment glows with a mystical, selective incantation.
ENVIRONMENT: A dark library alcove at night. Close-up framing focused on the open book and the scholar's hands.
STYLE: Gothic horror noir sketch. Heavy charcoal blocks obscure the surrounding bookshelves, creating a claustrophobic, ink-heavy shadow style. Fine, intricate pencil lines trace the texture of the old paper and the scholar's fingers. Selective neon amber pencil highlights the glowing text characters, the edges of the turning page, and the rim of the scholar's wire-rimmed spectacles. Textured paper grain." )

# 98
prompts+=( "SUBJECT: A narrow Venetian canal, a lone gondola boat with an ornate metal bow, a stone arch bridge, a lone passenger silhouette, and a vintage wall lantern.
ACTION: The gondola drifts silently beneath the stone bridge, casting ripples across the dark water surface.
ENVIRONMENT: A mirrored canal path in Venice at night. Cinematic low-angle perspective from water level, romantic-noir atmosphere.
STYLE: Rough ink and wash style combined with charcoal sketch textures. Heavy black blocks define the ancient stone walls and the underside of the bridge. Sharp pencil hatching outlines the architectural bricks. Selective neon amber pencil highlights the flame inside the wall lantern, its long shimmering reflection breaking across the water ripples, and the polished metallic tip of the gondola bow." )

# 99
prompts+=( "SUBJECT: A high-tech surveillance control room, banks of stacked electronic monitors casting pitch-black shadows, a lone security guard silhouette, and a single glitching screen.
ACTION: The guard stands motionless before the monitors while one specific screen displays a giant glitching graphic of an eye tracking the room.
ENVIRONMENT: A corporate security facility at 3 AM. Compact, tense composition, paranoid dystopian noir mood.
STYLE: Stylized graphic novel illustration with high-contrast chiaroscuro. Massive dark charcoal blocks eliminate midtones, swallowing the guard's body and the room infrastructure. Sharp, precise pencil sketch lines structure the screen frames and wires. Selective vibrant neon amber pencil highlights the glowing eye on the glitching monitor, the control panel LEDs, and the amber light reflecting off the guard's face. Textured paper backdrop with subtle noise." )

# 100
prompts+=( "SUBJECT: An industrial train graveyard, rusted obsolete locomotives covered in gritty graffiti, shattered train windows, and a single signal light hanging from a bent metal pole.
ACTION: The solitary signal light glows steadily against the desolate landscape, remaining a defiant beacon amidst the decay.
ENVIRONMENT: A forgotten railway yard at midnight. Cinematic wide low-angle shot, monumental composition, elegiac industrial noir atmosphere.
STYLE: Highly detailed pencil and charcoal drawing. Thick, jet-black charcoal blocks and heavy ink washes construct the massive iron hulls of the abandoned trains. Sharp, aggressive cross-hatching captures the texture of rust and broken glass on rough paper grain with subtle film grain. Selective neon amber pencil highlights the solid glowing signal light bulb, its stark reflection on the wet iron tracks, and the edges of the nearest graffiti tags." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
