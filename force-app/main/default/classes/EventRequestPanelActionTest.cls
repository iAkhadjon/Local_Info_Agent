@isTest
public class EventRequestPanelActionTest {
    @isTest
    static void showPanelReturnsDefaultStateForSingleRequest() {
        EventRequestPanelActionRequest req = new EventRequestPanelActionRequest();
        req.userMessage = 'Show me upcoming events';
        req.defaultSubject = 'Music';

        List<EventRequestPanelActionResponse> responses = EventRequestPanelAction.showPanel(
            new List<EventRequestPanelActionRequest>{ req }
        );

        System.assertEquals(1, responses.size(), 'Should return one response per request');
        EventPanelState state = responses[0].panel;
        System.assertNotEquals(null, state, 'Panel state should not be null');
        System.assertEquals('Event Search', state.title);
        System.assertEquals('Music', state.defaultSubject);
        System.assertEquals(2, state.options.size(), 'Should expose two default options');
        System.assertEquals('item1', state.options[0].value);
        System.assertEquals('item2', state.options[1].value);
    }

    @isTest
    static void showPanelHandlesNullAndEmptyInputs() {
        List<EventRequestPanelActionResponse> fromNull = EventRequestPanelAction.showPanel(null);
        System.assertEquals(1, fromNull.size(), 'Null input should still produce one response');

        List<EventRequestPanelActionResponse> fromEmpty = EventRequestPanelAction.showPanel(
            new List<EventRequestPanelActionRequest>()
        );
        System.assertEquals(1, fromEmpty.size(), 'Empty input should still produce one response');
    }
}
