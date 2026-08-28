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
# Theme: Mixed Media — people and streets, black/gold/grey palette
# Source: https://wiki.liutyi.info/display/AI/Ai+Art+11+-+Mixed+Media+people+and+streets
# Structure: 8 models × 5 prompts = 40 tasks total
# ---------------------------------------------------------------------------
prompts=()

# --- Claude Sonnet 4.6 ---

# 01 — Urban Nocturne — layered collage, street poetry
prompts+=( "Mixed media abstract collage artwork, museum-quality. Torn and layered fragments of burlap, linen, and aged paper form a textured ground. Ghostly silhouettes of pedestrians mid-stride, rendered as cut paper shadows, drift across receding vanishing-point roads. Perspective streetlights bleed upward in thin gold leaf strokes. Cracked asphalt texture mapped over smooth charcoal ink washes. Dominant palette: matte black, oxidized gold, and cool architectural grey. Deliberate visible brushwork over collage seams. Subtle iridescent glaze on gold elements. High resolution, museum print quality, depth of layers visible, art direction by a contemporary mixed-media master." )

# 02 — Structural Reverie — fabric, geometry, long exposure
prompts+=( "Large-format mixed media abstract composition. Shredded silk organza, raw-edge denim, and woven wool patches are physically layered and photographed, then overworked with india ink, gold gesso, and graphite powder. Dense faceless crowd silhouettes stenciled in flat black. Overhead highway geometry fragments into angular collage planes. Streetlight halos rendered as hand-stamped gold foil circles bleeding into grey newsprint. Background: deep charcoal smoke texture. Foreground: metallic gold thread stitching runs across composition in loose grid lines. 8K fine art photography of physical artwork, raking light reveals tactile surface relief, no CGI sheen." )

# 03 — Meridian — dystopian night city, deconstructed
prompts+=( "Abstract expressionist mixed media triptych panel. Foundation: weathered concrete texture with embedded torn newspaper fragments and rusted wire gauze. Mid-layer: elongated human silhouettes dissolving into road map contour lines, printed on translucent vellum and torn at edges. Top layer: gestural oil-stick marks in gold and warm amber trace power lines and streetlight poles. A lone figure's silhouette anchors the lower third, surrounded by diffused grey halogen light pools. Colour story: 85% desaturated — blacks, slates, warm greys; 15% gold-bronze accent. Strong negative space. Flat photograph of physical canvas, natural studio lighting, zero post-processing glow." )

# 04 — Passage — wabi-sabi, transit, material memory
prompts+=( "Mixed media collage painting with wabi-sabi material philosophy. Substrate: aged canvas stained with walnut ink, coarse hessian patches stitched at irregular angles. Human figures reduced to ink-rubbed silhouettes, some partially obscured under fabric layers. Receding urban road drawn in single-point perspective using gold metallic pen, lines fraying into brushstrokes at edges. Overhead streetlamps as vertical gold ink drips, halos smudged with thumb. Fragments of maps, bus tickets, and transit typography torn and embedded. Palette: soot black, antique gold, pewter, and off-white raw linen. Shot under raking natural light to exaggerate collage texture. High-end art book quality reproduction." )

# 05 — Frequency — motion blur, crowd, signal and noise
prompts+=( "Monumental abstract mixed media work, inspired by Kiefer and Basquiat. Ground built from industrial felt, blackened cheesecloth, and crumpled foil, all glued to stretched canvas. Multiple overlapping silhouettes in motion blur: commuters, a running child, a standing figure — all in flat tar black. Urban road infrastructure (lane markings, kerb lines, traffic light poles) printed on acetate, layered and burned at corners. Gold wax crayon hatching over entire composition in diagonal sweeps, catching collage edges. Secondary marks: chalk-grey gestural arcs evoking data signals or crowd noise. Tertiary elements: actual thread unraveling from fabric into open canvas space. Extreme close-up macro photography of physical artwork, high-contrast studio light from left." )

# --- Gemini 3.1 Flash ---

