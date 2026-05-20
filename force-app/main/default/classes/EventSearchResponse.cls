@JsonAccess(serializable='always' deserializable='always')
global class EventSearchResponse {
    @AuraEnabled
    global Boolean success;
    @AuraEnabled
    global String message;
    @AuraEnabled
    global Integer statusCode;
    @AuraEnabled
    global String requestId;
    @AuraEnabled
    global List<EventItem> events;
}
