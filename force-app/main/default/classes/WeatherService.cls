public class WeatherService {
    @TestVisible
    private static final String WEATHER_NAMED_CREDENTIAL = 'callout:Weather_API';
    @TestVisible
    private static final Integer HTTP_TIMEOUT_MS = 10000;

    /**
     * Gets the weather at the resort for the provided date.
     * Returns mocked weather data for demonstration purposes.
     */
    public static Weather getResortWeather(Datetime dateToCheck) {
        // Adjust the input date to the current year
        Integer currentYear = Date.today().year();
        Integer yearDelta = currentYear - dateToCheck.year();
        dateToCheck = dateToCheck.addYears(yearDelta);
        String dateString = dateToCheck.format('MMMM d');

        // Generate mock temperature data
        Decimal minTempC = 18.5;
        Decimal maxTempC = 27.3;
        Decimal minTempF = toFahrenheit(minTempC);
        Decimal maxTempF = toFahrenheit(maxTempC);
        String description =
            'On ' +
            dateString +
            ', temperature should be between ' +
            minTempC +
            '°C (' +
            minTempF +
            '°F) and ' +
            maxTempC +
            '°C (' +
            maxTempF +
            '°F) at the resort.';

        Weather weather = new Weather();
        weather.minTemperatureC = minTempC;
        weather.minTemperatureF = minTempF;
        weather.maxTemperatureC = maxTempC;
        weather.maxTemperatureF = maxTempF;
        weather.description = description;
        return weather;
    }

    public static WeatherSearchResponse getWeatherByLocation(WeatherSearchRequest request) {
        WeatherSearchResponse response = new WeatherSearchResponse();
        response.requestId = 'wx-' + String.valueOf(Datetime.now().getTime());
        response.location = request == null ? null : request.location;
        response.weatherDate = request == null ? null : request.weatherDate;

        if (request == null) {
            return failure(response, 400, 'Missing weather request.');
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            WEATHER_NAMED_CREDENTIAL +
                '/forecast?location=' +
                EncodingUtil.urlEncode(String.valueOf(request.location), 'UTF-8') +
                '&date=' +
                EncodingUtil.urlEncode(String.valueOf(request.weatherDate), 'UTF-8')
        );
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(HTTP_TIMEOUT_MS);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            return failure(response, 0, 'Weather API call failed: ' + e.getMessage());
        }

        Integer status = res.getStatusCode();
        response.statusCode = status;

        if (status < 200 || status >= 300) {
            return failure(response, status, 'Weather API returned status ' + status + '.');
        }

        try {
            return parseResponseBody(response, res.getBody(), request);
        } catch (Exception e) {
            return failure(response, status, 'Unable to parse weather response: ' + e.getMessage());
        }
    }

    private static WeatherSearchResponse parseResponseBody(
        WeatherSearchResponse response,
        String body,
        WeatherSearchRequest request
    ) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);

        Decimal minC = readDecimal(parsed, 'minTemperatureC');
        Decimal maxC = readDecimal(parsed, 'maxTemperatureC');
        Decimal minF = parsed.containsKey('minTemperatureF') ? readDecimal(parsed, 'minTemperatureF') : toFahrenheit(minC);
        Decimal maxF = parsed.containsKey('maxTemperatureF') ? readDecimal(parsed, 'maxTemperatureF') : toFahrenheit(maxC);
        String description = (String) parsed.get('description');

        response.success = true;
        response.message = 'Weather retrieved successfully.';
        response.minTemperatureC = minC;
        response.maxTemperatureC = maxC;
        response.minTemperatureF = minF;
        response.maxTemperatureF = maxF;
        response.description = description != null
            ? description
            : buildDefaultDescription(request, minC, maxC, minF, maxF);
        return response;
    }

    private static Decimal readDecimal(Map<String, Object> source, String key) {
        Object value = source.get(key);
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        if (value instanceof Integer) {
            return Decimal.valueOf((Integer) value);
        }
        if (value instanceof Double) {
            return Decimal.valueOf((Double) value);
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    private static String buildDefaultDescription(
        WeatherSearchRequest request,
        Decimal minC,
        Decimal maxC,
        Decimal minF,
        Decimal maxF
    ) {
        String loc = request == null || String.isBlank(request.location) ? 'the resort' : request.location;
        String day = request == null || String.isBlank(request.weatherDate) ? 'the selected date' : request.weatherDate;
        return 'On ' +
            day +
            ', temperatures at ' +
            loc +
            ' will be between ' +
            minC +
            '°C (' +
            minF +
            '°F) and ' +
            maxC +
            '°C (' +
            maxF +
            '°F).';
    }

    private static WeatherSearchResponse failure(
        WeatherSearchResponse response,
        Integer statusCode,
        String message
    ) {
        response.success = false;
        response.statusCode = statusCode;
        response.message = message;
        return response;
    }

    private static Decimal toFahrenheit(Decimal celsius) {
        if (celsius == null) {
            return null;
        }
        return (celsius * 9 / 5 + 32).setScale(1);
    }

    public class Weather {
        public Decimal minTemperatureC;
        public Decimal minTemperatureF;
        public Decimal maxTemperatureC;
        public Decimal maxTemperatureF;
        public String description;
    }
}
