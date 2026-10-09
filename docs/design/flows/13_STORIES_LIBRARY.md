# Stories library — English preview

Analyzed before implementation,2026-10-04. MCP refreshed flow
`bb0d8a5f-ea93-473d-b241-052b75dd92a1`; inspected
`sc_a86450f7f1dd43c8999180c514804d4a` and
`sc_66dde1d5f9fe43c1ab40fdd959dc870f` individually. Original hero: Good Morning,
cup illustration, review button, divider, Your library, two-column illustration
cards with bold centered wrapping titles. Scrolled variant pins Stories/Review.

Implement native hero/card library → selected title/entry → reading, true/false,
word and sentence questions → result → library. Preserve current story/input on
close; selecting a different title starts a distinct draft. Invalid IDs do not
silently replace the story. Existing A Big Family remains accessible.

Original card illustration ROIs cover What Do You Want?, I Want This Jacket!,
The New Student, This Is Not Art, I Really Want a Dog, A Ticket to New York.
Good Morning hero uses the original cup. No Math course is added. English mock
dialogues/exercises are authored because these library screenshots do not export
full story scripts. Do not represent them as exact official story content.

Family has verified speaker portraits; other scripts display named native speech
bubbles until their actual speaker portraits/rigs are obtained. Do not reuse Mom
and Melissa for Oscar/Eddy/Lily. Library thumbnails are original stills; no fake
thumbnail motion. Result uses the already verified original Duo timeline.

390-wide layout:16 outer padding, two native columns with flexible title heights,
original illustration viewports; scrollable at360/430 and text1/2. Native control
state, safe back and story independence require meaningful tests.

2026-10-05 verified continuation: closing/reopening the same story preserves its selected answer and draft; changing the story resets only that story session. Incorrect choice and word-bank order are graded. Story completion returns to the library. Native cover semantics expose one title/action, without duplicated child labels. The archived six-tab library navigation and every original story script/speaker rig remain open variants.
