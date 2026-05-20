# Agentforce LWC + Apex Third-Party API Request Panel - Codex Instructions

## 1. Goal

Build a Salesforce Agentforce solution where the agent displays an LWC inside the chat conversation. The LWC collects user input, shows its own loading state, calls Apex, and then displays success or failure results inside the LWC.

Example user request:

> Show me upcoming events.

Expected behavior:

1. Agent invokes a custom action that displays a request panel in the chat.
2. The panel contains inputs similar to the provided mockup:
   - Subject
   - Date
   - Range or other filter text
   - Radio buttons or checkboxes
   - Request, Submit, or OK button
3. The external API must not be called before the user clicks the button.
4. When the user clicks the button, the LWC shows a loading spinner and disables inputs.
5. Apex calls the third-party API.
6. When Apex returns, the LWC displays either:
   - Success state with returned event details
   - Failure state with a user-safe error message and a Retry option

## 2. Critical Architecture Decision

Implement the default solution as **one self-contained Agentforce output renderer LWC** that owns these UI states:

- `form`
- `loading`
- `success`
- `error`

Do not create a separate loading LWC unless there is a strong reuse requirement. Loading is a state of the request panel, not a separate business component.

### Why this architecture

The requirement says loading logic must be in LWC, not in the agent. If the Agentforce action itself performs the external API call, Agentforce controls the action execution period and the custom input LWC may not remain responsible for the loading UI after the chat submit happens.

Therefore, use this pattern:

```text
User asks agent -> Agentforce Apex action returns a panel model -> Custom Lightning Type renderer displays LWC -> User fills form -> LWC calls @AuraEnabled Apex -> Apex calls external API -> Same LWC displays result/error
```

The Agentforce invocable action is used to place the interactive panel in the conversation. The actual external API call happens only when the user clicks the button inside the LWC.

## 3. Salesforce Concepts To Use

Use these Salesforce capabilities:

1. **Apex invocable custom action for Agentforce**
   - Create an Apex class with `@InvocableMethod` so it can be selected as a custom action in Agentforce Builder.
   - This invocable action should return a simple panel state object.
   - It must not call the third-party API in the default implementation.

2. **Custom Lightning Type**
   - Create a LightningTypeBundle in `force-app/main/default/lightningTypes`.
   - Use an Apex-based custom Lightning type whose `schema.json` points to the panel state Apex class.
   - Add `renderer.json` so Agentforce renders the output using the custom LWC.

3. **Lightning Web Component**
   - The LWC target must include `lightning__AgentforceOutput`.
   - The component receives the panel model from the Agentforce action and then runs the interactive request flow.

4. **Apex controller for LWC**
   - Create an `@AuraEnabled` Apex method for the LWC to call imperatively.
   - This method calls a service class that performs the third-party API callout.

5. **Named Credential**
   - Do not hardcode endpoint base URLs, API keys, bearer tokens, usernames, passwords, or client secrets.
   - Use a Named Credential named `Events_API` unless the project already has a different approved name.
   - Apex endpoint format should be similar to `callout:Events_API/v1/events/search`.

## 4. Required User Flow

Implement exactly this flow unless an existing repo convention requires minor naming changes.

### Step 1 - Agent displays the panel

The user asks:

```text
What upcoming events are available?
```

The agent calls the custom action:

```text
Show Event Request Panel
```

The action returns `EventPanelState` as output.

Agentforce renders `EventPanelState` with the custom Lightning type and LWC.

### Step 2 - LWC displays the form

The LWC displays:

- Title: `Event Search`
- Input: `Subject`
- Input: `Date`
- Input: `Range`
- Radio group or checkbox group, for example:
  - `Item #1`
  - `Item #2`
- Primary button: `Request`

### Step 3 - LWC validates input

On Request click:

- Validate required fields.
- Display inline validation messages.
- Do not call Apex if validation fails.

Minimum validation:

- Subject is required.
- Date is required.
- One radio option is required if radio buttons are displayed.

### Step 4 - LWC shows loading

When validation passes:

- Set `isLoading = true`.
- Disable all form fields.
- Disable the button.
- Show `lightning-spinner` with accessible alternative text.
- Show a short message such as `Searching upcoming events...`.

### Step 5 - Apex calls third-party API

The LWC calls:

```javascript
searchUpcomingEvents({ request: requestPayload })
```

Apex performs the HTTP callout using the Named Credential.

