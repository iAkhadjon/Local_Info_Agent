@isTest
public class WeatherApiControllerTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"minTemperatureC":12.5,"maxTemperatureC":22.0,"minTemperatureF":54.5,"maxTemperatureF":71.6,"description":"Partly cloudy."}'
            );
            return res;
        }
    }

    @isTest
    static void getWeatherReturnsPopulatedResponseOnSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        WeatherSearchRequest req = new WeatherSearchRequest();
        req.location = 'mountain';
        req.weatherDate = '2026-06-01';

        Test.startTest();
        WeatherSearchResponse response = WeatherApiController.getWeather(req);
        Test.stopTest();

        System.assertEquals(true, response.success, 'Successful callout should return success=true');
        System.assertEquals(200, response.statusCode);
        System.assertEquals(12.5, response.minTemperatureC);
        System.assertEquals(22.0, response.maxTemperatureC);
        System.assertEquals('mountain', response.location);
        System.assertEquals('2026-06-01', response.weatherDate);
        System.assertNotEquals(null, response.description);
    }

    @isTest
    static void blankLocationThrowsValidation() {
        WeatherSearchRequest req = new WeatherSearchRequest();
        req.location = '';
        req.weatherDate = '2026-06-01';

        Boolean threw = false;
        try {
            WeatherApiController.getWeather(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Blank location must raise AuraHandledException');
    }

    @isTest
    static void blankWeatherDateThrowsValidation() {
        WeatherSearchRequest req = new WeatherSearchRequest();
        req.location = 'mountain';
        req.weatherDate = '';

        Boolean threw = false;
        try {
            WeatherApiController.getWeather(req);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Blank weatherDate must raise AuraHandledException');
    }

    @isTest
    static void nullRequestThrowsValidation() {
        Boolean threw = false;
        try {
            WeatherApiController.getWeather(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Null request must raise AuraHandledException');
    }
}
