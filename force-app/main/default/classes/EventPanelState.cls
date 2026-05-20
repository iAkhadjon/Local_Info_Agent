@JsonAccess(serializable='always' deserializable='always')
global class EventPanelState {
    @AuraEnabled
    global String title;
    @AuraEnabled
    global String prompt;
    @AuraEnabled
    global String defaultSubject;
    @AuraEnabled
    global String defaultDate;
    @AuraEnabled
    global String defaultRange;
    @AuraEnabled
    global List<EventOption> options;
}
