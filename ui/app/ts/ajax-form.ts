/// <amd-module name='ajax-form'/>

class AjaxForm {
    successCallback: () => void;

    rootElement: HTMLElement;
    formElement: HTMLFormElement | null;

    constructor(rootElement: HTMLElement, successCallback: () => void) {
        window.MAP.init();

        this.successCallback = successCallback;

        this.rootElement = rootElement;
        this.formElement = rootElement.querySelector('form');

        this.setup();
    }

    setup() {
        if (!this.formElement) {
            return;
        }

        this.formElement.addEventListener('submit', (e) => {
            const form = e.target as HTMLFormElement;

            fetch(form.action, {
                method: form.method,
                body: new FormData(form),
            }).then((response) => {
                if (response.status == 202) {
                    // Create/update was accepted
                    this.successCallback();
                    return Promise.resolve('');
                } else {
                    // Update went wrong.  Should have an error response.
                    return response.text();
                }
            }).then((body) => {
                this.rootElement.innerHTML = body;
                new AjaxForm(this.rootElement, this.successCallback);
            });

            e.preventDefault();
            return false;
        });
    }
}
