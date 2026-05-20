public with sharing class EventApiService {
    @TestVisible
    private static final Integer MAX_SERVER_DELAY_MS = 2000;

    public static EventSearchResponse searchUpcomingEvents(EventSearchRequest request) {
        applyServerDelay(request);

        if (request.forceError == true) {
            EventSearchResponse failed = new EventSearchResponse();
            failed.success = false;
            failed.statusCode = 500;
            failed.message = 'Simulated upstream failure.';
            failed.events = new List<EventItem>();
            failed.requestId = 'mock-' + String.valueOf(Datetime.now().getTime());
            return failed;
        }

        EventSearchResponse result = new EventSearchResponse();
        result.success = true;
        result.statusCode = 200;
        result.message = 'Events retrieved successfully.';
        result.requestId = 'mock-' + String.valueOf(Datetime.now().getTime());
        result.events = buildMockEvents(request);
        return result;
    }

    private static void applyServerDelay(EventSearchRequest request) {
        if (request == null || request.simulatedDelayMs == null || request.simulatedDelayMs <= 0) {
            return;
        }
        Integer clamped = Math.min(request.simulatedDelayMs, MAX_SERVER_DELAY_MS);
        Long target = System.currentTimeMillis() + clamped;
        while (System.currentTimeMillis() < target) {
            // busy-wait; capped by MAX_SERVER_DELAY_MS to stay under Apex CPU governor
        }
    }

    private static List<EventItem> buildMockEvents(EventSearchRequest request) {
        String subject = request.subject == null ? 'Event' : request.subject;
        String selected = request.selectedOption == null ? 'item' : request.selectedOption;
        String baseDate = String.isBlank(request.eventDate)
            ? String.valueOf(Date.today())
            : request.eventDate;

        List<EventItem> items = new List<EventItem>();

        EventItem one = new EventItem();
        one.id = 'evt-001';
        one.title = subject + ' Showcase';
        one.startDateTime = baseDate + 'T19:00:00Z';
        one.endDateTime = baseDate + 'T21:00:00Z';
        one.location = 'Downtown Pavilion';
        one.summary = 'A featured ' + subject + ' event tagged for ' + selected + '.';
        one.url = 'https://example.com/events/evt-001';
        items.add(one);

        EventItem two = new EventItem();
        two.id = 'evt-002';
        two.title = subject + ' Workshop';
        two.startDateTime = baseDate + 'T10:00:00Z';
        two.endDateTime = baseDate + 'T12:30:00Z';
        two.location = 'Community Hall';
        two.summary = 'Hands-on ' + subject + ' workshop with local hosts.';
        two.url = 'https://example.com/events/evt-002';
        items.add(two);

        EventItem three = new EventItem();
        three.id = 'evt-003';
        three.title = subject + ' Evening';
        three.startDateTime = baseDate + 'T20:30:00Z';
        three.endDateTime = baseDate + 'T23:00:00Z';
        three.location = 'Riverside Garden';
        three.summary = 'Casual ' + subject + ' gathering near the resort.';
        three.url = 'https://example.com/events/evt-003';
        items.add(three);

        return items;
    }
}
