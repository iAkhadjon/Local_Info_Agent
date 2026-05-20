import { LightningElement, api, track } from 'lwc';
import getWeather from '@salesforce/apex/WeatherApiController.getWeather';

export default class WeatherRequestPanel extends LightningElement {
    @api value;

    @track result;
    @track errorMessage;
    @track validationMessage;

    location = '';
    weatherDate = '';
    isLoading = false;
    hasSearched = false;

    connectedCallback() {
        const state = this.value || {};
        this.weatherDate = state.defaultDate || '';
        this.location = state.defaultLocation || '';
        if (!this.location) {
            const checked = (state.locationOptions || []).find((option) => option.checked);
            if (checked) {
                this.location = checked.value;
            }
        }
    }

    get title() {
        return (this.value && this.value.title) || 'Resort Weather';
    }

    get prompt() {
        return (this.value && this.value.prompt) || 'Choose date and location from the dropdown.';
    }

    get locationOptions() {
        const options = (this.value && this.value.locationOptions) || [];
        return options.map((option) => ({ label: option.label, value: option.value }));
    }

    get showForm() {
        return !this.hasSearched || this.isLoading || this.errorMessage;
    }

    get showResults() {
        return this.hasSearched && !this.isLoading && !this.errorMessage && this.result;
    }

    get inputsDisabled() {
        return this.isLoading;
    }

    handleLocationChange(event) {
        this.location = event.detail.value;
    }

    handleDateChange(event) {
        this.weatherDate = event.detail.value;
    }

    validate() {
        if (!this.location) {
            this.validationMessage = 'Location is required.';
            return false;
        }
        if (!this.weatherDate) {
            this.validationMessage = 'Date is required.';
            return false;
        }
        this.validationMessage = undefined;
        return true;
    }

    async handleRequest() {
        this.errorMessage = undefined;

        if (!this.validate()) {
            return;
        }

        this.isLoading = true;
        this.hasSearched = true;
        this.result = undefined;

        const request = {
            location: this.location,
            weatherDate: this.weatherDate
        };

        try {
            const response = await getWeather({ request });
            if (!response || response.success !== true) {
                this.errorMessage =
                    response && response.message ? response.message : 'Weather could not be retrieved.';
                return;
            }
            this.result = response;
        } catch (error) {
            const body = error && error.body ? error.body : null;
            this.errorMessage =
                (body && body.message) || 'Unable to retrieve weather right now. Please try again later.';
        } finally {
            this.isLoading = false;
        }
    }

    handleRetry() {
        this.handleRequest();
    }

    handleNewSearch() {
        this.hasSearched = false;
        this.result = undefined;
        this.errorMessage = undefined;
        this.validationMessage = undefined;
    }
}
