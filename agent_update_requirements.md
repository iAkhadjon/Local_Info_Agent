# Local Info Agent — Weather Panel UI Upgrade

## Context

Today the `local_weather` subagent in `force-app/main/default/aiAuthoringBundles/Local_Info_Agent/Local_Info_Agent.agent` (lines 93–152) calls `apex://CheckWeather` directly, passing only a date. There is no location concept and no interactive UI — the user types a date in chat and gets text back.

We want a richer experience: when the user asks anything weather-related, the agent should immediately render an LWC panel inside the chat that asks them to pick a **date** and **location** from dropdowns. On submit, the LWC calls a real weather API via a Named Credential and renders the result in its own success/error state.

The Event Request Panel feature (already implemented for `event_search_panel`) is the working template — same state machine pattern, same Apex + LightningType + LWC layout. This plan clones that pattern for weather.

Decisions captured up-front:
- **Locations** — hardcoded resort list in Apex.
- **CheckWeather** — kept in place; the agent routes the panel flow as the new default, CheckWeather remains as a fallback.
- **Backend** — wire to a real `Weather_API` Named Credential (parallel to `Events_API`).
- **Trigger style** — agent renders the panel immediately; the in-panel prompt itself reads "Choose date and location from the dropdown."

## Files to create

### Apex DTOs — `force-app/main/default/classes/`

All DTOs follow the convention from `agentforce_lwc_apex_instructions.md` §6.1: top-level `global` classes, `@JsonAccess(serializable='always' deserializable='always')`, `@AuraEnabled` on every field.

1. **`WeatherPanelState.cls`** — the state object Agentforce hands to the LWC.
   - `String title`
   - `String prompt` ("Choose date and location from the dropdown")
   - `String defaultDate` (ISO `yyyy-MM-dd`, today)
   - `String defaultLocation`
   - `List<WeatherLocationOption> locationOptions`

2. **`WeatherLocationOption.cls`**
   - `String label`
   - `String value`
   - `Boolean checked`

3. **`WeatherSearchRequest.cls`** — sent from LWC to controller.
   - `String location`
   - `String weatherDate` (ISO `yyyy-MM-dd`)

4. **`WeatherSearchResponse.cls`** — returned by controller, rendered in LWC success state.
   - `Boolean success`
   - `String message`
   - `Integer statusCode`
   - `String requestId`
   - `String location`
   - `String weatherDate`
   - `Decimal minTemperatureC`
   - `Decimal maxTemperatureC`
   - `Decimal minTemperatureF`
   - `Decimal maxTemperatureF`
   - `String description`

### Apex invocable action (called by the agent)

5. **`WeatherRequestPanelActionRequest.cls`** — single `@InvocableVariable String userMessage` (optional). Mirrors `EventRequestPanelActionRequest`.

6. **`WeatherRequestPanelActionResponse.cls`** — single `@InvocableVariable WeatherPanelState panel`. Mirrors `EventRequestPanelActionResponse`.

7. **`WeatherRequestPanelAction.cls`** — `@InvocableMethod` `showPanel(List<WeatherRequestPanelActionRequest>)`. Returns one response per request, each populated with:
   - Default date = `Date.today()` formatted ISO
   - Hardcoded location options (3 resorts, e.g. `Mountain Resort`, `Beach Resort`, `City Resort`), first one `checked = true`
   - Title + prompt strings
   - **Does not** call any external API — pure panel-state factory, identical pattern to `EventRequestPanelAction.cls`.

### Apex LWC controller (called by LWC imperatively)

8. **`WeatherApiController.cls`** — `@AuraEnabled public static WeatherSearchResponse getWeather(WeatherSearchRequest request)`.
   - Server-side re-validation: `request != null`, `location` non-blank, `weatherDate` non-blank.
   - Delegates to `WeatherService.getWeatherByLocation(request)`.
   - Catches `AuraHandledException` (re-throws) and generic `Exception` (logs at `LoggingLevel.ERROR`, throws a user-safe `AuraHandledException`).
   - Same shape as `EventApiController.searchUpcomingEvents`.

### LWC — `force-app/main/default/lwc/weatherRequestPanel/`

