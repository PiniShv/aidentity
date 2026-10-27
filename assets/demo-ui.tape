# aidentity ui demo — recorded inside the same sandbox as demo.tape, with the
# same terminal size, font, theme and typing speed, so both clips look alike.
#
# Regenerate with:  bash assets/record-demo.sh ui
#
# Privacy: as in demo.tape, everything points at a throwaway temporary
# directory with stand-in apps, so no app list, username, hostname or real
# path can appear. The profiles are made off camera.
#
# Each step waits for the screen it needs (Wait) instead of sleeping and hoping:
# on a slow or busy machine a fixed sleep lets the next key arrive before the
# menu is ready, and the key is echoed into the shell instead. Wait only polls;
# the pauses after it are what the viewer sees.

Output aidentity-ui-demo.gif

Require aidentity

Set Shell bash
Set FontSize 17
Set Width 1180
Set Height 760
Set Padding 24
Set Theme { "name": "aidentity", "background": "#0D1117", "foreground": "#C9D1D9", "cursor": "#38BDF8", "black": "#0D1117", "red": "#E5484D", "green": "#2FB344", "yellow": "#F5B400", "blue": "#2E7DF6", "magenta": "#8E4EC6", "cyan": "#22D3EE", "white": "#C9D1D9", "brightBlack": "#6B7280", "brightRed": "#E5484D", "brightGreen": "#2FB344", "brightYellow": "#F5B400", "brightBlue": "#38BDF8", "brightMagenta": "#8E4EC6", "brightCyan": "#67E8F9", "brightWhite": "#F0F6FC" }
Set TypingSpeed 55ms

Hide
Type "export PS1='$ ' && clear"
Enter
Type "aidentity add Claude --profile Work --color blue >/dev/null && aidentity add Claude --profile Personal --color green >/dev/null && aidentity add ChatGPT --profile Work --color teal >/dev/null && aidentity add Claude --main >/dev/null && clear"
Enter
Wait@120s /^\$$/
Show

Type "# Prefer a menu? One key per action."
Enter
Sleep 800ms
Type "aidentity ui"
Enter
Wait+Screen@120s /0 running/
Sleep 2s

Down
Sleep 600ms
Down
Sleep 900ms

Type "c"
Sleep 1200ms
Right
Sleep 450ms
Right
Sleep 450ms
Right
Sleep 800ms
Enter
Wait+Screen@120s /Press any key to return/
Sleep 2s
Space
Wait+Screen@120s /0 running/
Sleep 1800ms

Type "r"
Wait+Screen@120s /New account name/
Sleep 1200ms
Type "Client"
Sleep 700ms
Enter
Wait+Screen@120s /Renamed Claude Personal/
Sleep 2300ms
Space
Wait+Screen@120s /0 running/
Sleep 2s

Type "?"
Wait+Screen@120s /this help/
Sleep 3s
Space
Wait+Screen@120s /0 running/
Sleep 1800ms

Type "q"
Wait@120s /^\$$/
Sleep 1s
Type "# Back in your shell, as you left it."
Enter
Sleep 2500ms
