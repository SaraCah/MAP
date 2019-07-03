/// <amd-module name='ajax-form'/>

class AjaxForm {
    successCallback: () => void;

    rootElement: HTMLElement;
    formElements: NodeListOf<HTMLFormElement>;

    constructor(rootElement: HTMLElement, successCallback: () => void) {
        window.MAP.init();

        this.successCallback = successCallback;

        this.rootElement = rootElement;
        this.formElements = rootElement.querySelectorAll('form');

        this.setup();
    }

    setup() {
        for (const form of this.formElements) {
            // Can be fired to indicate success without needing a form submission
            //
            // Call like: formElt.dispatchEvent(new Event('ajax-success'));
            //
            form.addEventListener('ajax-success', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.successCallback();
                return false;
            });

            form.addEventListener('submit', (e) => {
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
}