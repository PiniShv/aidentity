# aidentity ui demo: the menu. Recorded inside the same sandbox as demo.tape,
# with the same terminal size and theme. The font is smaller, so the menu's
# line of keys fits on one line.
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

Output aidentity-ui-demo.mp4

Require aidentity

Set FontSize 18

Hide
Type "export PS1='$ ' && clear"
Enter
Type "aidentity add Claude --profile Work --color blue >/dev/null && aidentity add Claude --profile Personal --color green >/dev/null && aidentity add ChatGPT --profile Work --color teal >/dev/null && aidentity add Claude --main >/dev/null && clear"
Enter
Wait@120s /^\$$/
Show

Sleep 600ms
Type "aidentity ui"
Sleep 300ms
Enter
Wait+Screen@120s /0 running/
Sleep 2200ms

Down
Sleep 600ms
Down
Sleep 1s

Type "c"
Sleep 1200ms
Right
Sleep 1100ms
Enter
Wait+Screen@120s /Press any key to return/
Sleep 2200ms
Space
Wait+Screen@120s /0 running/
Sleep 1500ms

Type "r"
Wait+Screen@120s /New account name/
Sleep 1200ms
Type "Client"
Sleep 700ms
Enter
Wait+Screen@120s /Renamed Claude Personal/
Sleep 2500ms
Space
Wait+Screen@120s /0 running/
Sleep 3s
