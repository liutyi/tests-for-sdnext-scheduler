#!/usr/bin/env bash
set -euo pipefail

echo
echo Set schedule for $MODEL with STEPS=$STEPS, CFG=$CFG, AG=$AG, SEED=$SEED, ${WIDTH}x${HEIGHT}
echo

MODEL="${MODEL:-}"
if [[ -z "$MODEL" ]]; then
  echo "❌ MODEL is not set. Export it before running:" >&2
  echo '   export MODEL="Diffusers/baidu/ERNIE-Image-Turbo [54f8a75695]"' >&2
  exit 1
fi

# ---- PROMPT WRAPPER -------------------------------------------------------
# Every prompt is assembled as:   ${PROMPT_PREFIX} <core> ${PROMPT_SUFFIX}
#
# Leave either blank ("") to disable it.
# A single space is inserted between non-empty parts automatically;
# no trailing/leading spaces are needed inside the variables.
#
# Typical uses:
#   PREFIX — shared scene framing that opens every prompt
#   SUFFIX — quality boosters, negative-space reminder, aspect hint, etc.
# ---------------------------------------------------------------------------
PROMPT_PREFIX=\
"A dark-toned portrait photograph. \
The horizontal widescreen composition is highly dramatic and artistic, \
with at least 80% of the area being pure negative space \
ranging from deep dark tones to absolute black, \
concentrated heavily across the left and center. \
The far right edge reveals"

PROMPT_SUFFIX=\
"Studio low-key lighting with precision edge lighting \
traces the lit contours of the face and instrument, \
celebrating skin texture while allowing all shadow areas \
to dissolve naturally into the background. \
Shot on medium-format, tack-sharp focus on the instrument tip."

# ---- PROMPT TEMPLATE ------------------------------------------------------
# build_prompt assembles a full prompt from named slots.
#
# Usage:
#   build_prompt \
#     --subject    "a close-up profile of …" \
#     --details    "only … visible" \
#     --expression "the stillness of …" \
#     --instrument "a traditional fude brush, …" \
#     --contact    "the bristle tip resting against …" \
#     --mood       "ancient, meditative, …"
#
# Any slot can be omitted; only non-empty slots are emitted.
# PROMPT_PREFIX / PROMPT_SUFFIX are applied automatically.
# ---------------------------------------------------------------------------
build_prompt() {
  local subject="" details="" expression="" instrument="" contact="" mood=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --subject)    subject="$2";    shift 2 ;;
      --details)    details="$2";    shift 2 ;;
      --expression) expression="$2"; shift 2 ;;
      --instrument) instrument="$2"; shift 2 ;;
      --contact)    contact="$2";    shift 2 ;;
      --mood)       mood="$2";       shift 2 ;;
      *) echo "build_prompt: unknown slot '$1'" >&2; return 1 ;;
    esac
  done

  local -a parts=()
  [[ -n "$subject"    ]] && parts+=("$subject —")
  [[ -n "$details"    ]] && parts+=("$details.")
  [[ -n "$expression" ]] && parts+=("Her expression: $expression.")
  [[ -n "$instrument" ]] && parts+=("She holds $instrument.")
  [[ -n "$contact"    ]] && parts+=("$contact.")
  [[ -n "$mood"       ]] && parts+=("The mood is $mood.")

  local core="${parts[*]}"

  local result=""
  [[ -n "$PROMPT_PREFIX" ]] && result+="${PROMPT_PREFIX} "
  result+="$core"
  [[ -n "$PROMPT_SUFFIX" ]] && result+=" ${PROMPT_SUFFIX}"

  printf '%s' "$result"
}

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
# Two styles are supported and can be mixed freely in the same array:
#
#   A) Slot-based — recommended for template series like this one.
#      Prefix and suffix are applied automatically by build_prompt.
#        prompts+=( "$(build_prompt --subject "…" --instrument "…" …)" )
#
#   B) Verbatim — full prompt written by hand; prefix/suffix NOT applied.
#      Use when a specific shot needs to deviate entirely from the template.
#        prompts+=( "Raw prompt text here, exactly as sent to the model." )
# ---------------------------------------------------------------------------
prompts=()

# 01 · Calligrapher — elderly Japanese woman, ~70s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of an elderly Japanese woman in her seventies, facing left" \
  --details    "only the outline of her face, the strong architecture of her cheekbone, and the silver-white fall of her upswept hair are visible" \
  --expression "the stillness of a person who has long since made peace with silence" \
  --instrument "a traditional Japanese fude calligraphy brush, its lacquered bamboo handle gripped loosely between her index and middle fingers" \
  --contact    "the soft ink-laden bristle tip resting delicately against the center of her lower lip; the faint sheen of black ink barely visible on the bristle's edge" \
  --mood       "ancient, meditative, and deeply reverential" \
)" )