# 06 — The Weaver's Dream
prompts+=( "A masterpiece mixed media artwork presenting a breathtaking portrait of a woman. Her face is intricately rendered in soft watercolor and charcoal, while her flowing hair is a lush cascade of actual woven textiles, yarn, colorful embroidery thread, and small found beads, flowing beyond the canvas edge. The background is a collage of vintage maps and old sheet music, distressed and layered with textured paint. The mood is contemplative and beautiful, exhibiting extreme tactile depth and artisanal skill." )

# 07 — The Nostalgic Cabinet
prompts+=( "A stunning three-dimensional mixed media assemblage artwork arranged in a weathered shadow box frame. It features a curated collection of antique items: skeleton keys, old sepia photographs, clockwork gears, dried pressed butterflies, glass vials filled with colored pigments, and tarnished silver spoons. These objects are set against a background of aged, crackled plaster and layered with handwritten script. Wires and natural twine connect the elements. A cohesive, complex, narrative artwork with a rich patina and historical feel." )

# 08 — Midnight Garden
prompts+=( "An enchanting mixed media textile art piece depicting a mystical garden under moonlight. The night sky is deep blue velvet with silver thread constellation embroidery. The flowers and foliage are constructed from layers of frayed silk organza, felt cutouts, and vintage lace, creating a dimensional, plush texture. Beading mimics morning dew on leaves. The garden gate is shaped from twisted copper wire. Highly intricate, charming, and deeply textural, merging craft and fine art." )

# 09 — The Storybook City
prompts+=( "A magical mixed media artwork capturing a bustling, whimsical cityscape. The buildings are constructed from layered collage: scraps of colorful Japanese washi paper, patterned fabrics, and old dictionary pages for window details. The roofs are highlighted with shimmering gold leaf. Tiny, fantastical people made of wire and clay move through the streets. The entire piece is layered under a glossy resin finish, making the collage materials glow with depth and rich color. Playful, narrative, and intricately detailed." )

# 10 — The Botanist's Studio
prompts+=( "A elegant and cerebral mixed media piece blurring the line between science and art. A central, exquisitely detailed watercolor illustration of an iris flower is surrounded by actual preserved botanical specimens (dried leaves and petals) affixed with linen tape. Architectural drafting vellum overlays sections with scientific notes and diagrams in fine black ink. The background is aged, stained paper with texture paste reliefs of leaf skeletons. Museum-quality, tactile, and thoughtfully composed." )

# --- ChatGPT ---

# 11 — Urban Memory Collage
prompts+=( "Mixed media abstract masterpiece, urban memory collage composed of layered torn paper, raw linen fabric, and distressed canvas textures. Fragmented human silhouettes emerge subtly from overlapping materials, partially obscured as if fading into memory. Thin gold leaf veins trace through the composition like illuminated streets at night, connecting abstract road networks and streetlight forms. Asphalt-like textures, charcoal smudges, and soft graphite shading create depth. Color palette strictly limited to matte black, muted greys, and metallic gold accents (5-10%). Soft directional lighting reveals tactile surface relief, ultra-detailed textures, museum-quality composition, cinematic negative space, contemporary fine art aesthetic." )

# 12 — Nocturnal Infrastructure Study
prompts+=( "Abstract mixed media composition inspired by nighttime city infrastructure, constructed from layered textile fragments, gauze, and concrete-like textures. Stylized road grids and intersections appear as geometric imprints, with faint human silhouettes integrated into the structure. Gold foil lines mimic streetlights and traffic flows, glowing subtly against deep black and cold grey tones. Heavy use of impasto, scratches, and eroded surfaces. Balanced asymmetry, brutalist influence, high contrast lighting emphasizing texture depth. Minimal color palette: black, graphite grey, brushed gold highlights. Ultra high detail, gallery installation style, sophisticated and moody." )

# 13 — Fragmented Passage
prompts+=( "High-end mixed media abstract artwork depicting fragmented passage through an urban landscape. Collage of torn velvet, canvas fibers, and paper layers forming abstract roads and pathways. Silhouettes of walking figures appear elongated and blurred, embedded into the material layers. Gold accents applied as irregular strokes and leaf fragments, suggesting streetlights reflected on wet pavement. Subtle motion blur effect within static textures. Deep blacks dominate, with gradients of cool grey and restrained metallic gold (under 8%). Strong compositional flow, diagonal movement, atmospheric depth, hyper-detailed surface textures, fine art photography lighting." )

