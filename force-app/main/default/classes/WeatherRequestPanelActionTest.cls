@isTest
public class WeatherRequestPanelActionTest {
    @isTest
    static void showPanelReturnsDefaultStateForSingleRequest() {
        WeatherRequestPanelActionRequest req = new WeatherRequestPanelActionRequest();
        req.userMessage = 'Tell me about the weather';

        List<WeatherRequestPanelActionResponse> responses = WeatherRequestPanelAction.showPanel(
            new List<WeatherRequestPanelActionRequest>{ req }
        );

        System.assertEquals(1, responses.size(), 'Should return one response per request');
        WeatherPanelState state = responses[0].panel;
        System.assertNotEquals(null, state, 'Panel state should not be null');
        System.assertEquals('Resort Weather', state.title);
        System.assertEquals(String.valueOf(Date.today()), state.defaultDate, 'Default date should be today (ISO)');
        System.assertEquals(3, state.locationOptions.size(), 'Should expose three resort options');
        System.assertEquals(true, state.locationOptions[0].checked, 'First option should be checked');
        System.assertEquals(state.locationOptions[0].value, state.defaultLocation, 'Default location matches first option');
    }

    @isTest
    static void showPanelHandlesNullAndEmptyInputs() {
        List<WeatherRequestPanelActionResponse> fromNull = WeatherRequestPanelAction.showPanel(null);
        System.assertEquals(1, fromNull.size(), 'Null input should still produce one response');
        System.assertNotEquals(null, fromNull[0].panel, 'Null input should still produce a panel');

        List<WeatherRequestPanelActionResponse> fromEmpty = WeatherRequestPanelAction.showPanel(
            new List<WeatherRequestPanelActionRequest>()
        );
        System.assertEquals(1, fromEmpty.size(), 'Empty input should still produce one response');
        System.assertNotEquals(null, fromEmpty[0].panel, 'Empty input should still produce a panel');
    }
}