# 02 · Neurosurgeon — middle-aged Nigerian woman, ~45s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a middle-aged Nigerian woman in her mid-forties, facing left" \
  --details    "only the strong contour of her face, a sculptural cheekbone, and the edge of close-cropped natural hair are visible against the dark" \
  --expression "internal and focused — the look of someone visualizing a problem only she can see" \
  --instrument "a pair of stainless steel surgical ring forceps — the closed tips resting firmly under her chin, the pivot joint level with her jaw, her fingers resting through the rings with clinical familiarity" \
  --contact    "the cold reflection of the steel instrument catching the edge light precisely" \
  --mood       "austere, brilliant, and electrifyingly composed" \
)" )

# 03 · Architect — young Polish woman, ~late 20s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Polish woman in her late twenties, facing left" \
  --details    "only the clean line of her profile, the pale curve of her ear, and a loose strand of ash-blonde hair escaping from a bun are visible" \
  --expression "concentrated analysis, as though measuring something invisible" \
  --instrument "a traditional drafting compass, its metal handle rising from her grip, the two legs closed together" \
  --contact    "the fine brass pivot point resting lightly at the corner of her mouth where lip meets skin; her fingers hold it the way a conductor holds a baton" \
  --mood       "precise, architectural, and quietly formidable" \
)" )

# 04 · Jazz Vocalist — young Brazilian woman, ~early 30s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Brazilian woman in her early thirties, facing left" \
  --details    "only the sensuous curve of her profile, the fullness of her lips, and the voluminous coils of her natural hair silhouetted against the dark are discernible" \
  --expression "neither singing nor silence — the suspended moment between the two" \
  --instrument "a vintage-style large-diaphragm dynamic microphone held horizontally, cylindrical steel mesh head, fingers wrapped loosely around the body" \
  --contact    "the mesh head pressed gently but deliberately against the center of her closed lips; the grille reflecting a thin crescent of edge light" \
  --mood       "suspended, cinematic, and achingly intimate" \
)" )

# 05 · Watch Restorer — middle-aged Swiss woman, ~early 50s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a middle-aged Swiss woman in her early fifties, facing left" \
  --details    "only the refined outline of her face, her reading glasses pushed up onto her forehead, and silver-streaked hair pinned neatly back are visible in the darkness" \
  --expression "the patience of a person accustomed to infinite patience with tiny things" \
  --instrument "a brass jeweler's loupe pressed firmly against her right eye with one hand; with the other, a precision watchmaker's screwdriver — barely 1.5mm wide — held between thumb and forefinger" \
  --contact    "the flat blade resting with casual authority against the curve of her upper lip; the chrome steel shaft catching a needle-thin highlight" \
  --mood       "exact, obsessive, and timelessly concentrated" \
)" )

# 06 · Chess Grandmaster — young Indian woman, ~mid 20s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Indian woman in her mid-twenties, facing left" \
  --details    "only the clean arc of her profile, a long dark braid falling over one shoulder, and the delicate gold stud of an earring catching the edge light are visible" \
  --expression "remote and calculating — eyes focused somewhere far past the frame" \
  --instrument "a full-sized tournament chess queen piece — ivory-white, its finial crown pointing upward — held between the pads of her thumb, index, and middle finger" \
  --contact    "the smooth base resting softly against the center of her lips; the polished dome casting a faint reflected light back against her cheek" \
  --mood       "strategic, regal, and unsettlingly still" \
)" )

# 07 · Glassblower — older Mexican woman, ~early 60s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a Mexican woman in her early sixties, facing left" \
  --details    "only the weathered and magnificent contour of her face, prominent cheekbones, deep-set eyes, and thick dark hair streaked with white are visible in profile" \
  --expression "the confidence of a craft practiced for decades" \
  --instrument "a glassblowing pipe — the iron mouthpiece end, a narrow steel cylinder worn smooth from years of use — her fingers cradling the pipe with instinctive ease" \
  --contact    "the mouthpiece pressed against her slightly parted lips, her cheeks just barely hollowed in preparation for breath" \
  --mood       "elemental, commanding, and alive with latent heat" \
)" )

# 08 · Marine Biologist — young Australian Aboriginal woman, ~early 30s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Australian Aboriginal woman in her early thirties, facing left" \
  --details    "only the strong and beautiful architecture of her profile, wide-set eyes, a generous mouth, and the tight coil of her dark hair caught in a knot are visible" \
  --expression "precise, curious intelligence" \
  --instrument "a glass laboratory pipette at chest height — its slender transparent body rising diagonally from her grip" \
  --contact    "the tapered glass tip resting gently against the center of her lower lip; the glass catching a single fine line of edge light along its length, nearly invisible until it catches" \
  --mood       "oceanic in its calm — observational, sharp, and full of quiet wonder" \
)" )

