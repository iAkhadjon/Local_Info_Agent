import { LightningElement, api, track } from 'lwc';
import searchUpcomingEvents from '@salesforce/apex/EventApiController.searchUpcomingEvents';

export default class EventRequestPanel extends LightningElement {
    @api value;

    @track events = [];
    @track errorMessage;
    @track validationMessage;

    subject = '';
    eventDate = '';
    rangeValue = '';
    selectedOption;
    simulatedDelayMs = 1500;
    forceError = false;
    isLoading = false;
    hasSearched = false;

    connectedCallback() {
        const state = this.value || {};
        this.subject = state.defaultSubject || '';
        this.eventDate = state.defaultDate || '';
        this.rangeValue = state.defaultRange || '';
        const checked = (state.options || []).find((option) => option.checked);
        this.selectedOption = checked ? checked.value : null;
    }

    get title() {
        return (this.value && this.value.title) || 'Event Search';
    }

    get prompt() {
        return (this.value && this.value.prompt) || 'Fill in the details and click Request.';
    }

    get radioOptions() {
        const options = (this.value && this.value.options) || [];
        return options.map((option) => ({ label: option.label, value: option.value }));
    }

    get showForm() {
        return !this.hasSearched || this.isLoading || this.errorMessage;
    }

    get showResults() {
        return this.hasSearched && !this.isLoading && !this.errorMessage;
    }

    get hasEvents() {
        return this.events && this.events.length > 0;
    }

    get inputsDisabled() {
        return this.isLoading;
    }

    get loadingMessage() {
        return `Searching upcoming events (~${this.simulatedDelayMs}ms)...`;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
    }

    handleDateChange(event) {
        this.eventDate = event.detail.value;
    }

    handleRangeChange(event) {
        this.rangeValue = event.detail.value;
    }

    handleOptionChange(event) {
        this.selectedOption = event.detail.value;
    }

    handleDelayChange(event) {
        const raw = Number(event.detail.value);
        this.simulatedDelayMs = Number.isFinite(raw) && raw >= 0 ? raw : 0;
    }

    handleForceErrorChange(event) {
        this.forceError = event.detail.checked;
    }

    validate() {
        if (!this.subject || !this.subject.trim()) {
            this.validationMessage = 'Subject is required.';
            return false;
        }
        if (!this.eventDate) {
            this.validationMessage = 'Date is required.';
            return false;
        }
        if (!this.selectedOption) {
            this.validationMessage = 'Please select an option.';
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
        this.events = [];

        if (this.simulatedDelayMs > 0) {
            await new Promise((resolve) => setTimeout(resolve, this.simulatedDelayMs));
        }

        const request = {
            subject: this.subject,
            eventDate: this.eventDate,
            rangeValue: this.rangeValue,
            selectedOption: this.selectedOption,
            simulatedDelayMs: this.simulatedDelayMs,
            forceError: this.forceError
        };

        try {
            const response = await searchUpcomingEvents({ request });
            if (!response || response.success !== true) {
                this.errorMessage =
                    response && response.message ? response.message : 'No events could be retrieved.';
                return;
            }
            this.events = response.events || [];
        } catch (error) {
            const body = error && error.body ? error.body : null;
            this.errorMessage =
                (body && body.message) || 'Unable to retrieve events right now. Please try again later.';
        } finally {
            this.isLoading = false;
        }
    }

    handleRetry() {
        this.handleRequest();
    }

    handleNewSearch() {
        this.hasSearched = false;
        this.events = [];
        this.errorMessage = undefined;
        this.validationMessage = undefined;
    }
}