# 14 — Silent City Layers
prompts+=( "Contemporary abstract mixed media painting, silent city concept, built from layered fabric scraps, mesh textures, and oxidized surfaces. Human silhouettes reduced to minimal shadow forms, almost erased into the background. Structured lines resembling roads and streetlight poles cut through the composition in gold leaf and metallic pigment. Heavy contrast between matte black voids and soft grey transitions. Textural richness: cracked paint, stitched fabric seams, sanded surfaces. Carefully controlled color palette: black, warm grey, antique gold highlights. Soft spotlight illumination, museum-grade aesthetic, refined minimalism with emotional depth." )

# 15 — Luminous Grid / Human Trace
prompts+=( "Mixed media abstract fine art piece combining collage, textile art, and urban abstraction. A luminous grid of roads and pathways emerges from layered materials — canvas, burlap, and handmade paper. Human silhouettes appear as ghost-like imprints within the grid, subtly integrated into the structure. Gold metallic lines and dots evoke streetlights and navigation systems, softly glowing against a deep black and desaturated grey base. Complex layering, semi-transparent overlaps, delicate balance between chaos and structure. Extreme texture detail, macro surface realism, elegant composition, contemporary gallery masterpiece style." )

# --- Grok ---

# 16 — Nocturnal City
prompts+=( "Masterpiece mixed media abstract collage, layered textured fabrics, torn vintage maps, silhouettes of lonely figures walking under glowing streetlights, fragmented cityscapes, neon reflections on wet asphalt, scattered clock gears and birds, dramatic contrast, intricate details, black, gold, and deep charcoal grey dominating color palette, subtle crimson accents, highly detailed textures, sophisticated composition, award-winning abstract art --stylize 750 --v 6" )

# 17 — Ethereal Forest
prompts+=( "Highly detailed mixed media abstract art, rich collage of pressed leaves, bark textures, embroidered fabric pieces, deer and human silhouettes merging with trees, glowing mushrooms, winding golden paths disappearing into mist, ancient runes floating, intricate overlapping layers, deep emerald green, warm gold, and dark umber brown dominating palette with subtle silver highlights, masterpiece, cinematic depth, exquisite detail --stylize 650" )

# 18 — Dream Architect
prompts+=( "Surreal masterpiece mixed media collage, architectural fragments, blueprint papers, textured velvet and linen, floating staircases, human silhouettes building impossible structures in clouds, broken hourglasses, birds carrying keys, dramatic perspective, black, antique gold, and cool slate grey dominating colors with soft ivory accents, ultra intricate, rich textures, conceptual abstract art, best quality" )

# 19 — Ocean Memory
prompts+=( "Emotional mixed media abstract collage masterpiece, layered watercolor paper, sea-worn fabric, fishing net fragments, woman silhouette reaching into waves, sunken pocket watches, seashells, old letters, bioluminescent creatures, turbulent yet melancholic composition, deep navy blue, teal, and shimmering gold dominating palette with hints of rust, hyper detailed textures, award-winning fine art" )

# 20 — Inner Cosmos
prompts+=( "Cosmic mixed media abstract art, breathtaking collage of star maps, metallic foil scraps, velvet night sky textures, human silhouettes floating among galaxies, orbiting geometric shapes, blooming nebulae, broken mirrors reflecting stars, intricate celestial details, dominating deep black, radiant gold, and electric violet-purple palette with silver starlight, masterpiece, extremely detailed, mystical atmosphere --stylize 800" )

# --- Qwen 3.6 Plus ---

# 21 — Urban Nocturne & Chiaroscuro
prompts+=( "A mixed media abstract masterpiece blending digital collage and traditional textile art. Fragments of weathered velvet, rough linen, and silk thread are meticulously layered to form winding roads and glowing streetlights. Dark human silhouettes wander along the paths, their forms subtly woven into the textured background. The composition is dominated by deep blacks, rich charcoal greys, and luminous metallic gold accents that catch the ambient light. Dramatic chiaroscuro lighting, intricate textural contrast, museum-quality abstract expressionism, highly detailed, photorealistic fabric rendering --v 6.0 --ar 16:9" )