# 09 · Ceramicist — elderly Korean woman, ~mid 70s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of an elderly Korean woman in her mid-seventies, facing left" \
  --details    "only the deeply lined and magnificent contour of her face, the strong horizontal crease of her eyelid, and a loose knot of white hair are visible" \
  --expression "total absorption — the stillness of someone who has spent a lifetime listening to clay" \
  --instrument "a loop trimming tool — a small wire-tipped instrument used to carve wet ceramics, its wooden handle gripped lightly between her fingers" \
  --contact    "the curved stainless wire loop resting against the center of her lower lip, not pressing, merely touching, as though tasting the shape of a decision; the wire catching a near-invisible filament of highlight" \
  --mood       "weathered, sovereign, and perfectly at rest" \
)" )

# 10 · Conductor — middle-aged Russian woman, ~early 50s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a middle-aged Russian woman in her early fifties, facing left" \
  --details    "only the imperious architecture of her profile, a high and wide Slavic forehead, and dark hair swept back with severe elegance are discernible against the dark" \
  --expression "the authority of someone accustomed to silence falling when she raises her hand" \
  --instrument "a white fiberglass orchestral baton — its narrow shaft angled slightly downward — fingers holding it with the specific grip of decades of rehearsal" \
  --contact    "the pointed tip resting with deliberate precision against the bow of her upper lip, steady as a metronome at rest; the baton's taper catching a clean cold highlight along its length" \
  --mood       "commanding, interior, and charged with the memory of sound" \
)" )

# 11 · Tattoo Artist — young Filipina woman, ~late 20s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Filipina woman in her late twenties, facing left" \
  --details    "only the smooth curve of her profile, the soft geometry of her nose, and the dark fall of long straight hair are visible" \
  --expression "inward and private — the look of a person in the midst of a visual problem only they can solve" \
  --instrument "a professional rotary tattoo machine — matte black aluminum body, slim and ergonomic — cradled in a practiced grip between palm and fingers, needle tip retracted" \
  --contact    "the front of the machine resting gently against the point of her chin; its subtle metallic texture catching the edge light in broken facets" \
  --mood       "creative, concentrated, and quietly electric" \
)" )

# 12 · Weaver — elderly Navajo woman, ~mid 70s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a Navajo elder in her mid-seventies, facing left" \
  --details    "only the broad and majestic contour of her face, the deeply incised lines of a life outdoors, and thick silver-streaked hair parted in the center and pulled back are visible" \
  --expression "the gravity of inherited knowledge" \
  --instrument "a traditional wooden weaving comb — flat, toothed, carved from pale hardwood, worn smooth at its handle by years of use — held lightly by both hands whose fingers interlace around it with natural ease" \
  --contact    "the comb's edge resting at the center of her closed mouth; the pale wood catching the edge light differently from the dark surround" \
  --mood       "ancient, rooted, and quietly monumental" \
)" )

# 13 · Violinist — young Colombian woman, ~mid 20s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Colombian woman in her mid-twenties, facing left" \
  --details    "only the elegant line of her profile, the soft fullness of her lips, and the loose dark waves of her hair just visible at the edge are discernible" \
  --expression "suspended between two movements — the silence that is also music" \
  --instrument "a full-length concert violin bow — pernambuco wood, the stick arching very slightly — the rest of the bow disappearing into darkness at the left of the frame" \
  --contact    "the ivory tip touching the right corner of her lips with featherlight precision; catching a single spot of edge light" \
  --mood       "suspended, lyrical, and breathlessly still" \
)" )

# 14 · Acupuncturist — middle-aged Chinese woman, ~mid 40s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a Chinese woman in her mid-forties, facing left" \
  --details    "only the refined contour of her face, the clean geometry of her jaw, and dark hair pulled back at the nape of her neck are visible" \
  --expression "precise calm — the practiced stillness of someone whose hands must never tremble" \
  --instrument "a single sterile acupuncture needle — hair-thin silver shaft barely 0.25mm wide, guide tube absent — held with extraordinary delicacy between the very tips of her thumb and index finger" \
  --contact    "the fine silver point resting perpendicularly against the center of her lower lip, perfectly still; almost invisible until it catches the edge light as a single luminous filament" \
  --mood       "surgical, serene, and tremblingly precise" \
)" )

