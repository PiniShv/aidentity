# Dashboard components

The dashboard adapts retrieved 21st.dev component source to dependency-free vanilla JavaScript and CSS. The CLI remains the source of profile data and operations. React, Radix, Base UI, Tailwind, Motion, and Lucide runtime dependencies were replaced with native elements, inline SVG, CSS, and Web Animations.

| UI category | Retrieved component | Adaptation |
| --- | --- | --- |
| Navigation | [Animated Sidebar by starc007](https://21st.dev/@starc007/components/animated-sidebar), demo 29334 | Desktop collapsed rail, animated labels, keyboard shortcut, mobile sheet, focus trap, Escape and focus restoration. |
| Dialogs | [Animated Dialog by rmahammad](https://21st.dev/@rmahammad/components/animated-dialog), demo 26905 | Native modal dialog with scale/slide animation, fixed header/footer, scrollable body, mobile bottom sheet and reduced motion. |
| Profile cards | [Animated Profile Card by ravikatiyar162](https://21st.dev/@ravikatiyar162/components/animated-profile-card), demo 8206 | Cover band, offset account identity, name/app line, configuration metadata, subtle hover lift and full-width action. Human profile data and photographs replaced by actual launcher identities. |
| Tabs | [Animated Tabs by educalvolpz](https://21st.dev/@educalvolpz/components/animated-tabs), demo 24930 | Sliding underline measured from the active tab, Arrow/Home/End navigation and roving keyboard focus. |
| Inputs/search | [Input by Origin UI](https://21st.dev/@originui/components/input), demo 159 | Leading search icon, trailing clear action, focus ring, input sizing and accessible labels. |
| Buttons | [Button by Origin UI](https://21st.dev/@originui/components/button), demo 146 | Primary, outline, secondary and destructive variants with a loading overlay that preserves button size. |
| Loading | [Button Spinner by uiable](https://21st.dev/@uiable/components/uiable-spinner-button), demo 19975 | CSS border spinner inside pending actions with visible text and `aria-busy`. |
| Notifications | [Toast by cnippet-dev](https://21st.dev/@cnippet-dev/components/toast), demo 24297 | Stacked status notifications, entrance/exit transitions, hover pause, timed dismissal, dismiss and activity actions. |
| Explore tunnel | [Perspective Tunnel Hero by daiwiikharihar](https://21st.dev/@daiwiikharihar/components/perspective-tunnel-hero), demo 39043 | See `experience.js` and `experience.css` for the scroll-driven visual adaptation. |
| Explore wheel | [Works Wheel by crafterui](https://21st.dev/@crafterui/components/works-wheel), demo 28371 | See `experience.js` and `experience.css` for the profile wheel adaptation. |

The workspace uses a warm near-black ground and actual account badge colors.
Placement, sizing and motion were refined using the
[Apple design skill](https://github.com/dickwu/apple-design-skill), particularly
Apple's [Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
and [Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
guidance. That skill is a design reference, not a build or runtime dependency.

Controls use a short sampled spring; panels use a softer spring. The Explore
camera and wheel use time-based damped springs that retain velocity when gestures
change direction, and stop requesting frames at rest. These spring parameters
are design choices rather than Apple-prescribed values. Reduced motion replaces
the spatial scenes with static, keyboard-accessible content.