# 22 — Fragmented Motion & Vanishing Perspective
prompts+=( "An avant-garde mixed media collage depicting abstract urban movement. Torn pieces of embroidered cotton, distressed wool, and sheer organza overlap to create intersecting roads and vanishing perspectives. Elongated human silhouettes in motion are rendered in matte black, contrasting against sweeping strokes of brushed gold leaf and oxidized silver-grey textures. Soft directional lighting emphasizes the tactile depth of each fabric layer, while geometric abstraction guides the viewer's eye through the composition. Award-winning contemporary art, hyper-detailed texture mapping, cinematic depth of field, masterpiece --ar 3:4" )

# 23 — Atmospheric & Dreamlike Glow
prompts+=( "A dreamlike mixed media abstract artwork combining decoupage, textile collage, and subtle ink wash techniques. Layers of frayed burlap, crushed velvet, and metallic gold foil are arranged to form meandering pathways under a canopy of stylized streetlights casting long, soft glows. Faint human silhouettes stand contemplatively along the edges, their outlines blending into the grey and black fabric textures. Dominated by a moody palette of obsidian black, slate grey, and radiant antique gold. Rich tactile surfaces, atmospheric perspective, gallery-ready composition, ultra-high definition, intricate layering --v 6.0" )

# 24 — Geometric Architecture & Negative Space
prompts+=( "A meticulously crafted mixed media abstract piece merging geometric abstraction with tactile textile collage. Precise cuts of herringbone wool, raw silk, and hammered gold leaf intersect to create a network of roads, crosswalks, and minimalist streetlight forms. Shadowy human silhouettes are integrated into the negative space, rendered in deep matte black against a backdrop of layered charcoal and dove grey fabrics. High-contrast lighting accentuates the physical dimensionality of each overlapped layer. Contemporary museum exhibition quality, masterful composition, photorealistic texture rendering, 8k --ar 1:1" )

# 25 — Expressive Rain-Slicked Nightscape
prompts+=( "An expressive mixed media masterpiece combining impasto painting techniques with intricate fabric collage. Swaths of distressed denim, aged lace, and brushed gold pigment are dynamically layered to evoke a rain-slicked urban nightscape. Winding roads and glowing streetlights emerge organically from the textured chaos, while solitary human silhouettes in deep black navigate the grey-toned pathways. The color scheme is strictly anchored in rich blacks, cool greys, and luminous gold highlights that reflect off the implied wet surfaces. Evocative lighting, heavy textural depth, award-winning abstract contemporary art, highly detailed, cinematic composition --v 6.0" )

# --- GLM 5.1 ---

# 26 — Urban Tapestry
prompts+=( "Mixed media abstract masterpiece, intricately layered textile collage. Swatches of charcoal grey linen and raw silk intersect with glossy black leather patches, held together by visible metallic gold embroidery and erratic gold thread stitching. Faded silhouettes of pedestrians are woven into the fabric, walking along a fragmented asphalt road made of textured black sandpaper. Glowing amber-gold streetlights cast a warm, dusty luminance over the grey felt sky. Tactile depth, frayed edges, impasto paint strokes, 8k resolution, museum-quality contemporary assemblage, dramatic chiaroscuro, dominating colors of obsidian, shimmering gold, and ash grey." )

# 27 — Gilded Noir
prompts+=( "Deconstructed collage abstract art, gallery masterpiece. Torn edges of matte black construction paper and slate grey newsprint overlap to form a winding nocturnal road. Delicate, faceless silhouettes cut from shadow traverse the scene. The streetlights are striking applications of genuine gold leaf, catching the light with a brilliant metallic sheen, contrasting sharply against the monochromatic grey and black cityscape. Drips of liquid gold paint, subtle graphite smudges, and deep volumetric lighting. A moody, cinematic atmosphere, highly detailed paper-cut assemblage, rich textural interplay, noir aesthetic." )

