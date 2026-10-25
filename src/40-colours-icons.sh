# ---------------------------------------------------------------- colours --

# A colour name, or six hex digits: ASCII ones only (see validate_profile_name).
color_hex() {
  local LC_ALL=C
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    blue)   printf '2E7DF6' ;; green)  printf '2FB344' ;; red)    printf 'E5484D' ;;
    orange) printf 'F76B15' ;; purple) printf '8E4EC6' ;; pink)   printf 'D6409F' ;;
    teal)   printf '12A594' ;; yellow) printf 'F5B400' ;; gray|grey) printf '6B7280' ;;
    graphite|black) printf '1F2430' ;;
    [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

# Every name color_hex accepts, used in the "unknown colour" error so it cannot
# claim a smaller set than the code takes. (help and the README list the main
# spellings and leave out the aliases grey and black.) auto_color only picks from
# the first eight — the neutrals are opt-in, never assigned automatically.
COLOR_NAMES="blue green orange purple teal pink red yellow gray grey graphite black"
AUTO_COLOR_NAMES="blue green orange purple teal pink red yellow"

# Stable colour per profile name, so a profile always looks the same.
auto_color() {
  local sum n i
  sum=$(printf '%s' "$1" | cksum | awk '{print $1}')
  n=$(printf '%s' "$AUTO_COLOR_NAMES" | wc -w | tr -d ' ')
  i=$(( sum % n + 1 ))
  printf '%s' "$AUTO_COLOR_NAMES" | awk -v i="$i" '{print $i}'
}

# ------------------------------------------------------------------ icons --

# Composite a coloured badge with a letter onto the source app's icon.
# Uses only what ships with macOS: iconutil for icns<->png, and JXA/Cocoa to draw.
# If anything here fails we fall back to the app's plain icon — never fatal.
build_icon() {
  local tmp rc
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/aidentity.XXXXXX") || return 1
  _build_icon_in "$1" "$2" "$3" "$4" "$tmp"
  rc=$?
  rm -rf "$tmp"
  return $rc
}

_build_icon_in() {
  local src_app="$1" letter="$2" hex="$3" out_icns="$4" tmp="$5"
  local src_icns

  src_icns=$(app_icns "$src_app") || return 1

  iconutil -c iconset "$src_icns" -o "$tmp/base.iconset" >/dev/null 2>&1 || return 1

  cat > "$tmp/badge.jxa" <<'JXA'
ObjC.import('Cocoa');
// argv: letter, hex, then one or more image paths, each badged in place.
// Spinning a separate osascript per size cost ~60ms of interpreter boot each;
// batching cut a badged `add` from ~805ms to ~331ms with identical output.
function run(argv) {
  var letter = argv[0], hex = argv[1];
  var failed = 0;
  for (var i = 2; i < argv.length; i++) {
    if (badge(argv[i], argv[i], letter, hex) !== 0) failed++;
  }
  return failed === 0 ? 0 : 1;
}

function badge(inPath, outPath, letter, hex) {
  var src = $.NSImage.alloc.initWithContentsOfFile(inPath);
  if (!src || src.isNil()) return 1;
  var W = src.size.width, H = src.size.height;
  if (W < 1) return 1;
  var out = $.NSImage.alloc.initWithSize({width: W, height: H});
  out.lockFocus;
  src.drawInRect($.NSMakeRect(0, 0, W, H));

  var d = W * 0.44, x = W - d - W * 0.03, y = W * 0.03;
  var r = parseInt(hex.substr(0,2),16)/255,
      g = parseInt(hex.substr(2,2),16)/255,
      b = parseInt(hex.substr(4,2),16)/255;

  // A light ring keeps the badge readable over any icon.
  $.NSColor.colorWithCalibratedRedGreenBlueAlpha(1,1,1,0.96).set;
  $.NSBezierPath.bezierPathWithOvalInRect(
    $.NSMakeRect(x - W*0.022, y - W*0.022, d + W*0.044, d + W*0.044)).fill;
  $.NSColor.colorWithCalibratedRedGreenBlueAlpha(r,g,b,1).set;
  $.NSBezierPath.bezierPathWithOvalInRect($.NSMakeRect(x, y, d, d)).fill;

  var attrs = $.NSMutableDictionary.dictionary;
  attrs.setObjectForKey($.NSFont.boldSystemFontOfSize(d * 0.60), "NSFont");
  attrs.setObjectForKey($.NSColor.whiteColor, "NSColor");
  var s = $.NSString.alloc.initWithUTF8String(letter);
  var ts = s.sizeWithAttributes(attrs);
  s.drawAtPointWithAttributes({x: x + (d - ts.width)/2, y: y + (d - ts.height)/2}, attrs);

  out.unlockFocus;
  var rep = $.NSBitmapImageRep.imageRepWithData(out.TIFFRepresentation);
  rep.representationUsingTypeProperties(4, $.NSDictionary.dictionary)
     .writeToFileAtomically(outPath, true);
  return 0;
}
JXA

  # Badge only the sizes where a letter is legible; leave 16/32 as-is. All of
  # them go to ONE osascript call — the Cocoa runtime costs far more to start
  # than the drawing costs to run.
  local f base targets=()
  for f in "$tmp/base.iconset"/*.png; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      icon_16x16.png|icon_16x16@2x.png|icon_32x32.png) continue ;;
    esac
    targets+=("$f")
  done
  if [ "${#targets[@]}" -gt 0 ]; then
    osascript -l JavaScript "$tmp/badge.jxa" "$letter" "$hex" "${targets[@]}" >/dev/null 2>&1 || true
  fi

  iconutil -c icns "$tmp/base.iconset" -o "$out_icns" >/dev/null 2>&1 || return 1
  [ -f "$out_icns" ]
}
