# shellcheck shell=bash
# SC2016: single-quoted scripts are handed to "$BASH_BIN" -c and to generated
# stubs, which expand them later, on purpose. shellcheck only recognises that
# when the interpreter is spelled literally as `bash -c`.
# shellcheck disable=SC2016
#
# Area "basics": help, version and exit codes; apps and doctor; profile name validation;
# the letter checks under a UTF-8 locale; slugify and shquote; json_str; colours.
# Sourced by test/run_tests.sh after test/lib.sh. Run it alone with:
#   bash test/run_tests.sh basics

group "help, version and exit codes"

ai help
assert_rc "help exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "help explains the single-instance-lock mechanism" "$RUN_OUT" "single-instance lock"

ai --help
assert_rc "--help exits 0" 0 "$RUN_RC" "$RUN_OUT"
ai -h
assert_rc "-h exits 0" 0 "$RUN_RC" "$RUN_OUT"

ai
assert_rc "no arguments falls back to help and exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "no arguments prints the usage block" "$RUN_OUT" "USAGE"

ai version
assert_rc "version exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "version names the tool" "$RUN_OUT" "aidentity "
VERSION_LINE="$RUN_OUT"
ai --version
assert_eq "--version matches version" "$VERSION_LINE" "$RUN_OUT"
ai -v
assert_eq "-v matches version" "$VERSION_LINE" "$RUN_OUT"

ai definitely-not-a-command
assert_rc_nonzero "an unknown command exits non-zero" "$RUN_RC" "$RUN_OUT"
assert_contains "an unknown command says which one" "$RUN_OUT" "definitely-not-a-command"

ai add --no-such-flag
assert_rc_nonzero "an unknown option for add exits non-zero" "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP" --profile Dashes -- junk
assert_rc_nonzero "add refuses -- instead of ignoring what follows it" "$RUN_RC" "$RUN_OUT"
assert_contains "and names it as an unknown option" "$RUN_OUT" "Unknown option for add: --"
assert_no_dir "no launcher is built for it" "$APPS/Fake Dashes.app"
assert_no_dir "no profile directory is created for it" "$DATA/fake-dashes"
ai rm --no-such-flag
assert_rc_nonzero "an unknown option for rm exits non-zero" "$RUN_RC" "$RUN_OUT"

ai add
assert_rc_nonzero "add with no app and no terminal exits non-zero" "$RUN_RC" "$RUN_OUT"
ai add "$ELECTRON_APP"
assert_rc_nonzero "add with no profile and no terminal exits non-zero" "$RUN_RC" "$RUN_OUT"

ai open
assert_rc_nonzero "open with no argument exits non-zero" "$RUN_RC" "$RUN_OUT"
ai rm
assert_rc_nonzero "rm with no argument exits non-zero" "$RUN_RC" "$RUN_OUT"

group "apps and doctor"

ai apps
assert_rc "apps exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_nonempty "apps produces output" "$RUN_OUT"

ai doctor
assert_rc "doctor exits 0" 0 "$RUN_RC" "$RUN_OUT"
assert_nonempty "doctor produces output" "$RUN_OUT"
assert_contains "doctor reports the sandbox launcher directory" "$RUN_OUT" "$APPS"
assert_contains "doctor reports a macOS version" "$RUN_OUT" "macOS"
assert_contains "doctor reports the bash version" "$RUN_OUT" "bash"

if [ "$(id -u)" = "0" ]; then
  _skip "doctor flags a launcher directory it cannot write to" "running as root, every directory is writable"
else
  RO_APPS="$SB/read only apps"
  mkdir -p "$RO_APPS"
  chmod 500 "$RO_APPS"
  RUN_OUT=$(AIDENTITY_APPS_DIR="$RO_APPS" detached "$BASH_BIN" "$AIDENTITY" doctor 2>&1 </dev/null)
  chmod 700 "$RO_APPS"
  assert_contains "doctor flags a launcher directory it cannot write to" "$RUN_OUT" "NOT WRITABLE"
fi