# 28 — Ethereal Journey
prompts+=( "Evocative mixed media abstract painting, layered collage masterpiece. Translucent sheets of grey tissue paper and heavy black tulle create a foggy, atmospheric depth. Abstract silhouettes of people drift along a disappearing asphalt highway. Vintage streetlamps emit a soft, powdery golden glow, illuminated by embedded gold foil and luminescent pigments. Scratched film grain texture, dry brush techniques, crumbling plaster, and scattered gold leaf flakes. A melancholic yet beautiful urban dreamscape, highly detailed, masterpiece, interplay of matte greys, deep blacks, and radiant golds, soft volumetric lighting." )

# 29 — Architectural Fragment
prompts+=( "Avant-garde mixed media collage, brutalist abstract masterpiece. Angular fragments of pumice grey concrete, blackened sheet metal, and distressed denim form a jagged urban road. Faceless human silhouettes are stamped in stark black ink, navigating the debris. Tall, geometric streetlights are crafted from polished brass and gold wire, radiating a sharp, artificial gold luminescence against the gloom. Charcoal rubbings, rust textures, and peeling paint layers. Extreme tactile detail, macro photography of an assemblage artwork, high contrast, dominant palette of carbon black, steel grey, and molten gold." )

# 30 — Resin & Relic
prompts+=( "Museum-quality mixed media diorama collage, encased in clear resin. A shattered urban streetscape built from torn black canvas, silver-grey wool felt, and jagged asphalt-textured polymer. Shadowy silhouettes of lone figures stand beneath ornate streetlamps constructed from twisted gold wire and glowing amber resin. Deep glossy blacks contrasting with matte, porous greys and thick, raised gold acrylic gesso. Intricate surface imperfections, dust motes caught in the golden light, hyper-detailed textures, dramatic spotlight lighting, rich noir-and-gold palette, visually stunning masterpiece." )

# --- Kimi K2.6 Thinking ---

# 31 — Nocturnal Metropolis
prompts+=( "Mixed media abstract collage masterpiece, museum-quality textured composition. Layered fragments of raw linen, coarse burlap, and aged newsprint forming a fragmented city skyline. Human silhouettes cut from black rice paper walk along roads made of woven grey thread and gold metallic leaf. Vintage streetlight shapes emerge from torn cardboard and dried acrylic impasto in ochre and slate. Dominating palette: deep onyx black, antique gold, cool concrete grey, with subtle rust accents. Heavy gel medium creating dimensional ridges, visible brushstrokes, frayed fabric edges catching light. Moody chiaroscuro lighting, gallery presentation, ultra-detailed material realism, 8k texture resolution." )

# 32 — Forest Memory
prompts+=( "Abstract mixed media collage, masterpiece of tactile materiality. Pieces of moss-dyed cheesecloth, bark-textured handmade paper, and pressed fern silhouettes layered with embroidered thread pathways. Human silhouettes in matte black paper stand among trees constructed from torn book pages and gold foil trunks. Ground plane built from overlapping grey wool felt and charcoal pencil scribbles. Dominating colors: forest black, burnished gold, ash grey, with touches of oxidized copper. Encaustic wax drips between layers, visible staples and stitching holding fragments together. Ethereal side-lighting emphasizing every fiber and crease, fine art photography of physical artwork, hyper-detailed surface texture." )

# 33 — Tidal Fragments
prompts+=( "Mixed media abstract seascape collage, gallery masterpiece. Torn sheets of indigo-dyed muslin and translucent rice paper create ocean waves, interwoven with silver-grey fishing net and dried salt crystals. Human silhouettes in black tissue paper stand on a shoreline made of cracked gesso and gold leaf pebbles. Roads of braided sisal rope lead to lighthouses constructed from corrugated cardboard and metallic gold paint. Palette dominated by midnight black, pale gold, storm grey, with foam-white highlights. Heavy impasto sand texture, layered resin pools, torn edges with visible glue marks. Dramatic raking light, museum archival quality, exquisite material detail." )

# 34 — Cartographic Dreams
prompts+=( "Abstract mixed media collage, cartographic masterpiece. Fragments of vintage topographical maps, faded blueprints, and leather scraps form an aerial view of an imaginary city. Roads rendered in stitched black thread and gold wire intersect at paper silhouettes of walking figures. Streetlights made from watch gears and brass foil dot the landscape. Textured fabric patches in tweed and canvas create building volumes. Dominating palette: archival black, brass gold, map grey, sepia undertones. Coffee stains and foxing on paper edges, raised topography from built-up gel medium, hand-lettered labels in india ink. Soft diffused studio lighting, Leica-quality documentation of physical artwork, every fiber and grain visible." )

