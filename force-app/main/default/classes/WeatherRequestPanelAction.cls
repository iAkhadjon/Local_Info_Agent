global with sharing class WeatherRequestPanelAction {
    @InvocableMethod(
        label='Show Weather Request Panel'
        description='Displays an Agentforce LWC panel that lets the guest pick a date and resort location, then calls the weather API after the user clicks Request.'
    )
    global static List<WeatherRequestPanelActionResponse> showPanel(List<WeatherRequestPanelActionRequest> requests) {
        List<WeatherRequestPanelActionResponse> responses = new List<WeatherRequestPanelActionResponse>();

        if (requests == null || requests.isEmpty()) {
            requests = new List<WeatherRequestPanelActionRequest>{
                new WeatherRequestPanelActionRequest()
            };
        }

        String today = String.valueOf(Date.today());

        for (WeatherRequestPanelActionRequest req : requests) {
            WeatherPanelState state = new WeatherPanelState();
            state.title = 'Resort Weather';
            state.prompt = 'Choose date and location from the dropdown.';
            state.defaultDate = today;
            state.locationOptions = buildDefaultLocationOptions();
            state.defaultLocation = state.locationOptions[0].value;

            WeatherRequestPanelActionResponse response = new WeatherRequestPanelActionResponse();
            response.panel = state;
            responses.add(response);
        }

        return responses;
    }

    private static List<WeatherLocationOption> buildDefaultLocationOptions() {
        List<WeatherLocationOption> options = new List<WeatherLocationOption>();

        WeatherLocationOption mountain = new WeatherLocationOption();
        mountain.label = 'Mountain Resort';
        mountain.value = 'mountain';
        mountain.checked = true;
        options.add(mountain);

        WeatherLocationOption beach = new WeatherLocationOption();
        beach.label = 'Beach Resort';
        beach.value = 'beach';
        beach.checked = false;
        options.add(beach);

        WeatherLocationOption city = new WeatherLocationOption();
        city.label = 'City Resort';
        city.value = 'city';
        city.checked = false;
        options.add(city);

        return options;
    }
}
