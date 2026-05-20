@JsonAccess(serializable='always' deserializable='always')
global class WeatherSearchResponse {
    @AuraEnabled
    global Boolean success;
    @AuraEnabled
    global String message;
    @AuraEnabled
    global Integer statusCode;
    @AuraEnabled
    global String requestId;
    @AuraEnabled
    global String location;
    @AuraEnabled
    global String weatherDate;
    @AuraEnabled
    global Decimal minTemperatureC;
    @AuraEnabled
    global Decimal maxTemperatureC;
    @AuraEnabled
    global Decimal minTemperatureF;
    @AuraEnabled
    global Decimal maxTemperatureF;
    @AuraEnabled
    global String description;
}