### Step 6 - LWC shows success or failure

On success:

- Set `isLoading = false`.
- Render result cards or a compact table/list.
- Show an explicit success status.
- Include event title, date/time, location, summary, and URL if present in the response.

On failure:

- Set `isLoading = false`.
- Render an error state with a sanitized message.
- Include a Retry button.
- Do not expose stack traces, raw tokens, secrets, or full raw API responses to the user.

## 5. Required File Structure

Create or update files under the standard Salesforce DX structure.

```text
force-app/main/default/classes/
  EventPanelState.cls
  EventPanelState.cls-meta.xml
  EventOption.cls
  EventOption.cls-meta.xml
  EventSearchRequest.cls
  EventSearchRequest.cls-meta.xml
  EventSearchResponse.cls
  EventSearchResponse.cls-meta.xml
  EventItem.cls
  EventItem.cls-meta.xml
  EventRequestPanelActionRequest.cls
  EventRequestPanelActionRequest.cls-meta.xml
  EventRequestPanelActionResponse.cls
  EventRequestPanelActionResponse.cls-meta.xml
  EventRequestPanelAction.cls
  EventRequestPanelAction.cls-meta.xml
  EventApiController.cls
  EventApiController.cls-meta.xml
  EventApiService.cls
  EventApiService.cls-meta.xml
  EventApiServiceMock.cls
  EventApiServiceMock.cls-meta.xml
  EventRequestPanelActionTest.cls
  EventRequestPanelActionTest.cls-meta.xml
  EventApiControllerTest.cls
  EventApiControllerTest.cls-meta.xml

force-app/main/default/lwc/eventRequestPanel/
  eventRequestPanel.html
  eventRequestPanel.js
  eventRequestPanel.css
  eventRequestPanel.js-meta.xml
  __tests__/eventRequestPanel.test.js

force-app/main/default/lightningTypes/eventRequestPanelType/
  schema.json
  lightningDesktopGenAi/renderer.json
  enhancedWebChat/renderer.json

manifest/package.xml
```

If the repo has a different default package directory, adapt paths but keep the metadata types and naming consistent.

## 6. Apex Implementation Requirements

### 6.1 Data DTO classes

Create top-level Apex classes for custom Lightning Type compatibility. Do not use nested classes for any class referenced by `schema.json`.

Use `global` for DTO classes referenced by Agentforce or Lightning Types.

Use `@AuraEnabled` on all DTO fields that must be projected into a custom Lightning type or sent to/from LWC.

Use `@JsonAccess(serializable='always' deserializable='always')` on DTO classes that are referenced by Agentforce/Lightning Types or sent through the LWC/Apex boundary.

#### EventPanelState.cls

Purpose: the model returned by the Agentforce action to render the interactive panel.

Required fields:

```apex
@JsonAccess(serializable='always' deserializable='always')
global class EventPanelState {
    @AuraEnabled global String title;
    @AuraEnabled global String prompt;
    @AuraEnabled global String defaultSubject;
    @AuraEnabled global String defaultDate;
    @AuraEnabled global String defaultRange;
    @AuraEnabled global List<EventOption> options;
}
```

#### EventOption.cls

```apex
@JsonAccess(serializable='always' deserializable='always')
global class EventOption {
    @AuraEnabled global String label;
    @AuraEnabled global String value;
    @AuraEnabled global Boolean checked;
}
```

#### EventSearchRequest.cls

Purpose: payload from LWC to Apex.

```apex
@JsonAccess(serializable='always' deserializable='always')
global class EventSearchRequest {
    @AuraEnabled global String subject;
    @AuraEnabled global String eventDate;
    @AuraEnabled global String rangeValue;
    @AuraEnabled global String selectedOption;
}
```

Use `String eventDate` in ISO `yyyy-MM-dd` format to avoid client/server date serialization ambiguity.

#### EventItem.cls

Purpose: one item in the third-party API response.

Required fields:

```apex
@JsonAccess(serializable='always' deserializable='always')
global class EventItem {
    @AuraEnabled global String id;
    @AuraEnabled global String title;
    @AuraEnabled global String startDateTime;
    @AuraEnabled global String endDateTime;
    @AuraEnabled global String location;
    @AuraEnabled global String summary;
    @AuraEnabled global String url;
}
```

#### EventSearchResponse.cls

Purpose: response from Apex to LWC.

Required fields:

