# Onboarding slice spec (sp/onboarding)

Refs: docs/design/references/onboarding/01-20.png (Gummble Duolingo iOS flow e6ac09f7…).

## Architecture
- domain/onboarding_content.dart — copy/option models (PromptSegment with bold/accent emphasis, `{language}` placeholder).
- data/onboarding_content_repository.dart — abstract `OnboardingContentRepository` + `MockOnboardingContentRepository` (copy transcribed from refs).
- application/onboarding_controller.dart — `onboardingContentRepositoryProvider`, `onboardingContentProvider` (override to swap API).
- presentation/widgets/ — onboarding_motion.dart, onboarding_parts.dart, onboarding_palette.dart.

## Colors (pixel-sampled, 1180px refs)
checkBlue #1DB2FB (10.png 950-1080,800-900), barFilled #1B9AD7 (08.png 100-190,1220-1300),
barEmpty #D4EBFB (08.png 100-190,790-880), barEmptySelected #BBE3FA (08.png 100-190,1000-1090),
sheet #FAF7FB / allow #33ACE7 / arrow #7CD1FC (14.png).

## Motion (all collapse to static under MediaQuery.disableAnimations)
- Primary button 3D press-down: 4px drop, 100ms easeOutCubic (shared ReferenceButton).
- Progress bar fill: TweenAnimationBuilder 220ms easeOutCubic (shared FlowHeader).
- Page transition: AnimatedSwitcher 300ms, slide 35% + fade; direction follows forward/back.
- Option select bounce: scale 1→0.94→1.03→1 over 260ms.
- Mascot bubble pop: scale 0.6→1 + fade, 320ms easeOutBack, 120ms delay on intro screens; re-pops when the prompt text changes.
- Mascot/illustration pop: 420ms easeOutBack; benefits rows stagger 80ms; notification arrow pops 160ms late.
- Collapse chevron rotates 200ms.

## Known deltas (minor)
- Goldens render at 430 logical px 1:1; refs are 390pt scaled ×1.1, so type looks ~10% smaller side-by-side.
- No iOS status bar in goldens.
