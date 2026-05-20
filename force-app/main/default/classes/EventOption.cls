@JsonAccess(serializable='always' deserializable='always')
global class EventOption {
    @AuraEnabled
    global String label;
    @AuraEnabled
    global String value;
    @AuraEnabled
    global Boolean checked;
}