```apex
@JsonAccess(serializable='always' deserializable='always')
global class EventSearchResponse {
    @AuraEnabled global Boolean success;
    @AuraEnabled global String message;
    @AuraEnabled global Integer statusCode;
    @AuraEnabled global String requestId;
    @AuraEnabled global List<EventItem> events;
}
```

### 6.2 Agentforce invocable action

Create an action that returns the panel state. This action only displays the UI. It does not call the external API.

#### EventRequestPanelActionRequest.cls

```apex
global class EventRequestPanelActionRequest {
    @InvocableVariable(label='User Message' description='Original user request or prompt, if available' required=false)
    global String userMessage;

    @InvocableVariable(label='Default Subject' description='Optional subject inferred by the agent' required=false)
    global String defaultSubject;
}
```

#### EventRequestPanelActionResponse.cls

```apex
global class EventRequestPanelActionResponse {
    @InvocableVariable(label='Event Request Panel' description='Render this output with eventRequestPanelType')
    global EventPanelState panel;
}
```

#### EventRequestPanelAction.cls

Requirements:

- Class must use `with sharing`.
- Method must be `global static`.
- Method must be annotated with `@InvocableMethod`.
- It must support bulk input and return one response per request.
- It must populate sensible default options.

Expected shape:

```apex
global with sharing class EventRequestPanelAction {
    @InvocableMethod(
        label='Show Event Request Panel'
        description='Displays an Agentforce LWC panel that collects event-search inputs and calls the external events API after the user clicks Request.'
    )
    global static List<EventRequestPanelActionResponse> showPanel(List<EventRequestPanelActionRequest> requests) {
        List<EventRequestPanelActionResponse> responses = new List<EventRequestPanelActionResponse>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<EventRequestPanelActionRequest>{ new EventRequestPanelActionRequest() };
        }

        for (EventRequestPanelActionRequest req : requests) {
            EventPanelState state = new EventPanelState();
            state.title = 'Event Search';
            state.prompt = 'Fill in the details and click Request.';
            state.defaultSubject = req == null ? null : req.defaultSubject;
            state.defaultRange = null;
            state.options = new List<EventOption>();

            EventOption option1 = new EventOption();
            option1.label = 'Item #1';
            option1.value = 'item1';
            option1.checked = false;
            state.options.add(option1);

            EventOption option2 = new EventOption();
            option2.label = 'Item #2';
            option2.value = 'item2';
            option2.checked = true;
            state.options.add(option2);

            EventRequestPanelActionResponse response = new EventRequestPanelActionResponse();
            response.panel = state;
            responses.add(response);
        }

        return responses;
    }
}
```

### 6.3 LWC Apex controller

#### EventApiController.cls

Requirements:

- `with sharing`.
- Exposes exactly one public LWC method to start.
- Performs input validation again on the server side.
- Delegates external API logic to `EventApiService`.
- Throws `AuraHandledException` only with user-safe messages.

Expected shape:

```apex
public with sharing class EventApiController {
    @AuraEnabled
    public static EventSearchResponse searchUpcomingEvents(EventSearchRequest request) {
        if (request == null) {
            throw new AuraHandledException('Missing request details.');
        }
        if (String.isBlank(request.subject)) {
            throw new AuraHandledException('Subject is required.');
        }
        if (String.isBlank(request.eventDate)) {
            throw new AuraHandledException('Date is required.');
        }
        if (String.isBlank(request.selectedOption)) {
            throw new AuraHandledException('Please select an option.');
        }

        try {
            return EventApiService.searchUpcomingEvents(request);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Event API request failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve events right now. Please try again later.');
        }
    }
}
```

### 6.4 External API service

#### EventApiService.cls

Requirements:

- Use `HttpRequest`, `Http`, and `HttpResponse`.
- Use Named Credential endpoint `callout:Events_API`.
- Use `POST` unless the actual API contract requires `GET`.
- Set `Content-Type: application/json`.
- Set a timeout appropriate for the expected service latency.
- Treat all non-2xx status codes as failures.
- Parse the JSON response defensively.
- Never return raw secrets or stack traces to the LWC.

Expected shape:

