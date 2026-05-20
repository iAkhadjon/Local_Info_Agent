@JsonAccess(serializable='always' deserializable='always')
global class WeatherLocationOption {
    @AuraEnabled
    global String label;
    @AuraEnabled
    global String value;
    @AuraEnabled
    global Boolean checked;
}
