@JsonAccess(serializable='always' deserializable='always')
global class WeatherSearchRequest {
    @AuraEnabled
    global String location;
    @AuraEnabled
    global String weatherDate;
}
