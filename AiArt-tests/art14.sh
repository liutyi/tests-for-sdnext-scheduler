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
# Theme: Female portraits — elegant, action, cinematic, grounded in contemporary world
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+14+-+female+portraits
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — The Rain Doesn't Touch Her — Fashion × Cinematic Portrait
prompts+=( "A woman in her late 20s with sharp bone structure, wearing a tailored black wool coat with a high collar, standing alone on a rain-slicked city street at night, looking directly into the camera with absolute calm, heavy rain falling around her but she is still and unhurried, fashion editorial meets cinematic street photography style, cold blue-white streetlight overhead creating hard top lighting with rain catching the light into silver streaks, warm amber window glow from a bar behind her reflecting in the wet pavement, rim lighting separating her coat from the dark background, shot on 85mm lens at f/1.4, subject centered with slight low angle, rain streaks in sharp foreground, blurred city lights in deep background bokeh, rule of thirds vertical with her eyes on the upper third line, danger and charisma, cinematic portrait quality" )

# 02 — Controlled Chaos — Editorial Action Portrait
prompts+=( "A woman in her early 30s mid-motion, turning sharply with long dark hair exploding outward in a dramatic arc around her, wearing a structured ivory silk blouse partially open, one hand raised to her collarbone, expression fierce and composed simultaneously, clean white cyclorama studio background, high-end fashion editorial action portrait style, single hard key light from the upper right creating strong facial shadow and catching every strand of hair in sharp detail, subtle fill light from below reducing shadow to a mid-tone, no color temperature conflict, pure contrast play, shot on 85mm lens, subject in center frame, hair arc filling the upper left and right thirds creating natural framing, low angle slightly looking up, frozen motion at peak movement, strong atmosphere and interesting pose, commercial editorial quality" )

# 03 — The Last Cigarette Before the Call — Noir × Urban Charisma
prompts+=( "A woman in her mid-30s sitting sideways on a windowsill of a high-floor apartment, one leg inside one leg dangling out, wearing a fitted dark turtleneck and wide-leg trousers, holding a cigarette loosely between two fingers, gaze cast downward at the city below with a half-smile, nighttime cityscape blurred behind her, contemporary cinematic noir portrait style, single shaft of warm interior lamp light catching her face from the left, cool city ambient light from the window on the right side of her face creating a split-tone effect, subtle cigarette smoke catching the interior light, shot on 50mm lens, subject in right third with open city negative space to the left, medium close crop from mid-thigh up, depth of field keeping face sharp and city completely dissolved into bokeh, danger and charisma, strong atmosphere, cinematic quality" )

# 04 — Weight of Quiet — Painterly Emotional Portrait
prompts+=( "A woman in her 40s with natural grey streaks in dark hair, sitting on the floor of a sunlit room with bare wooden boards, back against a white wall, knees drawn up, eyes closed and head tilted slightly back as if listening to something, wearing a loose linen shirt, morning light, intimate painterly portrait style with soft impressionistic rendering and visible texture in the light areas, overcast diffused window light from the left wrapping the scene in even warm-white tones with no hard shadows, subtle warm glow from below as light bounces off the wooden floor, Rembrandt lighting quality on the face despite the overall softness, shot on 85mm lens, close medium crop from hips up, subject centered with empty wall space above her as negative space, shallow depth of field with floor boards receding softly, painterly emotion and quiet presence, portrait quality" )

# 05 — Three Seconds Before Impact — Dance × Action Portrait
prompts+=( "A woman contemporary dancer in her late 20s captured mid-leap, body fully extended in a suspended diagonal line from pointed toe to outstretched fingertip, wearing a deep burgundy draped jersey dress that follows the motion like a second body, expression intense and inward, shot in a raw industrial rehearsal space with concrete floors and high windows, cinematic action portrait style, dramatic hard side lighting from a single large window at the left casting the extended limbs in sharp light and the underside of the body into deep shadow, golden hour sunlight quality through industrial glass, warm on skin cold on concrete floor, motion blur at the dress hem suggesting speed while the face and core remain pin sharp, shot on 35mm lens from a slightly low angle, full body in frame with negative space above the leap, strong atmosphere and interesting pose, cinematic editorial quality" )

