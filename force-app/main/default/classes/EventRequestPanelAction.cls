global with sharing class EventRequestPanelAction {
    @InvocableMethod(
        label='Show Event Request Panel'
        description='Displays an Agentforce LWC panel that collects event-search inputs and calls the events API after the user clicks Request.'
    )
    global static List<EventRequestPanelActionResponse> showPanel(List<EventRequestPanelActionRequest> requests) {
        List<EventRequestPanelActionResponse> responses = new List<EventRequestPanelActionResponse>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<EventRequestPanelActionRequest>{
                new EventRequestPanelActionRequest()
            };
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