ai list
assert_rc "list exits 0 with no profiles" 0 "$RUN_RC" "$RUN_OUT"
assert_contains "list says so when there is nothing yet" "$RUN_OUT" "No profiles yet."
ai_stdout list --json
assert_rc "list --json exits 0 with no profiles" 0 "$RUN_RC" "$RUN_ERR"
assert_eq "list --json prints an empty array when there is nothing yet" "[]" "$RUN_OUT"

group "profile name validation — rejected"

reject_name() { # description name
  libcall validate_profile_name "$2"
  assert_rc_nonzero "rejects $1" "$RUN_RC" "$RUN_OUT"
}

reject_name "an empty name"                    ""
# The single quotes below are deliberate: these strings must reach the script
# with their metacharacters intact, which is the whole point of the test.
# shellcheck disable=SC2016
reject_name "command substitution \$(...)"     'Work$(whoami)'
# shellcheck disable=SC2016
reject_name "a bare dollar sign"               'Work$HOME'
# shellcheck disable=SC2016
reject_name "backticks"                        'Work`id`'
reject_name "a double quote"                   'Work"x'
reject_name "a single quote"                   "Work'x"
reject_name "a forward slash"                  'Work/Personal'
reject_name "a leading slash"                  '/etc'
reject_name "a semicolon"                      'Work; rm -rf ~'
reject_name "an ampersand"                     'Work & Play'
reject_name "a pipe"                           'Work|Play'
reject_name "a glob star"                      'Work*'
reject_name "a redirect character"             'Work>out'
reject_name "a newline"                        "$(printf 'Work\nPersonal')"
reject_name "a tab"                            "$(printf 'Work\tX')"
reject_name "a leading space"                  ' Work'
reject_name "a trailing space"                 'Work '
reject_name "a leading dot"                    '.hidden'
reject_name "a parent-directory name"          '..'
reject_name "an XML-breaking character"        'Work<Personal'
reject_name "a colon"                          'Work:Personal'
reject_name "a backslash"                      'Work\Personal'
reject_name "a name longer than 40 characters" "$(repeat_char 41 a)"

group "profile name validation — accepted"

accept_name() { # description name
  libcall validate_profile_name "$2"
  assert_rc "accepts $1" 0 "$RUN_RC" "$RUN_OUT"
}

accept_name "a plain word"                    'Work'
accept_name "lowercase"                       'personal'
accept_name "a single letter"                 'W'
accept_name "a digit"                         '2'
accept_name "an internal space"               'My Client'
accept_name "a hyphen"                        'Client-2'
accept_name "an underscore"                   'Client_2'
accept_name "letters, digits, space, hyphen and underscore together" 'Acme Corp_2-b'
accept_name "exactly 40 characters"           "$(repeat_char 40 a)"

group "letter checks do not depend on the locale"

# In a UTF-8 locale, the default in Terminal, bash lets [A-Za-z] match letters
# such as é, ß and fullwidth ａ, and [0-9a-f] fullwidth hex digits. The suite
# runs under C, so these run the checks under en_US.UTF-8, where each must
# still refuse them.
utf8_call() { LC_ALL=en_US.UTF-8 libcall "$@"; }
for n in 'Café' 'Straße' 'ｗork' 'İstanbul' 'Ⅻ'; do
  utf8_call validate_profile_name "$n"
  assert_rc_nonzero "under en_US.UTF-8, the profile name [$n] is refused" "$RUN_RC" "$RUN_OUT"