```apex
public with sharing class EventApiService {
    private static final String ENDPOINT = 'callout:Events_API/v1/events/search';

    public static EventSearchResponse searchUpcomingEvents(EventSearchRequest request) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setEndpoint(ENDPOINT);
        httpRequest.setMethod('POST');
        httpRequest.setHeader('Content-Type', 'application/json');
        httpRequest.setTimeout(60000);

        Map<String, Object> body = new Map<String, Object>{
            'subject' => request.subject,
            'date' => request.eventDate,
            'range' => request.rangeValue,
            'selectedOption' => request.selectedOption
        };
        httpRequest.setBody(JSON.serialize(body));

        HttpResponse httpResponse = new Http().send(httpRequest);
        Integer statusCode = httpResponse.getStatusCode();
        String responseBody = httpResponse.getBody();

        if (statusCode < 200 || statusCode >= 300) {
            EventSearchResponse failed = new EventSearchResponse();
            failed.success = false;
            failed.statusCode = statusCode;
            failed.message = 'External service returned an error.';
            failed.events = new List<EventItem>();
            return failed;
        }

        return parseSuccessResponse(statusCode, responseBody);
    }

    @TestVisible
    private static EventSearchResponse parseSuccessResponse(Integer statusCode, String responseBody) {
        EventSearchResponse result = new EventSearchResponse();
        result.success = true;
        result.statusCode = statusCode;
        result.message = 'Events retrieved successfully.';
        result.events = new List<EventItem>();

        if (String.isBlank(responseBody)) {
            return result;
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        if (payload.containsKey('requestId')) {
            result.requestId = String.valueOf(payload.get('requestId'));
        }

        Object eventsObject = payload.get('events');
        if (eventsObject instanceof List<Object>) {
            for (Object row : (List<Object>) eventsObject) {
                if (!(row instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> eventMap = (Map<String, Object>) row;
                EventItem item = new EventItem();
                item.id = asString(eventMap.get('id'));
                item.title = asString(eventMap.get('title'));
                item.startDateTime = asString(eventMap.get('startDateTime'));
                item.endDateTime = asString(eventMap.get('endDateTime'));
                item.location = asString(eventMap.get('location'));
                item.summary = asString(eventMap.get('summary'));
                item.url = asString(eventMap.get('url'));
                result.events.add(item);
            }
        }

        return result;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}
```

Adapt field mappings to match the real third-party API contract.

## 7. LWC Implementation Requirements

### 7.1 eventRequestPanel.js-meta.xml

Use `lightning__AgentforceOutput`. Start with API version `64.0` or higher, based on the org/project version.

Suggested metadata:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>64.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>Event Request Panel</masterLabel>
    <targets>
        <target>lightning__AgentforceOutput</target>
    </targets>
    <targetConfigs>
        <targetConfig targets="lightning__AgentforceOutput">
            <sourceType name="c__eventRequestPanelType"></sourceType>
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

If deployment fails because the custom Lightning type is not deployed yet, use this deployment order:

1. Deploy the LWC without the `<targetConfigs>` block.
2. Deploy the LightningTypeBundle.
3. Re-add the `<targetConfigs>` block.
4. Redeploy the LWC.

### 7.2 eventRequestPanel.js

Requirements:

- Import Apex method from `@salesforce/apex/EventApiController.searchUpcomingEvents`.
- Use `@api value` to receive the panel state from Agentforce.
- Initialize defaults from `value`.
- Track form fields, loading state, response state, and error state.
- Use imperative Apex call only after button click.
- Never call Apex from `connectedCallback` unless explicitly required.
- Provide retry and reset behavior.

Expected shape:

