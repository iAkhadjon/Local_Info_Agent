public with sharing class WeatherApiController {
    @AuraEnabled
    public static WeatherSearchResponse getWeather(WeatherSearchRequest request) {
        if (request == null) {
            throw new AuraHandledException('Missing request details.');
        }
        if (String.isBlank(request.location)) {
            throw new AuraHandledException('Location is required.');
        }
        if (String.isBlank(request.weatherDate)) {
            throw new AuraHandledException('Date is required.');
        }

        try {
            return WeatherService.getWeatherByLocation(request);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Weather API request failed: ' + e.getMessage());
            throw new AuraHandledException('Unable to retrieve weather right now. Please try again later.');
        }
    }
}
