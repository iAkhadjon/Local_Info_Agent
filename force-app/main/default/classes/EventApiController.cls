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
