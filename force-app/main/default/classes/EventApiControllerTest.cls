@isTest
public class EventApiControllerTest {
    @isTest
    static void searchUpcomingEventsReturnsMockSuccess() {
        EventSearchRequest req = new EventSearchRequest();
        req.subject = 'Jazz';
        req.eventDate = '2026-06-01';
        req.rangeValue = '10km';
        req.selectedOption = 'item1';

        EventSearchResponse response = EventApiController.searchUpcomingEvents(req);

        System.assertEquals(true, response.success, 'Mock service should report success');
        System.assertEquals(200, response.statusCode);
        System.assertNotEquals(null, response.events);
        System.assert(response.events.size() > 0, 'Mock service should return at least one event');
        System.assert(response.events[0].title.contains('Jazz'), 'Mock events should reflect the requested subject');
    }

    @isTest
    static void searchUpcomingEventsHonorsForceErrorFlag() {
        EventSearchRequest req = new EventSearchRequest();
        req.subject = 'Jazz';
        req.eventDate = '2026-06-01';
        req.selectedOption = 'item1';
        req.forceError = true;

        EventSearchResponse response = EventApiController.searchUpcomingEvents(req);

        System.assertEquals(false, response.success, 'Force-error flag should produce a failure response');
        System.assertEquals(500, response.statusCode);
        System.assertEquals(0, response.events.size());
    }

    @isTest
    static void blankSubjectThrowsValidation() {
        EventSearchRequest req = new EventSearchRequest();
        req.subject = '';
        req.eventDate = '2026-06-01';
        req.selectedOption = 'item1';

        Boolean threw = false;
        try {
            EventApiController.searchUpcomingEvents(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Blank subject must raise AuraHandledException');
    }

    @isTest
    static void nullRequestThrowsValidation() {
        Boolean threw = false;
        try {
            EventApiController.searchUpcomingEvents(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Null request must raise AuraHandledException');
    }
}