```javascript
import { LightningElement, api, track } from 'lwc';
import searchUpcomingEvents from '@salesforce/apex/EventApiController.searchUpcomingEvents';

export default class EventRequestPanel extends LightningElement {
    @api value;

    @track events = [];
    @track errorMessage;

    subject = '';
    eventDate = '';
    rangeValue = '';
    selectedOption;
    isLoading = false;
    hasSearched = false;

    connectedCallback() {
        const state = this.value || {};
        this.subject = state.defaultSubject || '';
        this.eventDate = state.defaultDate || '';
        this.rangeValue = state.defaultRange || '';
        const checked = (state.options || []).find((option) => option.checked);
        this.selectedOption = checked ? checked.value : null;
    }

    get title() {
        return (this.value && this.value.title) || 'Event Search';
    }

    get prompt() {
        return (this.value && this.value.prompt) || 'Fill in the details and click Request.';
    }

    get radioOptions() {
        const options = (this.value && this.value.options) || [];
        return options.map((option) => ({ label: option.label, value: option.value }));
    }

    get showForm() {
        return !this.hasSearched || this.isLoading || this.errorMessage;
    }

    get showResults() {
        return this.hasSearched && !this.isLoading && !this.errorMessage;
    }

    get hasEvents() {
        return this.events && this.events.length > 0;
    }

    get isRequestDisabled() {
        return this.isLoading;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
    }

    handleDateChange(event) {
        this.eventDate = event.detail.value;
    }

    handleRangeChange(event) {
        this.rangeValue = event.detail.value;
    }

    handleOptionChange(event) {
        this.selectedOption = event.detail.value;
    }

    async handleRequest() {
        this.errorMessage = undefined;

        if (!this.validate()) {
            return;
        }

        this.isLoading = true;
        this.hasSearched = true;
        this.events = [];

        const request = {
            subject: this.subject,
            eventDate: this.eventDate,
            rangeValue: this.rangeValue,
            selectedOption: this.selectedOption
        };

        try {
            const response = await searchUpcomingEvents({ request });
            if (!response || response.success !== true) {
                this.errorMessage = response && response.message ? response.message : 'No events could be retrieved.';
                return;
            }
            this.events = response.events || [];
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRetry() {
        this.handleRequest();
    }

    handleNewSearch() {
        this.hasSearched = false;
        this.errorMessage = undefined;
        this.events = [];
    }

    validate() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-radio-group')];
        let valid = true;
        inputs.forEach((input) => {
            if (typeof input.reportValidity === 'function') {
                valid = input.reportValidity() && valid;
            }
        });
        return valid;
    }

    normalizeError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unexpected error. Please try again.';
    }
}
```

### 7.3 eventRequestPanel.html

Requirements:

- Use Lightning base components.
- Match the mockup layout closely but keep it responsive for chat width.
- Show form, loading, success, and error states in the same component.
- Use accessible labels.

Expected shape:

```html
<template>
    <article class="panel">
        <header class="panel__header">
            <h2>{title}</h2>
            <p>{prompt}</p>
        </header>

        <template if:true={showForm}>
            <lightning-input
                label="Subject"
                value={subject}
                onchange={handleSubjectChange}
                disabled={isLoading}
                required>
            </lightning-input>

            <lightning-input
                type="date"
                label="Date"
                value={eventDate}
                onchange={handleDateChange}
                disabled={isLoading}
                required>
            </lightning-input>

            <lightning-input
                label="Range"
                value={rangeValue}
                onchange={handleRangeChange}
                disabled={isLoading}>
            </lightning-input>

            <lightning-radio-group
                label="Options"
                options={radioOptions}
                value={selectedOption}
                onchange={handleOptionChange}
                disabled={isLoading}
                required>
            </lightning-radio-group>

            <div class="panel__actions">
                <lightning-button
                    variant="brand"
                    label="Request"
                    onclick={handleRequest}
                    disabled={isRequestDisabled}>
                </lightning-button>
            </div>
        </template>

        <template if:true={isLoading}>
            <div class="loading" role="status" aria-live="polite">
                <lightning-spinner alternative-text="Searching upcoming events" size="small"></lightning-spinner>
                <p>Searching upcoming events...</p>
            </div>
        </template>

        <template if:true={errorMessage}>
            <section class="state state_error" aria-live="assertive">
                <h3>Request failed</h3>
                <p>{errorMessage}</p>
                <lightning-button label="Retry" onclick={handleRetry}></lightning-button>
            </section>
        </template>

        <template if:true={showResults}>
            <section class="state state_success" aria-live="polite">
                <h3>Success</h3>

                <template if:true={hasEvents}>
                    <template for:each={events} for:item="eventItem">
                        <article key={eventItem.id} class="event-card">
                            <h4>{eventItem.title}</h4>
                            <p>{eventItem.startDateTime}</p>
                            <p>{eventItem.location}</p>
                            <p>{eventItem.summary}</p>
                            <template if:true={eventItem.url}>
                                <a href={eventItem.url} target="_blank" rel="noopener noreferrer">Open details</a>
                            </template>
                        </article>
                    </template>
                </template>

                <template if:false={hasEvents}>
                    <p>No events found.</p>
                </template>

                <lightning-button label="New Search" onclick={handleNewSearch}></lightning-button>
            </section>
        </template>
    </article>
</template>
```