# --- Gemini 3.1 Pro ---

# 06 — Neon Rain Alleyway — Cinematic Noir
prompts+=( "A 28-year-old woman with a sharp, alert expression and dark wet hair clinging to her face, wearing a black leather jacket over a simple gray t-shirt, her body angled defensively as if looking over her shoulder. She stands in a narrow alleyway in a modern metropolis at night with wet asphalt reflecting vibrant street signs. Cinematic editorial portrait photography style. Split-tone lighting with electric blue and hot magenta neon hues casting high-contrast, dramatic shadows across her face. Captured on a 50mm lens for a raw street documentary feel, rule of thirds composition with the subject positioned in the right third and negative space opposite, featuring a shallow depth of field with intense background bokeh." )

# 07 — Morning Loft — Painterly Impressionist
prompts+=( "A 34-year-old woman with a serene but deeply melancholic expression, her loose blonde hair tied back carelessly with a few strands framing her face, wearing an oversized beige knit sweater, sitting cross-legged on a rustic wooden floor bench. She is positioned inside a minimalist apartment loft with large industrial glass windows during a foggy morning. Painterly impressionist photography style emphasizing texture and soft emotion. Natural overcast diffused light streams through the glass panes, creating a flat, even, and deeply atmospheric environment. Shot on 35mm film for an analog feel with visible grain and muted color saturation, utilizing distinct foreground, mid-ground, and background layering with a soft linen curtain subtly blurring the extreme edge of the frame." )

# 08 — Brutalist Courtyard — High Fashion Geometry
prompts+=( "A 24-year-old woman with a confident, charismatic stare and a sharp geometric bob haircut, wearing an architectural asymmetric red blazer over tailored black trousers, standing tall with her hands in her pockets. She is located in the open concrete courtyard of a modern brutalist museum building defined by clean structural lines. High-end fashion photography style. Sharp, dramatic rim lighting from a harsh afternoon sun creates a brilliant outline that separates her silhouette cleanly from the deep architectural shadows behind her. Captured with a 35mm lens for a wide environmental context, utilizing a low angle looking up to emphasize her commanding presence, centered with symmetrical framing." )

# 09 — Theater Backstage — Chiaroscuro Portrait
prompts+=( "A 40-year-old theater actress with a deeply expressive, intense gaze and elegant laugh lines around her eyes, her hair styled in a classic elegant updo, wearing a simple textured silk slip dress. She sits in a dimly lit contemporary backstage dressing room with hints of a vanity mirror blurred in the background. Documentary portrait style. Classic Rembrandt lighting from a 45-degree key light leaves a distinct, dramatic portrait triangle shadow on her cheek, creating a high-contrast chiaroscuro mood with deep shadows. Shot on an 85mm lens ensuring natural facial proportions and a highly compressed background, utilizing a tight composition focused on the rich textures of her skin and clothing." )

# 10 — Subway Terminal — Atmospheric Transit
prompts+=( "A 30-year-old woman with an intense, scanning gaze and short cropped pixie hair, wearing a sleek waterproof trench coat with the collar turned up, leaning subtly against a tiled industrial pillar. She is standing on a subterranean concrete subway platform with a modern transit train's headlights approaching out of focus in the distance. Cinematic noir photography style loaded with tension. Dramatic volumetric light shafts slice through the humid underground air from overhead steel grates, cutting visible beams through the atmosphere. Captured on a 50mm lens for a neutral, candid perspective, with the subject in the left third and negative space opposite framing the empty, receding platform lines." )

# --- ChatGPT ---

# 11 — Rain Taxi Encounter — Cinematic Documentary
prompts+=( "A 28-year-old woman with wet dark hair clinging to her face, leaning into the open window of a taxi on a rainy city street at night, intense eye contact with someone inside, wearing a soaked black leather jacket and minimal makeup, urban realism documentary portrait style, shot on 50mm lens, rain droplets frozen mid-air, neon reflections on glass, chiaroscuro lighting with strong contrast between streetlights and shadows, subject positioned in right third with blurred city lights forming background bokeh, shallow depth of field, cinematic grain, high dynamic range, natural skin texture" )