# 15 · Forensic Scientist — young Scottish woman, ~early 30s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Scottish woman in her early thirties, facing left" \
  --details    "only the strong and clean line of her profile, a faint scatter of freckles just visible on the lit edge of her cheek, and auburn hair pulled back tightly are discernible" \
  --expression "clinically focused — the look of someone reading evidence in invisible ink" \
  --instrument "a pair of fine-tipped stainless steel laboratory tweezers — closed, the tips pinching together at a point — held in a two-finger grip, the elbow of the tweezers pointing toward the camera" \
  --contact    "the very end of the blades resting against the arch of her upper lip; the stainless steel catching a long cold highlight along both blades" \
  --mood       "analytical, cool-toned, and quietly relentless" \
)" )

# 16 · Opera Singer — elderly Italian woman, ~late 60s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of an Italian woman in her late sixties, facing left" \
  --details    "only the grand and expressive architecture of her face, the strong Roman nose, full lips, and silver hair arranged with theatrical elegance are visible" \
  --expression "the complex gravity of someone who has sung grief and ecstasy in equal measure for forty years" \
  --instrument "a steel tuning fork held by its stem — the two tines just struck, still vibrating infinitesimally — gripped with a performer's certainty" \
  --contact    "the rounded top of the stem pressed directly against the center of her closed lips, conducting the tone into her skull the way singers test pitch; the clean chrome glowing in the edge light" \
  --mood       "magnificent, melancholic, and vibrating with memory" \
)" )

# 17 · Fashion Designer — middle-aged Senegalese woman, ~mid 40s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a Senegalese woman in her mid-forties, facing left" \
  --details    "only the striking geometry of her profile, wide-set eyes, a sharply defined philtrum, and close-cropped natural hair are visible" \
  --expression "evaluative — the look of someone who sees a finished garment when others see raw cloth" \
  --instrument "a flat triangular wedge of white tailor's chalk between two fingers, its sharp edge pressed sideways against her lower lip, the way a designer pauses mid-sketch" \
  --contact    "a faint powder ghost of white transferring at the point of contact; the bright white triangle a small brilliant shape against the darkness" \
  --mood       "inventive, imperious, and visually acute" \
)" )

# 18 · Astronomer — young Iranian woman, ~late 20s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Iranian woman in her late twenties, facing left" \
  --details    "only the thoughtful and precise line of her profile, a straight strong nose, and dark hair escaping loosely from behind her ear are visible" \
  --expression "navigational — as though she is plotting a path through something vast" \
  --instrument "a cylindrical astronomy laser pointer — black anodized aluminum, pen-sized, used to trace constellations — held loosely between two fingers, no beam visible" \
  --contact    "the blunt emitter end resting against the center of her upper lip, pointed inward; the matte surface catching a faint edge reflection" \
  --mood       "searching, cosmically patient, and lit from within" \
)" )

# 19 · Luthier — middle-aged Argentinian woman, ~early 50s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of an Argentinian woman in her early fifties, facing left" \
  --details    "only the handsome and assured line of her profile, a paint-flecked cheekbone, and dark hair threaded with silver tucked behind her ear are visible" \
  --expression "reconciling feel with theory — a craftsperson mid-decision" \
  --instrument "a purfling cutter — a specialized lutherie hand tool with a short wooden handle and twin parallel steel blades used to inlay decorative channels around a violin top — the wooden handle cupped in her palm" \
  --contact    "the blade end resting with quiet weight against the side of her lower lip, her thumb along the spine of the tool; the pale worn wood catching the edge light warmly" \
  --mood       "tactile, devoted, and saturated with craft" \
)" )

# 20 · Neuroscientist — young Congolese woman, ~early 30s
prompts+=( "$(build_prompt \
  --subject    "a close-up profile of a young Congolese woman in her early thirties, facing left" \
  --details    "only the brilliant and composed line of her profile, high cheekbones, and densely coiled natural hair arranged in a loose crown are visible" \
  --expression "suspended certainty — a hypothesis forming behind her eyes" \
  --instrument "a borosilicate glass capillary tube — barely 1mm wide, used in electrophysiology and cell injection — gripped between her thumb and the side of her index finger" \
  --contact    "the polished open end resting precisely against the center of her lower lip, parallel to the ground; the glass nearly invisible except for a single luminous line of edge light running its full length" \
  --mood       "extraordinary — precise, radiant, and on the edge of discovery" \
)" )

# ---- QUEUE JOBS ------------------------------------------------------------
for (( i=0; i<${#prompts[@]}; i++ )); do
  queue_job $((i+1)) "${prompts[$i]}"
done

echo "✅ All ${#prompts[@]} jobs queued in scheduler"