### 7.4 eventRequestPanel.css

Requirements:

- Keep styles scoped and lightweight.
- Use SLDS-friendly spacing.
- Ensure the component fits narrow chat panels.

Example direction:

```css
.panel {
    border: 1px solid var(--slds-g-color-border-base-1, #d8dde6);
    border-radius: 0.5rem;
    padding: 1rem;
    background: var(--slds-g-color-neutral-base-100, #fff);
}

.panel__header h2 {
    font-size: 1rem;
    font-weight: 700;
    margin: 0 0 0.25rem 0;
}

.panel__actions {
    margin-top: 1rem;
    text-align: center;
}

.loading {
    margin-top: 1rem;
    min-height: 3rem;
    display: flex;
    align-items: center;
    gap: 0.75rem;
}

.state {
    margin-top: 1rem;
}

.state_error {
    border-left: 4px solid var(--slds-g-color-error-base-50, #ba0517);
    padding-left: 0.75rem;
}

.state_success {
    border-left: 4px solid var(--slds-g-color-success-base-50, #2e844a);
    padding-left: 0.75rem;
}

.event-card {
    border: 1px solid var(--slds-g-color-border-base-1, #d8dde6);
    border-radius: 0.375rem;
    padding: 0.75rem;
    margin: 0.75rem 0;
}
```

## 8. Custom Lightning Type Implementation

Create `force-app/main/default/lightningTypes/eventRequestPanelType`.

### 8.1 schema.json

```json
{
  "title": "Event Request Panel",
  "description": "Interactive panel for collecting event search inputs and showing event API results.",
  "lightning:type": "@apexClassType/c__EventPanelState"
}
```

### 8.2 lightningDesktopGenAi/renderer.json

```json
{
  "renderer": {
    "componentOverrides": {
      "$": {
        "definition": "c/eventRequestPanel"
      }
    }
  }
}
```

### 8.3 enhancedWebChat/renderer.json

Use the same content as `lightningDesktopGenAi/renderer.json` for predictable Enhanced Web Chat behavior.

```json
{
  "renderer": {
    "componentOverrides": {
      "$": {
        "definition": "c/eventRequestPanel"
      }
    }
  }
}
```

## 9. Agentforce Builder Setup Instructions

After deployment, configure the agent manually unless the repo already contains supported Agentforce metadata.

1. Go to Setup.
2. Open Agentforce Builder.
3. Create or open the target agent.
4. Create a custom action from Apex.
5. Select the invocable method:

```text
Show Event Request Panel
```

6. Add the action to the relevant topic, for example `Events` or `Event Search`.
7. Configure the action output:
   - Output field: `panel`
   - Output rendering: `eventRequestPanelType`
8. Save and activate or test the agent.
9. In the agent instructions, include wording similar to:

```text
When the user asks about upcoming events, event schedules, or event availability, call the Show Event Request Panel action. Do not call the third-party events API directly before the user fills out the form. The displayed LWC collects the required inputs, shows its own loading state, calls Apex, and displays the result or failure state.
```

10. Test in Agent Preview:

```text
Show me upcoming events.
```

Expected result: the custom LWC form appears in the chat.

## 10. Named Credential Setup

Create or confirm a Named Credential named:

```text
Events_API
```

Requirements:

- Base URL points to the third-party API host only, for example `https://api.example.com`.
- Authentication is configured through External Credential or the org-approved auth method.
- No secrets are committed to source control.
- Apex uses the `callout:Events_API` endpoint prefix.

If the org already has an approved Named Credential, use that name and update `EventApiService.ENDPOINT`.

## 11. Tests Required

### 11.1 Apex tests

Create tests with at least 85 percent coverage for new Apex classes.

Required test cases:

1. `EventRequestPanelActionTest`
   - Calls `showPanel` with one request.
   - Verifies one response is returned.
   - Verifies `panel.title`, `panel.prompt`, and `panel.options` are populated.

2. `EventApiControllerTest`
   - Uses `HttpCalloutMock` for success.
   - Verifies response `success = true` and events are parsed.
   - Uses `HttpCalloutMock` for non-2xx failure.
   - Verifies response `success = false` and user-safe error message.
   - Verifies missing required fields throw `AuraHandledException`.

3. `EventApiServiceMock`
   - Implement success, empty, malformed, and failure mock variants if practical.

Do not make real callouts in tests.

### 11.2 LWC Jest tests