9. **`weatherRequestPanel.js-meta.xml`**
   - `apiVersion` 63.0+ (match existing LWC files)
   - `isExposed = true`
   - Target: `lightning__AgentforceOutput`
   - `targetConfig` `sourceType` = `c__weatherRequestPanelType` (added **after** the LightningType is deployed — see deployment order below)

10. **`weatherRequestPanel.js`** — clone of `eventRequestPanel.js` with these substitutions:
    - `@api value` receives `WeatherPanelState`
    - `connectedCallback` reads `defaultDate`, `defaultLocation`, `locationOptions` into tracked state
    - Form state holds `location` and `weatherDate` only
    - `handleRequest()` validates, sets `isLoading = true`, calls imported `getWeather` from `@salesforce/apex/WeatherApiController.getWeather`, populates `result` on success or `errorMessage` on failure
    - `handleRetry()` / `handleNewSearch()` mirror the event panel
    - **No** `simulatedDelayMs` / `forceError` test controls (those were temporary for the event panel; we don't repeat them here)

11. **`weatherRequestPanel.html`** — three sections:
    - **Form** (`showForm`): `lightning-combobox` for location (options from `locationOptions`), `lightning-input type="date"` for date, validation message, error message + Retry button, Request button.
    - **Loading** (`isLoading`): `lightning-spinner` + "Fetching weather…".
    - **Results** (`showResults`): card showing location, date, min/max temperatures (°C and °F), description, plus a "New search" button.

12. **`weatherRequestPanel.css`** — copy `eventRequestPanel.css` layout classes, rename `erp-*` → `wrp-*` (or keep shared class names if preferred; the event panel CSS is self-contained so cloning is cleanest).

### Lightning Type bundle — `force-app/main/default/lightningTypes/weatherRequestPanelType/`

13. **`schema.json`**
    ```json
    {
      "title": "Weather Request Panel",
      "description": "Interactive panel for picking date and location and showing weather API results.",
      "lightning:type": "@apexClassType/c__WeatherPanelState"
    }
    ```

14. **`lightningDesktopGenAi/renderer.json`** — `definition: "c/weatherRequestPanel"`.

15. **`enhancedWebChat/renderer.json`** — same content.

### Tests

16. **`WeatherRequestPanelActionTest.cls`** — two methods mirroring `EventRequestPanelActionTest`:
    - `showPanelReturnsDefaultStateForSingleRequest` — assert title, default date is today, location options length, first option `checked`.
    - `showPanelHandlesNullAndEmptyInputs` — null and empty input lists both produce safe defaults.

17. **`WeatherApiControllerTest.cls`** — four methods mirroring `EventApiControllerTest`:
    - Successful path returns populated `WeatherSearchResponse`.
    - Blank location throws `AuraHandledException`.
    - Blank weatherDate throws `AuraHandledException`.
    - Null request throws `AuraHandledException`.

## Files to modify

### `force-app/main/default/classes/WeatherService.cls`

Add a new method:
```apex
public static WeatherSearchResponse getWeatherByLocation(WeatherSearchRequest request)
```

This method:
- Builds a `callout:Weather_API/...` HTTP request (real API call via Named Credential, no hardcoded URL or key — same convention as the `Events_API` callout described in `agentforce_lwc_apex_instructions.md` §10).
- Maps the HTTP response into a `WeatherSearchResponse`.
- On non-2xx or parse failure, returns a response with `success = false`, `statusCode`, and `message`.

Keep the existing `getResortWeather(Datetime)` signature in place so `CheckWeather.cls` continues to compile and the fallback Apex action still works.

### `force-app/main/default/aiAuthoringBundles/Local_Info_Agent/Local_Info_Agent.agent`

- Update the `local_weather` subagent block (around lines 93–152):
  - Replace the `check_weather` action binding with a new `show_weather_panel` action whose `target:` is `apex://WeatherRequestPanelAction`.
  - Input: optional `userMessage` (string).
  - Output: `panel` typed as `@apexClassType/c__WeatherPanelState`, displayable, rendered by `weatherRequestPanelType` (mirrors the `event_search_panel` subagent's `panel` output, lines ~228–280).
  - Reasoning instructions: when the user asks about weather, immediately call `show_weather_panel` — do not ask follow-up questions in chat first.
- Keep the `check_weather` action **available but not the default** — add it as a secondary action the subagent may invoke if the panel cannot render (or move it to its own subagent reachable only via explicit fallback). Lowest-friction option: leave the existing `check_weather` action declared in the subagent and instruct the model in the subagent prompt to prefer `show_weather_panel` unless the panel action returns an error.

### Named Credential (org-side, not metadata in this repo)

A `Weather_API` Named Credential must exist in the target org before the panel can return live results:
- Type: Named Credential pointing at the third-party weather API host.
- Auth: per provider (API key header or OAuth).
- Endpoint usage: `callout:Weather_API/<provider-specific-path>`.

If a credential file is added to this repo later, it lives at `force-app/main/default/namedCredentials/Weather_API.namedCredential-meta.xml`. Out of scope for this plan unless you want to script the credential creation too.

## Deployment order

Per `agentforce_lwc_apex_instructions.md` §15 — LightningTypes and LWCs with custom `sourceType` need staged deploys:

1. Deploy Apex first: `sf project deploy start --source-dir force-app/main/default/classes` (DTOs, action, controller, service changes, tests).
2. Deploy the LWC **without** the `<targetConfigs>` `sourceType` line: `sf project deploy start --source-dir force-app/main/default/lwc/weatherRequestPanel`.
3. Deploy the LightningTypeBundle: `sf project deploy start --source-dir force-app/main/default/lightningTypes/weatherRequestPanelType`.
4. Re-add `<sourceType name="c__weatherRequestPanelType"/>` to `weatherRequestPanel.js-meta.xml` and redeploy the LWC.
5. Deploy the agent script: `sf project deploy start --source-dir force-app/main/default/aiAuthoringBundles/Local_Info_Agent`.
6. Assign perm-set groups if not already: `sf org assign permset --name AFDX_Agent_Perms` and `sf org assign permset --name AFDX_User_Perms`.

## Verification

**Apex tests** (each runs against the local source after step 1 above):
```bash
sf apex run test --tests WeatherRequestPanelActionTest --result-format human --wait 10
sf apex run test --tests WeatherApiControllerTest --result-format human --wait 10
sf apex run test --tests WeatherServiceTest --result-format human --wait 10
```

**Agent preview** — VS Code: open `Local_Info_Agent.agent`, run **AFDX: Preview This Agent**.
- *Simulated mode* (before live deploy): type "tell me about the weather". Expect the agent to call `show_weather_panel` and the simulator to display the panel-state JSON.
- *Live mode* (after full deploy + permsets + Named Credential): same prompt. Expect the `weatherRequestPanel` LWC to render in chat with the date defaulted to today and the three resort options. Pick a location, change the date, click Request — expect spinner, then a results card with min/max temps in °C and °F.

**Negative paths to confirm in live mode:**
- Submit with location cleared → client-side validation message; no Apex call.
- Submit with a date in a format the date input prevents → blocked by input control.
- Force a Named Credential failure (e.g., disable the credential briefly) → results section replaced by error state with Retry; Retry re-issues the call.
- Confirm `CheckWeather` text fallback still works by directly invoking it from the agent debug console (or from a subagent prompt that routes around the panel).

## Critical reference files

- `agentforce_lwc_apex_instructions.md` — spec the implementation must conform to.
- `force-app/main/default/classes/EventRequestPanelAction.cls` — template for `WeatherRequestPanelAction`.
- `force-app/main/default/classes/EventApiController.cls` — template for `WeatherApiController`.
- `force-app/main/default/classes/EventApiService.cls` — template for the Named-Credential callout in `WeatherService.getWeatherByLocation`.
- `force-app/main/default/lwc/eventRequestPanel/` — template for the new LWC (form/loading/success/error state machine).
- `force-app/main/default/lightningTypes/eventRequestPanelType/` — template for the new LightningType bundle.
- `force-app/main/default/aiAuthoringBundles/Local_Info_Agent/Local_Info_Agent.agent` — both the existing `local_weather` block (to modify) and the existing `event_search_panel` block (the structural reference for the modification).