# 12 — Morning Balcony Stillness — Painterly Impressionism
prompts+=( "A 32-year-old woman with short auburn hair and soft freckles, standing barefoot on a small apartment balcony holding a coffee mug, gazing into the distance with a contemplative expression, wearing an oversized linen shirt, painterly impressionist portrait style with subtle brushstroke texture, shot on 85mm lens, golden hour lighting casting warm directional light across her face, soft shadows and glowing highlights, subject centered with symmetrical framing, layered composition with railing foreground and city skyline in background, shallow depth of field, soft atmospheric haze" )

# 13 — Boxing Gym Break — Gritty Editorial
prompts+=( "A 25-year-old athletic woman sitting on the floor of a boxing gym, wrapping her hands, sweat on her skin, focused and slightly exhausted expression, messy tied-back hair, wearing sports bra and worn training pants, gritty fashion editorial photography style, shot on 35mm lens, overhead industrial lighting mixed with rim lighting outlining her shoulders, high contrast shadows, subject placed in left third with negative space showing punching bags behind, foreground ropes slightly out of focus, deep texture detail, cinematic realism, subtle film grain" )

# 14 — Subway Glance — Street Photography Realism
prompts+=( "A 22-year-old woman sitting inside a subway car, briefly looking up from her phone with a guarded expression, straight black hair tucked behind ears, wearing a dark hoodie and headphones, contemporary street photography portrait, shot on 50mm lens, overcast diffused light from subway windows creating soft even tones, muted color palette, subject positioned in left third with passengers blurred in background, shallow depth of field with natural motion blur, candid composition, realistic noise and grain" )

# 15 — Close-Up Tension — Macro Emotional Portrait
prompts+=( "Extreme close-up of a 30-year-old woman's face, slightly parted lips and tense jaw, a single tear forming in the corner of her eye, fine skin texture visible, strands of hair crossing her face, no visible background context, macro portrait photography style, macro lens, dramatic split-tone lighting with warm light on one side and cool blue light on the other, centered symmetrical framing, ultra shallow depth of field focusing on eye and tear, hyper-detailed skin texture, cinematic intensity" )

# --- Grok ---

# 16 — Golden Hour Executive — Confident Power Portrait
prompts+=( "A poised 28-year-old East Asian woman with sharp cheekbones and shoulder-length straight black hair, wearing a tailored black blazer over a silk camisole, standing on a modern city rooftop terrace at dusk, looking directly at camera with calm authority and subtle smile, 85mm lens, cinematic editorial fashion photography, golden hour warm directional light creating long elegant shadows across her face and hair, rim lighting separating her from the blurred city skyline, rule of thirds composition with negative space on the right, shallow depth of field with creamy bokeh. Photorealistic, highly detailed skin texture and fabric." )

# 17 — Rainy Street Reflection — Introspective Urban Mood
prompts+=( "A 32-year-old Caucasian woman with wet wavy auburn hair clinging to her face, wearing a soaked beige trench coat, standing under a streetlight on a rainy night city sidewalk, head slightly tilted with contemplative expression and direct gaze, 50mm lens, documentary-style portrait photography, overcast diffused light mixed with cool blue streetlamp illumination creating gentle split-tone lighting, water droplets visible on skin and coat, subject in left third with reflective puddles in foreground, shallow depth of field. Moody cinematic realism with natural grain." )

# 18 — Studio Chiaroscuro — Dramatic Close-Up Intensity
prompts+=( "A 25-year-old Black woman with short natural afro hair and striking bone structure, wearing a simple black turtleneck, extreme close-up portrait in a minimalist studio, intense eye contact with slightly parted lips conveying quiet strength, macro lens, painterly impressionist portrait style, strong chiaroscuro lighting with deep dramatic shadows and bright key light creating a classic Rembrandt triangle on her cheek, centered symmetrical framing, extreme texture detail on skin and hair. Hyper-detailed photorealism with rich tonal range." )