Create Jest tests for:

1. Initial render displays form fields and Request button.
2. Clicking Request with missing required fields does not call Apex.
3. Clicking Request with valid input calls Apex and shows loading while the promise is pending.
4. Successful response displays success state and event cards.
5. Failed response displays error state and Retry button.
6. Retry calls Apex again.

Mock Apex import:

```javascript
jest.mock(
    '@salesforce/apex/EventApiController.searchUpcomingEvents',
    () => ({ default: jest.fn() }),
    { virtual: true }
);
```

## 12. Acceptance Criteria

The implementation is complete only when all criteria pass.

### Functional acceptance

- Agent displays the LWC panel in the conversation for an upcoming-events request.
- External API is not called until the user clicks Request.
- The loading spinner appears inside the LWC, not as an agent text response.
- Inputs are disabled while loading.
- Success result is displayed inside the LWC.
- Failure result is displayed inside the LWC.
- Retry works after failure.
- New Search works after success.

### Technical acceptance

- Apex compiles.
- LWC compiles.
- LightningTypeBundle deploys.
- Apex tests pass.
- Jest tests pass if the repo has Jest configured.
- No credentials are hardcoded.
- The code uses a Named Credential for the callout.
- The solution works in Agentforce Builder preview.

## 13. Optional Alternative: Native Agentforce Input and Output Pattern

Only use this alternative if the product owner accepts that custom loading during the agent-owned Apex call may be limited by the Agentforce runtime.

Alternative flow:

```text
Agent displays Agentforce input LWC -> User submits chat form -> Agentforce invokes Apex action -> Apex calls external API -> Agentforce displays output LWC
```

Files for this alternative:

```text
lwc/eventSearchInput/
  target: lightning__AgentforceInput

lwc/eventSearchResult/
  target: lightning__AgentforceOutput

lightningTypes/eventSearchRequestType/
  schema.json
  lightningDesktopGenAi/editor.json
  enhancedWebChat/editor.json

lightningTypes/eventSearchResponseType/
  schema.json
  lightningDesktopGenAi/renderer.json
  enhancedWebChat/renderer.json

classes/EventSearchAction.cls
```

In this alternative:

- The input LWC must dispatch `valuechange` as the user changes fields.
- The Apex invocable action performs the external API call.
- The result LWC renders `EventSearchResponse`.
- Loading is primarily controlled by Agentforce/chat runtime after the user submits the action.

Do not choose this alternative for the default implementation because the main requirement is LWC-controlled loading.

## 14. Do Not Do These Things

- Do not call the external API from the agent before the user clicks the LWC button.
- Do not put API loading logic in agent instructions.
- Do not create a separate loading component unless explicitly required.
- Do not hardcode API credentials or bearer tokens.
- Do not expose raw API errors to the user.
- Do not use nested Apex classes for classes referenced by custom Lightning Types.
- Do not skip server-side validation just because the LWC validates fields.
- Do not make real HTTP callouts in tests.

## 15. Deployment Notes

Suggested deploy command:

```bash
sf project deploy start --source-dir force-app/main/default --target-org <ORG_ALIAS> --wait 20
```

If Lightning Type and LWC cross-reference deployment fails:

1. Deploy Apex DTOs and LWC without sourceType target config.
2. Deploy `lightningTypes/eventRequestPanelType`.
3. Add sourceType target config back to LWC metadata.
4. Redeploy LWC.
5. Deploy or update Agentforce action configuration manually in Agentforce Builder.

## 16. Official References For Codex To Consult

- Agentforce custom actions using Apex InvocableMethod:
  - https://developer.salesforce.com/docs/ai/agentforce/guide/agent-invocablemethod.html
- Custom Lightning Types for Agentforce action UI:
  - https://developer.salesforce.com/docs/ai/agentforce/guide/lightning-types.html
- Apex-based Custom Lightning Types:
  - https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-apex.html
- Lightning Type UI configuration:
  - https://developer.salesforce.com/docs/platform/lightning-types/guide/lightning-types-ui-config.html
- LWC `lightning__AgentforceOutput` target:
  - https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-agentforce-output.html
- LWC `lightning__AgentforceInput` target, for the optional alternative:
  - https://developer.salesforce.com/docs/platform/lwc/guide/targets-lightning-agentforce-input.html
- Named Credentials as Apex callout endpoints:
  - https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_named_credentials.htm
