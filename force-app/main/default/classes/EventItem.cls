@JsonAccess(serializable='always' deserializable='always')
global class EventItem {
    @AuraEnabled
    global String id;
    @AuraEnabled
    global String title;
    @AuraEnabled
    global String startDateTime;
    @AuraEnabled
    global String endDateTime;
    @AuraEnabled
    global String location;
    @AuraEnabled
    global String summary;
    @AuraEnabled
    global String url;
}
