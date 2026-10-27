# aidentity demo — recorded entirely inside a sandbox.
#
# Regenerate with:  bash assets/record-demo.sh
#
# Privacy: HOME, the app search path, the launcher directory and the profile
# data root all point at a throwaway temporary directory seeded with fixture
# apps. The real machine is never scanned, and no command that prints machine
# details (such as `doctor`) is recorded, so no app list, username, hostname,
# path or version can appear. The prompt is a bare "$".

Output aidentity-demo.gif

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
Sleep 1s
Show

Type "# One Mac, one Claude: until now."
Enter
Sleep 1500ms

Type "aidentity apps"
Enter
Wait@20s /^\$$/
Sleep 2500ms

Type "aidentity add Claude --profile Work --color blue"
Enter
Wait@20s /^\$$/
Sleep 3s

Type "aidentity add Claude --profile Personal --color green"
Enter
Wait@20s /^\$$/
Sleep 3s

Type "aidentity add ChatGPT --profile Work --color teal"
Enter
Wait@20s /^\$$/
Sleep 3s

Type "# And one for your original account, so Claude.app is never in the way."
Enter
Sleep 1500ms

Type "aidentity add Claude --main"
Enter
Wait@20s /^\$$/
Sleep 3s

Type "# Three extra accounts and your original one, each in its own window."
Enter
Sleep 1500ms

Type "aidentity list"
Enter
Wait@20s /^\$$/
Sleep 4s

Type "# Rename one: the account stays signed in."
Enter
Sleep 1500ms

Type "aidentity rename 'Claude Personal' Client"
Enter
Wait@20s /^\$$/
Sleep 2500ms

Type "# Recolour it without touching the session."
Enter
Sleep 1200ms

Type "aidentity set 'Claude Client' --color purple"
Enter
Wait@20s /^\$$/
Sleep 2500ms

Type "# Deleted a launcher by mistake? Its account is still there."
Enter
Sleep 1500ms

Type "aidentity rm 'Claude Client' -y"
Enter
Wait@20s /^\$$/
Sleep 2500ms

Type "aidentity restore 'Claude Client'"
Enter
Wait@20s /^\$$/
Sleep 3500ms

Type "# Then click the new icons in your Dock. That's it."
Enter
Sleep 2500ms
