@JsonAccess(serializable='always' deserializable='always')
global class EventSearchRequest {
    @AuraEnabled
    global String subject;
    @AuraEnabled
    global String eventDate;
    @AuraEnabled
    global String rangeValue;
    @AuraEnabled
    global String selectedOption;
    @AuraEnabled
    global Integer simulatedDelayMs;
    @AuraEnabled
    global Boolean forceError;
}
