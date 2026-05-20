# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project type

Salesforce DX project (API version 66.0) containing a sample Agentforce agent (`Local_Info_Agent`) plus a planned LWC + Apex extension for in-chat interactive panels. All deployable metadata lives under `force-app/main/default/`. The default package directory is declared in `sfdx-project.json`.

## Common commands

Salesforce CLI (`sf`) drives all org interactions. Replace `<alias>` with your authorized org alias (e.g. `my-de-org`, `AgentScratchOrg`).

```bash
# Authorize / list orgs
sf org login web --alias <alias> --set-default
sf org list

# Create an Agentforce-ready scratch org
sf org create scratch --definition-file config/project-scratch-def.json --alias AgentScratchOrg --set-default --target-dev-hub DevHub

# Deploy / retrieve source
sf project deploy start --source-dir force-app
sf project deploy start --manifest manifest/package.xml
sf project retrieve start --source-dir force-app

# Deploy a single component (faster iteration)
sf project deploy start --source-dir force-app/main/default/classes/CheckWeather.cls

# Run Apex tests
sf apex run test --result-format human --code-coverage --wait 10
sf apex run test --tests CurrentDateTest --result-format human --wait 10
sf apex run test --class-names WeatherServiceTest --result-format human --wait 10

# Assign permission set groups (after deploy) so the agent user / dev user can run the agent
sf org assign permset --name AFDX_Agent_Perms
sf org assign permset --name AFDX_User_Perms
```

Formatting (Prettier with Apex + XML plugins):

```bash
npm install                  # one-time
npm run prettier             # write
npm run prettier:verify      # check only
```

The agent can be previewed in VS Code via the **AFDX: Preview This Agent** command on `force-app/main/default/aiAuthoringBundles/Local_Info_Agent/Local_Info_Agent.agent`. "Simulated mode" mocks tool responses; "live mode" requires the Apex/flow/prompt template to be deployed first.

## Architecture

### Agent Script as source of truth

`Local_Info_Agent.agent` (an `AiAuthoringBundle` metadata type, *not* the legacy `Bot` metadata) is the agent's blueprint. It's a DSL file, not XML — top-level sections define `system`, `config`, `variables`, `language`, the entry `start_agent`, and one `subagent` per skill. Editing this file is how you change the agent's behavior.

Key constructs to understand before editing the `.agent` file:

- **Subagent routing**: `start_agent agent_router` dispatches to subagents via `@utils.transition to @subagent.<name>`. Add a new subagent by adding both a router action and a `subagent <name>:` block.
- **Tool bindings**: Each subagent's `actions:` block declares tools. Each tool has a `target:` URI scheme that determines its backing implementation:
  - `apex://ClassName` → an Apex class with `@InvocableMethod` (e.g. `CheckWeather`).
  - `prompt://Template_Name` → a `genAiPromptTemplate` (e.g. `Get_Event_Info`).
  - `flow://Flow_Name` → an autolaunched Flow (e.g. `Get_Resort_Hours`).
  - `@utils.transition`, `@utils.setVariables`, `@utils.escalate` → built-in agent runtime helpers.
- **Mutable variables**: Declared in the top-level `variables:` block (`guest_interests`, `reservation_required`). Mutated inside subagent reasoning via `set @variables.x = @outputs.y` after a tool call, then read in another subagent via `if @variables.x:` deterministic branches or `available when` guards on tool calls.
- **Input/output schemas**: Each `actions:` definition declares typed `inputs:` and `outputs:` that must match the @InvocableVariable / Flow / Prompt Template signature. If you change the Apex signature, update the `.agent` file's schema or the action will fail validation at deploy/preview time.

### Tool implementations

The current agent uses three tool styles, one of each kind:

- **Invocable Apex** — `classes/CheckWeather.cls` (delegates to `WeatherService.cls`, which returns mocked data). The `WeatherRequest`/`WeatherResponse` inner classes define the schema exposed to the agent via `@InvocableVariable`. `CurrentDate.cls` is a second Apex tool intended for use as grounding for the `Get_Event_Info` prompt template.
- **Prompt template** — `genAiPromptTemplates/Get_Event_Info.genAiPromptTemplate-meta.xml`.
- **Flow** — `flows/Get_Resort_Hours.flow-meta.xml`.

### Permission sets

`Resort_Agent` (agent runtime user) and `Resort_Admin` (developer Apex access) are bundled into `AFDX_Agent_Perms` and `AFDX_User_Perms` permission set groups. Assign these after deploying — the agent cannot run without them.

### Planned feature: in-chat interactive panel (Event Request Panel)

`agentforce_lwc_apex_instructions.md` is a detailed spec for a new feature that is **not yet implemented**. It describes a self-contained Agentforce output renderer LWC that owns its own `form` / `loading` / `success` / `error` states, with the external API call happening only on user click, not during the agent action. The expected file layout is:

- `force-app/main/default/classes/Event*` — DTOs (`EventPanelState`, `EventOption`, `EventSearchRequest`, `EventSearchResponse`, `EventItem`), the invocable action (`EventRequestPanelAction`), the LWC controller (`EventApiController`), and the HTTP service (`EventApiService`).
- `force-app/main/default/lwc/eventRequestPanel/` — the LWC with `lightning__AgentforceOutput` target.
- `force-app/main/default/lightningTypes/eventRequestPanelType/` — `schema.json` plus `lightningDesktopGenAi/renderer.json` and `enhancedWebChat/renderer.json`.

If asked to implement any "Event Request Panel" / "show panel" / "events API" / `Events_API` Named Credential work, follow that spec — it has specific conventions:

- DTO classes referenced by `schema.json` or Agentforce must be top-level `global` classes (no nested classes) with `@AuraEnabled` fields and `@JsonAccess(serializable='always' deserializable='always')`.
- External endpoints must use the `Events_API` Named Credential (`callout:Events_API/...`) — never hardcode URLs, keys, or tokens.
- Deployment ordering for LWCs that reference a custom Lightning type: deploy LWC without `<targetConfigs>` → deploy `LightningTypeBundle` → re-add `<targetConfigs>` → redeploy LWC.

## Conventions

- Prettier is the formatter; `.prettierrc` declares Apex + XML plugins and `trailingComma: "none"`. Run before committing Apex/XML edits.
- `.forceignore` excludes `package.xml`, LWC `jsconfig.json`/`.eslintrc.json`, and `**/__tests__/**` from `sf` push/pull — keep test files outside the deployable set.
- `sourceApiVersion` in `sfdx-project.json` is `66.0`; the planned LWC spec suggests `64.0`+ for new LWC metadata files. New metadata should match or exceed the project's API version.