# 35 — Celestial Transit
prompts+=( "Mixed media abstract cosmic collage, transcendent masterpiece. Swaths of black silk organza and metallic gold lame create a night sky punctured with pinprick star holes. Human silhouettes in matte black construction paper ride roads of silver-grey ribbon and piano wire stretching between floating landmasses of encaustic wax and pressed dried flowers. Streetlight orbs made from vintage glass marbles and gold leaf emit warm halos. Dominating colors: absolute black, celestial gold, lunar grey, with subtle violet shadows. Layered tulle creating atmospheric depth, embroidered constellation lines, torn paper nebulae with spray paint gradients. Cinematic gallery lighting, monumental scale implied, flawless material documentation, hyperreal texture capture." )

# --- Deepseek ---

# 36 — The Midnight Commute
prompts+=( "Mixed media abstract art masterpiece. A dense collage of crumpled sheet music, coarse grey burlap, and torn newspaper fragments. Dominant shapes: a lone silhouette of a hunched figure walking a tightrope of gold leaf threads, surrounded by fragmented city streetlights dripping black ink. Layered textures of charcoal dust and gritty asphalt. Overhead, a subtle cartography grid in muted gold. The composition evokes urban isolation and mechanical rhythm. Deep blacks, metallic gold, and ash grey dominate. Intricate detail, high resolution, textured canvas finish." )

# 37 — Echoes of a Lost Avenue
prompts+=( "A masterwork of abstract mixed media. Collage elements include layered grey wool fabric, cracked black leather, and delicate gold foil peeling from a dark background. Central motif: multiple overlapping silhouettes of pedestrians dissolving into a vertical line of glowing, hazy streetlamps. Faint, ghost-like road markings (dashed lines) weave through the composition like a torn paper river. Splatters of black India ink and dry-brushed metallic gold dust. A palpable sense of motion and melancholy. Colors: noir black, tarnished gold, and stormcloud grey. Ultra-detailed, museum quality, tactile realism." )

# 38 — Gilded Wreckage
prompts+=( "Detailed masterpiece of mixed media abstract art. Collage of asphalt-textured paper, rough grey linen, and torn pieces of a vintage road map. A central, fragmented silhouette of a crowd is constructed from jagged pieces of blackened mirrors. Liquid gold cascades through the center, forming distorted streetlight reflections in puddles. Dusty charcoal smudges create depth. Rough, torn edges and visible tape strips add to the deconstructed feel. Emotional weight of urban decay and faded glory. Monochromatic black, layered greys, and striking, muted gold accents. Sharp focus, 8K, textured art print." )

# 39 — Silhouette Symphony in Grey & Gold
prompts+=( "An exceptional mixed media abstract art piece. Combines sewn patches of grey felt, crumpled black tissue, and gold leaf veins like circuitry. Dominated by a chorus of elegant, elongated people silhouettes, their edges bleeding into vertical streaks that suggest rain-streaked streetlights. A subtle horizon line of torn road stripes anchors the bottom. Dried pumice gel and gritty texture medium create a relief effect. The composition is a symphony of loneliness and mechanical beauty. Core palette: matte black, burnished gold, and pearl grey. Masterpiece detail, collage visible, gallery lighting." )

# 40 — The Golden Thread of Memory
prompts+=( "Mixed media abstract art, masterpiece-level. Foundation of layered grey cardboard, chalky black gesso, and torn pages from an old engineering manual. A single, winding road of woven gold thread cuts diagonally across the image, lined by tiny, blurry streetlight shapes made from punched gold circles. Human silhouettes are barely suggested as negative space cut from black vellum, walking away. Patches of textured grey netting overlay sections like fog or smoke. The feeling is one of a forgotten dream of the city. Colors: jet black, antique gold, and charcoal grey. Exquisite texture, high detail, evocative and haunting." )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
