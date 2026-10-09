# Approved repository tree

Historical target layout below is retained as design rationale; it is not the current disk tree. [Actual refresh manifest](../audit/DOCS_MANIFEST.md) and [input inventory](../audit/INPUT_INVENTORY.json) own observed paths. Existing mobile router is main.dart, design is core/design, domain folders are preserved; never regenerate to match this sample. Appwrite foundation scripts are in appwrite/, backend wire types in packages/api_contracts and shared transport in services/shared. Remaining full schema/domain/cloud integration is phase-gated.

Phase0 exists now: all docs below, root/nested instructions, skills/reviewer definitions, hooks/validators, PR/MCP/environment examples. Application/backend/build/content paths below are **approved future paths**, created in their assigned phase; no empty placeholder application code, fake successful pipeline, or unused layer was generated. [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) owns timing. Generated SDK platform files follow pinned flutter create; the tree fixes ownership/modules rather than listing every generated Gradle/Xcode file.

~~~text
CocEnglish/
  README.md
  AGENTS.md
  CLAUDE.md
  package.json                         [P1: pnpm workspace scripts only]
  pnpm-workspace.yaml / pnpm-lock.yaml  [P1: services + infrastructure packages]
  .gitignore                           [P1: secrets, builds, caches, private exports]
  .mcp.example.json
  .codex/config.example.toml
  .agents/skills/
    coc-flutter-feature/SKILL.md
    coc-service-change/SKILL.md
    coc-ai-provider/SKILL.md
    gummble-ui-research/SKILL.md
  .claude/
    settings.json
    agents/architecture-reviewer.md
    agents/design-qa.md
    skills/{same-four-names}/SKILL.md   [discovery wrappers; no copied procedures]
  .github/
    pull_request_template.md
    workflows/                        [P1: checks/android/ios; P11: artifacts]
  apps/mobile/
    AGENTS.md
    pubspec.yaml / pubspec.lock        [P1]
    android/ / ios/                    [P1: generated Flutter platforms]
    assets/{intro,audio,images,fonts}/  [P2/P4/P7: generated from owned content]
    lib/
      main.dart
      app/{bootstrap,router,config}.dart
      l10n/                           [vi/en localization source/generated output]
      design_system/{tokens,theme,components,motion}/
      core/
        api/{client,generated,mappers}/
        auth/                         [SDK session/JWT boundary]
        cache/{database,journal,bundles,assets}/
        content/                      [hash/signature/canonical-byte verifier]
        audio/                        [capture/playback/focus/PCM native bridge]
        telemetry/
      features/
        onboarding/
        auth/
        learning_path/
        lesson/
        practice/
        listening/
        speaking/
        quests/
        social/
        profile/
        settings/
        # Each: presentation/{views,controllers}; data/{repositories,mappers}
        # domain/ only for complex reducers/rules; no compulsory empty layer
    test/{unit,widgets,goldens,repositories}/
    integration_test/
  services/
    learning/
      AGENTS.md
      package.json / tsconfig.json
      src/{handler,cloud,local}.ts
      src/{content,enrollment,grading,sessions,review,events}/
      test/{unit,contract,integration}/
    progress/
      AGENTS.md
      package.json / tsconfig.json
      src/{handler,cloud,local}.ts
      src/{profile,rewards,streak,wallet,achievement,social,quests,leagues,events}/
      test/{unit,contract,integration}/
    ai/
      AGENTS.md
      package.json / tsconfig.json
      src/{handler,cloud,local}.ts
      src/{capabilities,live,reservations,adapters,assessment,tutor,turn,events}/
      test/{unit,contract,integration}/
  packages/                           [P1]
    backend-core/src/{auth,errors,transaction,logging,storage,signing}.ts
    api-types/                        [schema-derived TS wire types; no domain rules]
  content/                            [P4/P7: author-owned source, not user data]
    vi_en/{course,units,lessons,placement}/
    audio/                            [versioned approved generated/listening assets]
  infrastructure/
    .env.example
    toolchain.json                    [P1: actual SDK/runtime/JDK/Xcode identities]
    appwrite/{schema,permissions,functions}/
    migrations/                       [expand/backfill receipts; no destructive reset]
    demo/                             [local TLS/supervisor/schedule configuration]
  tools/
    agent/hooks.mjs
    blueprint/{validate,validate-schemas}.mjs
    contracts/                        [P1: wire fixtures/types; no second API spec]
    content/                          [P4/P7: validation/signing/audio asset tooling]
    scripts/{migrate,seed,deploy,export,restore,demo}.mjs
    fixtures/{api,grading,events,ai}/   [cross-language behavior cases]
    load/                             [P10: k6 smoke/spike/soak scripts]
  docs/
    00_READ_ME_FIRST.md
    ARCHITECTURE_BLUEPRINT_V1.md
    ASSUMPTIONS.md
    FREEZE_REVIEW.md
    research/{DOCUMENTATION_AUDIT,RESEARCH_EVIDENCE,AI_EVIDENCE}.md
    product/{SRS,FEATURE_MATRIX,USER_FLOWS,SCREEN_INVENTORY,EDGE_CASE_MATRIX}.md
    design/{DESIGN,COMPONENT_STATES,GUMMBLE_RESEARCH}.md
    architecture/{ARCHITECTURE,STACK,SERVICE_CATALOG,NFR,OFFLINE}.md
    architecture/adr/README.md + 0001–0017 decision records
    data/{DATA_MODEL,PERMISSIONS,MIGRATIONS}.md
    api/{openapi.yaml,AUTH.md,EVENTS_ERRORS.md}
    ai/{AI_ARCHITECTURE,AI_EVALS}.md
    devops/{CI_CD,OPERATIONS,COST_MODEL}.md
    quality/{TEST_STRATEGY,TRACEABILITY}.md
    agent/{AGENT_SYSTEM,IMPLEMENTATION_PLAN,DEPENDENCY_DAG,TASK_PROTOCOL,REPOSITORY_TREE}.md
~~~

apps/mobile owns all product UI and native capture/playback bridge. Services are separately built/deployed; shared backend-core contains infrastructure plumbing only, never shared course/reward rules. api-types is generated from docs/api/openapi.yaml; Dart DTO serializers and contract fixture tests use the same schema. No shared cross-language domain package, second frontend, gateway, Redis, broker, Kubernetes or web admin.

content is the author source; mobile intro files are built copies with source hash, never separately edited. infrastructure declares admitted resources/security/migrations; tools implements checked commands. docs owns frozen specifications and phase evidence. Reviewer/skill configuration stays in agent folders; actual account secret material and private exports remain outside Git. Future package/lock/workflow files become concrete in P1 rather than claiming compatibility before resolution/build.