done
utf8_call validate_profile_name 'Acme Corp_2-b'
assert_rc "and an ASCII name is still accepted there" 0 "$RUN_RC" "$RUN_OUT"
utf8_call validate_switch '--lang=dé'
assert_rc_nonzero "a language tag with é is refused" "$RUN_RC" "$RUN_OUT"
utf8_call validate_switch '--proxy-server=socks5://prøxy:1080'
assert_rc_nonzero "a proxy with ø is refused" "$RUN_RC" "$RUN_OUT"
utf8_call validate_env 'TZ=Europe/Zürich'
assert_rc_nonzero "a time zone with ü is refused" "$RUN_RC" "$RUN_OUT"
utf8_call validate_env 'LANG=dé_DE.UTF-8'
assert_rc_nonzero "a locale with é is refused" "$RUN_RC" "$RUN_OUT"
utf8_call is_bundle_id 'com.exämple.app'
assert_rc_nonzero "a bundle identifier with ä is not trusted" "$RUN_RC" "$RUN_OUT"
utf8_call typed_path '/tmp/Café'
assert_eq "a path with é is quoted for the user to type" "'/tmp/Café'" "$RUN_OUT"
# U+009B is CSI, a control code under UTF-8 but not under C: it must still be
# refused, and never printed back to the terminal.
C1=$'\xc2\x9b'
utf8_call validate_switch "--a${C1}31mX"
assert_rc_nonzero "a switch with the control code U+009B is refused" "$RUN_RC" "$RUN_OUT"
assert_not_contains "and the code is not printed back" "$RUN_OUT" "$C1"
utf8_call validate_env "LANG=de${C1}31m"
assert_rc_nonzero "an environment value with U+009B is refused" "$RUN_RC" "$RUN_OUT"
assert_not_contains "and the code is not printed back" "$RUN_OUT" "$C1"
utf8_call validate_env "A${C1}=1"
assert_rc_nonzero "a variable name with U+009B is refused" "$RUN_RC" "$RUN_OUT"
assert_not_contains "and the code is not printed back" "$RUN_OUT" "$C1"
# shown, which makes text safe to print, reads it as UTF-8 in any locale, so
# U+009B becomes ? under C too. The caller's locale is back afterwards: under
# C, é is still two bytes long.
SHOWN_IN="a${C1}b"$'\033'"c" libcall eval 'shown v "$SHOWN_IN"; u="é"; printf "%s|%s" "$v" "${#u}"'
assert_eq "under C, shown turns ESC and U+009B into ?, and C is back after it" "a?b?c|2" "$RUN_OUT"
SHOWN_IN="a${C1}b"$'\033'"c" utf8_call eval 'shown v "$SHOWN_IN"; u="é"; printf "%s|%s" "$v" "${#u}"'
assert_eq "and the same under UTF-8, which is back after it too" "a?b?c|1" "$RUN_OUT"
utf8_call validate_switch '--proxy-server=socks5://127.0.0.1:1080'
assert_rc "and an ASCII switch is still accepted there" 0 "$RUN_RC" "$RUN_OUT"
utf8_call color_hex 'ｆｆｆｆｆｆ'
assert_rc_nonzero "a colour in fullwidth hex digits is refused" "$RUN_RC" "$RUN_OUT"
utf8_call color_hex '2e7dF6'
assert_eq "and ASCII hex digits are still accepted" "2e7dF6" "$RUN_OUT"
utf8_call ui_idx256 'ｆｆｆｆｆｆ'
assert_rc "the menu's colour code refuses fullwidth hex digits, without an error" 1 "$RUN_RC" "$RUN_OUT"
assert_eq "and prints nothing" "" "$RUN_OUT"

group "slugify and shquote"

libcall slugify "Fake Work"
assert_eq "slugify lowercases and hyphenates spaces" "fake-work" "$RUN_OUT"
libcall slugify "My_Client 3"
assert_eq "slugify turns underscores into hyphens" "my-client-3" "$RUN_OUT"
libcall slugify "Claude WORK"
assert_eq "slugify lowercases uppercase input" "claude-work" "$RUN_OUT"
libcall slugify "Client-2"
assert_eq "slugify keeps existing hyphens" "client-2" "$RUN_OUT"
libcall slugify "A"
assert_eq "slugify handles a single character" "a" "$RUN_OUT"
# The slug becomes a directory name and part of a bundle identifier, and it is
# built from the *app* name too — which nothing validates. The charset filter is
# what keeps it safe, so pin it directly rather than trusting name validation.
libcall slugify 'Ev&il<x> Work'
assert_eq "slugify drops every character outside a-z0-9-" "evilx-work" "$RUN_OUT"

libcall shquote "plain"
assert_eq "shquote wraps a plain string in single quotes" "'plain'" "$RUN_OUT"
libcall shquote "/a b/c"
assert_eq "shquote keeps spaces inside the quotes" "'/a b/c'" "$RUN_OUT"
libcall shquote "it's"
assert_eq "shquote escapes an embedded single quote" "'it'\\''s'" "$RUN_OUT"

