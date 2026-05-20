@JsonAccess(serializable='always' deserializable='always')
global class WeatherPanelState {
    @AuraEnabled
    global String title;
    @AuraEnabled
    global String prompt;
    @AuraEnabled
    global String defaultDate;
    @AuraEnabled
    global String defaultLocation;
    @AuraEnabled
    global List<WeatherLocationOption> locationOptions;
}
