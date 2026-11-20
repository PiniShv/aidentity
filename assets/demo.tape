# aidentity demo: the command line. Recorded entirely inside a sandbox.
#
# Regenerate with:  bash assets/record-demo.sh main
#
# Privacy: HOME, the app search path, the launcher directory and the profile
# data root all point at a throwaway temporary directory seeded with fixture
# apps. The real machine is never scanned, and no command that prints machine
# details (such as `doctor`) is recorded, so no app list, username, hostname
# or real path can appear. The prompt is a bare "$".
#
# Each command gets a clean screen: the tape hides, clears and shows again,
# so the viewer sees one command and its answer at a time.

Output aidentity-demo.mp4

Require aidentity

Set FontSize 24

Hide
Type "export PS1='$ ' && clear"
Enter
Sleep 1s
Show

Sleep 700ms
Type "aidentity add Claude --profile Work --color blue"
Sleep 300ms
Enter
Wait@20s /^\$$/
Sleep 3500ms

Hide
Type "clear"
Enter
Sleep 300ms
Show
Sleep 500ms
Type "aidentity add Claude --profile Personal --color green"
Sleep 300ms
Enter
Wait@20s /^\$$/
Sleep 2800ms

Hide
Type "clear"
Enter
Sleep 300ms
Show
Sleep 500ms
Type "aidentity list"
Sleep 300ms
Enter
Wait@20s /^\$$/
Sleep 3500ms

Hide
Type "clear"
Enter
Sleep 300ms
Show
Sleep 500ms
Type "aidentity rename 'Claude Personal' Client"
Sleep 300ms
Enter
Wait@20s /^\$$/
Sleep 3800ms
