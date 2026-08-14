---
name: App support request
about: aidentity does not offer profiles for an app you use
title: 'Support: '
labels: app-support
assignees: ''
---

<!-- Read this first, it saves everyone time:

aidentity has no per-app list. It detects Chromium- and Electron-based apps by
looking at the bundle's structure. If your app is one of those and is still not
listed, its layout is unusual and the two listings below will show why.

If the app is genuinely native (written in Swift/AppKit), it has no
--user-data-dir switch and this approach cannot work at all. ChatGPT Classic
(com.openai.chat) is the reference example. That is a limitation, not a bug. -->

## Which app

- Name:
- Version:
- Where you got it (Mac App Store, vendor download, Homebrew cask):
- Path (usually `/Applications/<Name>.app`):

## Output of `aidentity apps`

<!-- Required. This shows what detection currently finds on your Mac. -->

```
paste here
```

## Contents of the app's Frameworks directory

<!-- Required. This is the listing that decides whether the app can work at all.
     Adjust the path to your app. -->

```sh
ls -1 "/Applications/<Name>.app/Contents/Frameworks"
```

```
paste here
```

If you see a `*.framework` in that list, also paste:

```sh
ls -1 "/Applications/<Name>.app/Contents/Frameworks/<That>.framework/Versions/"*/Helpers
```

```
paste here
```

## Bundle identifier

```sh
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "/Applications/<Name>.app/Contents/Info.plist"
```

```
paste here
```

## Does the app understand `--user-data-dir`?

<!-- Optional but decisive. Run this and say whether it opens a second, signed-out
     window. If it opens nothing, or opens your existing signed-in window, the app
     probably does not support separate profiles. -->

```sh
open -na "/Applications/<Name>.app" --args --user-data-dir=/tmp/aidentity-probe
```

Result:

## Why you want it

<!-- One line. Two work accounts, a client account, a personal account — it helps
     to know whether the app has its own built-in account switching that already
     covers you. aidentity is for having accounts signed in at the same time, in
     separate windows. -->