# 19 — Windy Coastal Edge — Dynamic Presence
prompts+=( "A 30-year-old Latina woman with long dark wavy hair dramatically blowing in the wind, wearing a white linen button-up shirt with sleeves rolled up, standing on a contemporary seaside boardwalk at late afternoon, body turned slightly away while looking back over shoulder with confident expression, 35mm lens, editorial action portrait photography, golden hour side lighting with volumetric light shafts through sea mist, low angle looking up to emphasize presence, foreground railing with layered ocean background, dynamic composition. Cinematic realism with natural movement." )

# 20 — Morning Window Light — Soft Emotional Connection
prompts+=( "A 27-year-old South Asian woman with long straight dark hair partially covering one eye, wearing an oversized soft gray sweater, sitting by a large apartment window in soft morning light, gentle melancholic expression with eyes looking slightly off-camera, 85mm lens, intimate documentary portrait style, overcast diffused natural window light creating delicate rim lighting and soft shadows, subject positioned in left third with negative space showing blurred city view, shallow depth of field with creamy bokeh. Warm, painterly photorealism focused on subtle emotion and skin tones." )

# --- Qwen 3.6 Plus ---

# 21 — Golden Hour Elegance — Editorial Portrait
prompts+=( "A late 20s woman with a confident, relaxed smile and loosely pinned chestnut hair, wearing a flowing emerald silk wrap dress, standing on a sun-drenched modern balcony overlooking a contemporary city skyline. Cinematic editorial fashion photography style. Golden hour warm directional light casts long, soft shadows across her features while highlighting the fabric's sheen. Captured on an 85mm lens with shallow depth of field creating creamy background bokeh, sharp focus on the eyes, and highly resolved facial details." )

# 22 — Urban Tension — Street Presence
prompts+=( "An early 30s woman with an intense, piercing gaze and a messy dark bun, wearing a fitted black leather jacket over a white tee, leaning back with weight shifted to one hip in a narrow contemporary brick alleyway flanked by modern glass storefronts. Gritty contemporary documentary portrait style. Rim lighting creates a bright, dramatic subject outline separating her sharply from the dim, moody background. Shot on a 35mm lens, utilizing subject placement in the right third with expansive negative space to the left, natural film grain texture, and high-contrast realistic skin pores." )

# 23 — Quiet Introspection — Soft Close-Up
prompts+=( "A mid-40s woman with a thoughtful, downward-cast expression and wavy auburn hair framing her face, dressed in a chunky cream cable-knit sweater, seated near a blurred indoor houseplant arrangement and large window. Contemporary painterly portrait photography style. Overcast diffused light provides even, flat illumination that minimizes harsh shadows and emphasizes subtle emotional depth. Macro lens capturing extreme close-up of facial micro-expressions and knit fabric texture, applying the rule of thirds to eye placement with muted natural saturation and ultra-detailed rendering." )

# 24 — Midnight Neon — Dynamic Action Shot
prompts+=( "A late 20s woman caught in a dynamic forward stride, wearing a tailored navy trench coat and dark jeans, hair whipping in the wind with a determined, focused expression, walking along a rain-slicked contemporary metropolitan street at night. Neo-noir cinematic street portrait style. Split-tone lighting featuring cool blue ambient overhead streetlights contrasting with warm neon red bounce light illuminating her face from a nearby shop sign. Shot on a 50mm lens from a low angle looking up to emphasize strong presence, with foreground puddle reflections adding environmental layering and crisp motion-freeze resolution." )

# 25 — Architectural Symmetry — High Fashion Pose
prompts+=( "A mid-30s woman with striking angular features, bold matte red lipstick, and sleek straight dark hair, wearing a minimalist structured white jumpsuit, standing with arms crossed and shoulders squared in a vast sunlit contemporary concrete gallery space. High-end contemporary architectural fashion photography style. Chiaroscuro lighting creates high contrast with deep, dramatic shadows sculpting one side of her face against the brightly lit geometric environment. Centered with symmetrical framing intersected by volumetric light shafts cutting through faint atmospheric dust, captured on an 85mm lens for compressed perspective, edge-to-edge sharpness, and professional color grading." )

# --- GLM 5.1 ---