# The property that matters: whatever goes in comes back out of a shell verbatim.
shquote_roundtrip() { # description input
  local quoted back
  quoted=$("$BASH_BIN" -c '. "$1" >/dev/null 2>&1; shquote "$2"' aidentity-lib "$LIB" "$2")
  back=$("$BASH_BIN" -c "printf '%s' $quoted")
  assert_eq "shquote round-trips $1" "$2" "$back"
}
shquote_roundtrip "a path with spaces"       "/Users/x/Application Support/y"
shquote_roundtrip "an apostrophe"            "Bob's Mac"
# shellcheck disable=SC2016  # the literal $ and backticks are the payload
shquote_roundtrip "a dollar sign"            'a $HOME b'
# shellcheck disable=SC2016
shquote_roundtrip "backticks and semicolons" 'a `id`; b'
shquote_roundtrip "a double quote"           'say "hi"'

group "json_str"

libcall json_str "plain"
assert_eq "json_str wraps a plain string in double quotes" '"plain"' "$RUN_OUT"
libcall json_str 'say "hi" \ bye'
assert_eq "json_str escapes quotes and backslashes" '"say \"hi\" \\ bye"' "$RUN_OUT"
libcall json_str $'a\tb\nc\rd'
assert_eq "json_str uses the short forms for tab, newline and return" '"a\tb\nc\rd"' "$RUN_OUT"
libcall json_str $'bell\a esc\033 one\001'
assert_eq "json_str writes other control characters as \\u00XX" '"bell\u0007 esc\u001b one\u0001"' "$RUN_OUT"
libcall json_str 'Ünïcödé — 日本'
assert_eq "json_str passes UTF-8 through unchanged" '"Ünïcödé — 日本"' "$RUN_OUT"
libcall json_str ""
assert_eq "json_str quotes an empty string" '""' "$RUN_OUT"
libcall json_str_or_null ""
assert_eq "an empty value becomes null" "null" "$RUN_OUT"
libcall json_lines $'--lang=de\n\n--disable-gpu'
assert_eq "json_lines makes an array of strings, skipping blank lines" '["--lang=de","--disable-gpu"]' "$RUN_OUT"
libcall json_lines ""
assert_eq "json_lines makes an empty array from nothing" '[]' "$RUN_OUT"

# The property that matters: a JSON parser gives back exactly what went in.
# Both locales, because the loop walks bytes under C and characters under UTF-8.
json_roundtrip() { # description input
  local loc quoted
  for loc in C en_US.UTF-8; do
    quoted=$(LC_ALL=$loc "$BASH_BIN" -c '. "$1" >/dev/null 2>&1; json_str "$2"' aidentity-lib "$LIB" "$2")
    assert_eq "json_str round-trips $1 ($loc)" "true" "$(json_get "$quoted" 'd === arg' "$2")"
  done
}
ALL_ASCII=$(i=1; while [ "$i" -lt 128 ]; do printf '%b' "\\0$(printf '%03o' "$i")"; i=$((i+1)); done)
assert_eq "the test string holds every ASCII character but NUL" "127" "$(printf '%s' "$ALL_ASCII" | wc -c | tr -d ' ')"
json_roundtrip "every ASCII character"        "$ALL_ASCII"
json_roundtrip "a path with quotes and slashes" '/Users/x/My "App" \ 2/a b.app'
json_roundtrip "UTF-8 text"                   'Ünïcödé — 日本 🙂'

group "colour handling"

libcall color_hex blue
assert_eq "a named colour resolves to hex" "2E7DF6" "$RUN_OUT"
libcall color_hex BLUE
assert_eq "colour names are case-insensitive" "2E7DF6" "$RUN_OUT"
libcall color_hex 2E7DF6
assert_eq "a raw hex value passes through" "2E7DF6" "$RUN_OUT"
libcall color_hex nosuchcolour
assert_rc_nonzero "an unknown colour is rejected" "$RUN_RC" "$RUN_OUT"
libcall auto_color "Fake Work"
assert_nonempty "auto_color returns a colour for a profile" "$RUN_OUT"
AUTO_ONCE="$RUN_OUT"
libcall auto_color "Fake Work"
assert_eq "auto_color is stable for the same profile" "$AUTO_ONCE" "$RUN_OUT"