# 26 — Urban Rain — Cinematic Noir
prompts+=( "28-year-old woman, sharp jawline, wet hair slicked back, intense determined expression, wearing a tailored black trench coat, gripping the collar tightly, standing on a contemporary city street at night, rain pouring down, blurred neon reflections on wet asphalt, cinematic editorial fashion photography, split-tone lighting with cool blue ambient streetlights vs warm orange neon, rim lighting on her hair and shoulders to separate from the dark background, 50mm lens, subject in right third with negative space opposite, shallow depth of field with background bokeh, hyper-detailed fabric texture" )

# 27 — Melancholy Transit — Painterly Documentary
prompts+=( "35-year-old woman, freckled skin, soft melancholic expression, loose auburn linen blouse, wind blowing her wavy hair across her face, leaning against a modern glass bus stop on a rural highway, overgrown grass around the edges, painterly impressionist documentary portrait, overcast diffused light creating a flat, even, and quiet mood, shot on 35mm film, rule of thirds, foreground/mid-ground/background layering, muted saturation and fine analog grain structure" )

# 28 — Concrete Atrium — Stark Fashion
prompts+=( "22-year-old woman, regal posture, bold red lips, sleek platinum blonde hair in a tight bun, wearing a minimalist white silk slip dress, chin tilted up defiantly, inside a modern concrete architecture atrium, geometric shadows falling across the walls, high fashion photography stark and elegant, Rembrandt lighting creating the classic triangle shadow under her eye, chiaroscuro with deep dramatic shadows, 85mm lens, centered with symmetrical framing, low angle looking up to emphasize presence, sharp focus on facial geometry and fabric sheen" )

# 29 — Gym Dust — Visceral Action Portrait
prompts+=( "40-year-old woman, intense green eyes, a single drop of sweat on her temple, clenched jaw, wearing a rough grey cotton tank top, tendons visible on her neck, inside a dimly lit contemporary boxing gym, out of focus heavy bag in the background, raw and visceral sports documentary portrait, volumetric light shafts cutting through the dusty gym air from a high window, creating a sense of danger and physical tension, macro lens, extreme close-up on her face and neck, rule of thirds, shallow depth of field with background bokeh, hyper-detailed skin texture" )

# 30 — Diner Dusk — Nostalgic Road Movie
prompts+=( "30-year-old woman, confident charismatic smirk, messy brunette bob, wearing an oversized vintage leather bomber jacket and ripped jeans, leaning casually on a parked sedan, deserted roadside diner parking lot at dusk, cinematic road movie still, golden hour warm directional light casting long shadows, rim lighting outlining her jacket against the darkening sky, epic lighting, 35mm lens capturing environmental context, subject in left third with negative space opposite, foreground/mid-ground/background layering, rich color grading" )

# --- Kimi K2.6 Thinking ---

# 31 — Rooftop Solitude — Cinematic Editorial
prompts+=( "East Asian woman, late 20s, sharp cheekbones, hair in loose waves, wearing a structured charcoal blazer over a silk camisole, standing on a modern glass rooftop terrace at twilight with a blurred city skyline behind her, cinematic editorial fashion photography, split-tone lighting with cool blue ambient from city lights mixed with warm tungsten key light on her face, 85mm lens, shallow depth of field with background bokeh, subject in left third with negative space opposite." )

# 32 — Subway Motion — Documentary Street
prompts+=( "Black woman, early 30s, natural afro hair, wearing a vintage leather jacket and white tee, intense forward gaze and purposeful stride, walking through a crowded contemporary subway platform as a train arrives with motion blur in the background, documentary portrait street photography, split-tone lighting with cool fluorescent platform lights mixed with warm incandescent train interior glow, 35mm lens, low angle looking up, foreground mid-ground background layering." )

# 33 — Studio Contemplation — Painterly Chiaroscuro
prompts+=( "Caucasian woman, mid-40s, silver-streaked auburn hair pulled back, wearing a simple black turtleneck, serene expression with slight melancholy, seated in a minimalist white-walled artist studio with a single canvas visible, painterly impressionist portrait, chiaroscuro with a single harsh key light from the side creating deep shadows across half her face, macro lens extreme close-up capturing skin texture and fabric weave, centered with symmetrical framing." )

# 34 — Rainy Avenue — Noir Atmosphere
prompts+=( "South Asian woman, early 20s, wet hair slicked back, wearing a tailored trench coat, hands clasped in pockets, defiant expression, standing on a wet downtown avenue at night with neon signs reflected in puddles, cinematic noir portrait, rim lighting from streetlamps creating a bright subject outline with dramatic separation from the dark background and volumetric light shafts from car headlights in the mist, 50mm lens, neutral perspective, rule of thirds, shot on 35mm film for grain and muted saturation." )

# 35 — Riverside Confidence — Natural Elegance
prompts+=( "Latina woman, mid-30s, long dark hair flowing in the breeze, wearing a tailored ivory pantsuit, standing confidently on a modern steel-cable pedestrian bridge over an urban river with morning mist over the water and glass towers in the background, cinematic editorial portrait, golden hour warm directional light with long shadows across the bridge deck, 85mm lens, natural facial proportions, subject in right third with negative space opposite, shallow depth of field with background bokeh." )

# --- Deepseek ---

# 36 — Rain-Soaked Tension — Cinematic Street Portrait
prompts+=( "A woman in her early 30s, wet dark hair clinging to her face, wearing a charcoal trench coat over a black turtleneck, standing on a rain-slicked city sidewalk at night, looking over her shoulder with a guarded, alert expression. Background: blurred neon signs and passing taxi taillights. Style: cinematic editorial, shot on 35mm film with visible grain. Lighting: rim lighting from a streetlamp behind her plus split-tone lighting (cool blue ambient, warm orange edge). Composition: subject in right third, negative space left, shallow depth of field with bokeh from rain droplets. 85mm lens, natural facial proportions." )

# 37 — Painterly Solitude — Soft Window Light Portrait
prompts+=( "A woman in her late 20s with loose auburn waves, wearing an oversized cream cable-knit sweater, seated on a wooden floor beside a large rain-streaked window in a quiet apartment. Expression: introspective, lips slightly parted, hands resting loosely in her lap. Style: painterly impressionist with visible brush-like softness, reminiscent of a contemporary figurative painting. Lighting: overcast diffused light through the window, creating even, gentle illumination with no harsh shadows. Composition: centered with symmetrical framing, subject in mid-ground, muted gray-blue walls behind her. 50mm lens, neutral documentary feel." )

# 38 — Danger at Dusk — Parking Garage Rim Light
prompts+=( "A fit woman around 35 years old with a sharp bob haircut, wearing a fitted black leather jacket and dark jeans, walking alone in an empty multi-story parking garage at twilight. Pose: caught mid-stride, one hand in jacket pocket, head turned slightly toward a sound off-camera, expression wary and ready. Style: fashion noir photography with high contrast. Lighting: dramatic chiaroscuro with strong rim lighting from a single overhead fluorescent tube, deep shadow on her front. Composition: low angle looking up, subject in left third, long diagonal concrete pillar in background for layering. 35mm lens, environmental context." )

# 39 — Golden Hour Power — Rooftop Editorial
prompts+=( "A woman in her early 40s with silver-streaked hair pulled into a low ponytail, wearing a tailored beige power suit and pointed heels, standing on a minimalist rooftop overlooking a city skyline. Pose: one hand on her hip, chin slightly raised, expression confident and unbothered. Style: high-fashion editorial photography. Lighting: golden hour with warm directional light from the setting sun, long shadows stretching behind her, plus soft fill from reflected sky. Composition: rule of thirds, subject centered in the lower two-thirds, epic volumetric light shafts breaking through distant clouds. 85mm lens, compressed background with blurred cityscape." )

# 40 — Charisma in Motion — Crosswalk Candid
prompts+=( "A woman in her mid-20s with a short curly afro, wearing a bright yellow midi dress and white sneakers, crossing a wide urban crosswalk during blue hour. Pose: mid-step, dress flaring slightly, looking over her shoulder with a spontaneous, joyful laugh. Style: documentary street portrait. Lighting: soft ambient city light mixed with cool twilight from above and warm storefront glow hitting her side. Composition: foreground pedestrian blurred, subject in sharp focus in mid-ground, background traffic lights and bodega signs — layered depth. 35mm lens with shallow depth of field, slight motion blur in legs." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
